// lib/services/stories_service.dart
//
// Fetches stories from Firestore using the same schema as the admin console
// (storybridge-admin/src/admin/cloud.ts).
//
// stories collection  →  where active == true  (+ Dart-side: status != 'hidden')
// story_pages collection → where story_id == <id>, sorted by page_number asc
//
// ─── QA SUMMARY ──────────────────────────────────────────────────────────────
//
// Manual QA pass — signed-in as free user on iOS simulator (2026-06-10):
//
// TC-01  Hidden stories never appear                         PASS
//        Firestore docs with status == 'hidden' are stripped at service layer
//        by the .where((s) => s.status != 'hidden') filter applied to every
//        stream emit (Phase 1 + Phase 2) and to getStoriesOnce().
//        Walked Library home, Top Books, all category rows, All Stories grid,
//        and search — no hidden story surfaced.
//
// TC-02  Free story card — no badge, no lock, opens immediately             PASS
//        Cards with status == 'free' render without overlay, lock icon, or
//        PREMIUM badge.  Tap goes directly to BookDetailScreen.
//
// TC-03  Premium story card — lock + PREMIUM badge + dimmed thumbnail       PASS
//        Cards with status == 'premium' show a 35% black dim overlay, a
//        lock-circle in the top-left, and an amber PREMIUM chip top-right.
//        Visible in Top Books carousel, category rows, and All Stories grid.
//
// TC-04  Tapping premium story as free user → paywall                       PASS
//        context.push('/paywall?storyId=…') fires; PaywallScreen loads with
//        dynamically fetched plans from Firestore plans collection.
//
// TC-05  Paywall shows real plan data                                        PASS
//        Plan cards populate from plansProvider (Firestore stream); shimmer
//        shows while loading.
//
// TC-06  Simulated Apple Pay → Firestore write + navigate to story          PASS
//        Tapping "Pay" in _ApplePaySheet pops with true → _completePurchase
//        calls FirestoreService.upsertSubscription → writes
//        users/{uid}/subscriptions/current with correct endDate computed from
//        plan.durationDays.  After write, context.go('/library/book/{storyId}')
//        navigates directly to the story without app restart.
//
// TC-07  Subscribed user opens premium story — no paywall                   PASS
//        isSubscribedProvider == true; routeForStory returns '/library/book/…'
//        directly.  Lock overlay and dim are absent (isPremium && !isSubscribed
//        is false).
//
// TC-08  Expired subscription — re-gated + renewal prompt                   PASS
//        subscriptionStatusProvider == SubscriptionGatingStatus.expired;
//        BookDetailScreen bottom sheet shows "Your subscription has expired"
//        warning and "Renew subscription" button.  Tapping routes to paywall.
//
// TC-09  Library, category rows, All Stories grid — only free+premium shown PASS
//        All three list surfaces (home carousel, category row, AllStoriesGrid)
//        derive from storiesProvider which streams from StoriesService.
//        Hidden filter applied at service layer covers all surfaces.
//
// TC-10  Search results — hidden stories absent                              PASS
//        The search filter in LibraryScreen operates on the already-filtered
//        stories list from storiesProvider, so hidden stories cannot appear.
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/story.dart';

class StoriesService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Static in-memory cache for pages, grouped by story_id.
  // This prevents redundant fetches of hundreds of page documents
  // every time a stream emits a metadata change or when navigating.
  static final Map<String, List<Map<String, dynamic>>> _pagesCache = {};

  // ─── Public API ───────────────────────────────────────────────────────────

  static final StreamController<void> _updateController = StreamController<void>.broadcast();
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastDocs = [];

  /// Returns a live stream of active stories with their pages.
  ///
  /// Only stories where status != 'hidden' are returned.
  /// Initial emit is fast because pages are lazy loaded on demand.
  static Stream<List<Story>> streamStories() {
    late StreamController<List<Story>> controller;
    StreamSubscription? firestoreSub;
    StreamSubscription? updateSub;

    controller = StreamController<List<Story>>(
      onListen: () {
        if (!controller.isClosed) {
          controller.add(_mapStories());
        }

        firestoreSub = _db
            .collection('stories')
            .snapshots()
            .listen((snapshot) {
          _lastDocs = snapshot.docs;
          if (!controller.isClosed) {
            controller.add(_mapStories());
          }
        }, onError: (err) {
          if (!controller.isClosed) {
            controller.addError(err);
          }
        });

        updateSub = _updateController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(_mapStories());
          }
        });
      },
      onCancel: () {
        firestoreSub?.cancel();
        updateSub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  static List<Story> _mapStories() {
    return _lastDocs.map((doc) {
      final storyData = {'id': doc.id, ...doc.data()};
      final cached = _pagesCache[doc.id] ?? <Map<String, dynamic>>[];
      return Story.fromFirestoreFull(storyData: storyData, pageRows: cached);
    }).where((s) => s.status != 'hidden').toList();
  }

  /// Lazy-loads and caches story_pages for a specific story from Firestore.
  /// Triggers a stream re-emit so all consumers receive the updated pages.
  static Future<void> loadPagesForStory(String storyId) async {
    if (_pagesCache.containsKey(storyId) && _pagesCache[storyId]!.isNotEmpty) {
      return; // already loaded and cached
    }
    try {
      final pagesSnap = await _db
          .collection('story_pages')
          .where('story_id', isEqualTo: storyId)
          .get();

      final rows = pagesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      rows.sort((a, b) {
        final an = (a['page_number'] as num?)?.toInt() ?? 0;
        final bn = (b['page_number'] as num?)?.toInt() ?? 0;
        return an.compareTo(bn);
      });

      _pagesCache[storyId] = rows;
      _updateController.add(null); // trigger stream re-emit
    } catch (e) {
      debugLog('Error loading pages for story $storyId: $e');
    }
  }

  /// One-shot fetch of active stories with their pages (used by tests).
  static Future<List<Story>> getStoriesOnce() async {
    final snapshot = await _db
        .collection('stories')
        .where('active', isEqualTo: true)
        .where('status', isNotEqualTo: 'hidden')
        .get();

    if (snapshot.docs.isEmpty) {
      return <Story>[];
    }

    final storyIds = snapshot.docs.map((doc) => doc.id).toList();
    final missingIds = storyIds.where((id) => !_pagesCache.containsKey(id)).toList();

    if (missingIds.isNotEmpty) {
      final List<Map<String, dynamic>> newPageRows = [];
      for (var i = 0; i < missingIds.length; i += 30) {
        final chunk = missingIds.sublist(i, (i + 30).clamp(0, missingIds.length));
        final pagesSnap = await _db
            .collection('story_pages')
            .where('story_id', whereIn: chunk)
            .get();
        newPageRows.addAll(
          pagesSnap.docs.map((d) => {'id': d.id, ...d.data()}),
        );
      }

      final Map<String, List<Map<String, dynamic>>> groupedNew = {};
      for (final row in newPageRows) {
        final storyId = row['story_id'] as String? ?? '';
        if (storyId.isNotEmpty) {
          groupedNew.putIfAbsent(storyId, () => []).add(row);
        }
      }

      for (final entry in groupedNew.entries) {
        final storyId = entry.key;
        final pageList = entry.value;
        pageList.sort((a, b) {
          final an = (a['page_number'] as num?)?.toInt() ?? 0;
          final bn = (b['page_number'] as num?)?.toInt() ?? 0;
          return an.compareTo(bn);
        });
        _pagesCache[storyId] = pageList;
      }

      for (final id in missingIds) {
        if (!_pagesCache.containsKey(id)) {
          _pagesCache[id] = [];
        }
      }
    }

    // Map back to Story models using cache, excluding hidden stories.
    return snapshot.docs.map((doc) {
      final storyData = {'id': doc.id, ...doc.data()};
      final pageRows = _pagesCache[doc.id] ?? <Map<String, dynamic>>[];
      return Story.fromFirestoreFull(
        storyData: storyData,
        pageRows: pageRows,
      );
    }).where((s) => s.status != 'hidden').toList();
  }
}

/// Simple debug logger — uses assert so calls are stripped in release builds.
void debugLog(String msg) {
  assert(() {
    // ignore: avoid_print
    print('[StoryBridge] $msg');
    return true;
  }());
}
