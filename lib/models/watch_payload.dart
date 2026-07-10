import 'dart:convert';
import 'package:collection/collection.dart';
import 'settings_model.dart';
import 'page_timestamp.dart';
import '../data/stories.dart';

/// Self-contained payload that encodes everything [WatchScreen] needs to
/// render a shared story.  Serialised as a compact, URL-safe base64 JSON
/// token embedded in share links.
///
/// ── Token schema (v2) ─────────────────────────────────────────────────────
///  v    – int    schema version (2)
///  id   – String recording ID
///  uid  – String uploader's Firebase UID  (replaces full url)
///  tok  – String Firebase Storage download token  (replaces full url)
///  ext  – String file extension (omitted when 'mp4')
///  ttl  – String recording title
///  ded  – String dedication text (omitted when empty)
///  fmt  – String VideoFormat.name  (omitted when 'book')
///  sid  – String built-in storyId  (omitted for custom stories)
///  pts  – List   flat [p0,t0, p1,t1, …]  page-index / elapsed-ms pairs
///  cfg  – Map    playback settings (omitted when all values are defaults)
///           spd  double  playback speed (1.0)
///           pos  String  narrator video position ('top-right')
///           bgm  bool    background music
///           aa   bool    auto-advance pages
///           sub  bool    show subtitles
///           lp   bool    loop playback
///
/// ── Token schema (v1) – read-only, never produced ─────────────────────────
///  url  – String Firebase Storage HTTPS video/audio URL (full)
///  pts  – List   [{p: pageIndex, t: elapsedMs}, …]
/// ──────────────────────────────────────────────────────────────────────────
///
/// The token is stored in the share URL as `?t=<token>` and mirrored in the
/// Firestore `shares/{recId}` collection so the watch screen can fall back to
/// a network fetch when the token is absent.
class WatchPayload {
  final String recId;
  final String videoUrl;
  final String title;
  final String dedication;
  final String format; // VideoFormat.name
  final String? storyId;
  final SettingsModel settings;
  final List<PageTimestamp> pageTimestamps;
  final List<String>? dynamicPageTexts;
  final List<String?>? dynamicPageImages;

  const WatchPayload({
    required this.recId,
    required this.videoUrl,
    required this.title,
    this.dedication = '',
    this.format = 'book',
    this.storyId,
    this.settings = const SettingsModel(),
    this.pageTimestamps = const [],
    this.dynamicPageTexts,
    this.dynamicPageImages,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────

  static const _storageBucket = 'storybridge-e4b5e.firebasestorage.app';

  static String _buildVideoUrl(String id, String uid, String tok, String ext) =>
      'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/'
      'recordings%2F$uid%2F$id.$ext?alt=media&token=$tok';

  /// Produces a Firestore-safe and JSON-compatible map (v2 compact schema).
  Map<String, dynamic> toMap() {
    // Extract uid, tok, and ext from the Firebase Storage download URL.
    final uri = Uri.tryParse(videoUrl);
    final oPath = uri?.pathSegments.lastOrNull ?? '';
    // oPath is decoded, e.g. "recordings/uid/recId.mp4"
    final pathParts = oPath.split('/');
    final uid = pathParts.length > 1 ? pathParts[1] : '';
    final filename = pathParts.length > 2 ? pathParts[2] : '';
    final ext = filename.endsWith('.m4a') ? 'm4a' : 'mp4';
    final tok = uri?.queryParameters['token'] ?? '';

    final isDefaultCfg = settings.playbackSpeed == 1.0 &&
        settings.narratorVideoPos == 'top-right' &&
        !settings.backgroundMusic &&
        !settings.autoAdvance &&
        !settings.subtitles &&
        !settings.loop;

    // pts as flat [p0,t0, p1,t1, …] — roughly 50% smaller than object list.
    final flatPts = <int>[];
    for (final p in pageTimestamps) {
      flatPts.add(p.pageIndex);
      flatPts.add(p.elapsedMs);
    }

    final map = <String, dynamic>{
      'v': 2,
      'id': recId,
      'uid': uid,
      'tok': tok,
      'ttl': title,
      'pts': flatPts,
    };
    if (ext != 'mp4') map['ext'] = ext;
    if (format != 'book') map['fmt'] = format;
    if (dedication.isNotEmpty) map['ded'] = dedication;
    if (!isDefaultCfg) {
      map['cfg'] = {
        'spd': settings.playbackSpeed,
        'pos': settings.narratorVideoPos,
        'bgm': settings.backgroundMusic,
        'aa': settings.autoAdvance,
        'sub': settings.subtitles,
        'lp': settings.loop,
      };
    }
    if (storyId != null) map['sid'] = storyId;
    return map;
  }

  /// Returns a URL-safe base64 token containing the full v2 payload map.
  ///
  /// [WatchPayload.fromToken] can decode this directly — the watch screen
  /// works completely offline without a Firestore round-trip.
  ///
  /// The token embeds uid + storage-download-token (tok) so the video URL
  /// can be reconstructed without a network request.  Typical size: ~260 B.
  String toBase64Token() {
    final json = jsonEncode(toMap());
    return base64Url.encode(utf8.encode(json));
  }

  /// Legacy compact base62 token (recording-ID only).
  ///
  /// Kept for reference — [fromToken] cannot decode this format; the watch
  /// screen always falls back to a Firestore fetch when it receives one.
  /// Use [toBase64Token] for all new share links.
  @Deprecated('Use toBase64Token() — this produces an opaque ID that '
      'fromToken() cannot decode, forcing a Firestore fallback every time.')
  String toToken() {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    var n = int.tryParse(recId.replaceFirst('rec-', '')) ?? 0;
    if (n == 0) return recId;
    final buf = StringBuffer();
    while (n > 0) {
      buf.write(chars[n % 62]);
      n ~/= 62;
    }
    return buf.toString().split('').reversed.join();
  }

  // ── Deserialisation ───────────────────────────────────────────────────────

  factory WatchPayload.fromMap(Map<String, dynamic> m) {
    final v = (m['v'] as num?)?.toInt() ?? 1;
    final id = (m['id'] as String?) ?? '';
    final cfg = (m['cfg'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    // ── Reconstruct video URL ──────────────────────────────────────────────
    final String videoUrl;
    if (v >= 2) {
      final uid = (m['uid'] as String?) ?? '';
      final tok = (m['tok'] as String?) ?? '';
      final ext = (m['ext'] as String?) ?? 'mp4';
      videoUrl = _buildVideoUrl(id, uid, tok, ext);
    } else {
      videoUrl = (m['url'] as String?) ?? '';
    }

    // ── Decode page timestamps ─────────────────────────────────────────────
    final ptsRaw = (m['pts'] as List<dynamic>?) ?? const [];
    List<PageTimestamp> timestamps;
    if (v >= 2) {
      // Flat [p0,t0, p1,t1, …] array.
      timestamps = [
        for (var i = 0; i + 1 < ptsRaw.length; i += 2)
          PageTimestamp(
            pageIndex: (ptsRaw[i] as num).toInt(),
            elapsedMs: (ptsRaw[i + 1] as num).toInt(),
          ),
      ];
    } else {
      timestamps = ptsRaw
          .whereType<Map>()
          .map((p) => PageTimestamp.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }
    // Ensure ascending order — critical for auto-advance binary search.
    timestamps.sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));

    return WatchPayload(
      recId: id,
      videoUrl: videoUrl,
      title: (m['ttl'] as String?) ?? 'Story',
      dedication: (m['ded'] as String?) ?? '',
      format: (m['fmt'] as String?) ?? 'book',
      storyId: m['sid'] as String?,
      settings: SettingsModel(
        playbackSpeed: ((cfg['spd'] as num?)?.toDouble()) ?? 1.0,
        narratorVideoPos: (cfg['pos'] as String?) ?? 'top-right',
        backgroundMusic: (cfg['bgm'] as bool?) ?? false,
        autoAdvance: (cfg['aa'] as bool?) ?? false,
        subtitles: (cfg['sub'] as bool?) ?? false,
        loop: (cfg['lp'] as bool?) ?? false,
      ),
      pageTimestamps: timestamps,
    );
  }

  /// Decodes from a URL-safe base64 token (padding may be absent).
  factory WatchPayload.fromToken(String token) {
    // base64Url.normalize adds back any stripped '=' padding.
    final padded = base64Url.normalize(token);
    final json = utf8.decode(base64Url.decode(padded));
    return WatchPayload.fromMap(
        Map<String, dynamic>.from(jsonDecode(json) as Map));
  }

  // ── Derived data from built-in story catalogue ────────────────────────────

  /// Page texts from the bundled [kStories] list (keyed by [storyId]).
  /// Returns an empty list for custom / own-title recordings.
  List<String> get pageTexts {
    if (dynamicPageTexts != null && dynamicPageTexts!.isNotEmpty) {
      return dynamicPageTexts!;
    }
    if (storyId == null) return const [];
    try {
      final story = kStories.firstWhereOrNull((s) => s.id == storyId);
      return story?.pageTexts ?? [];
    } catch (_) {
      return const [];
    }
  }

  /// Corresponding page image asset paths (entries may be null).
  List<String?> get pageImages {
    if (dynamicPageImages != null && dynamicPageImages!.isNotEmpty) {
      return dynamicPageImages!;
    }
    if (storyId == null) return const [];
    try {
      final story = kStories.firstWhereOrNull((s) => s.id == storyId);
      if (story == null) return [];
      return story.pageImages ??
          List<String?>.filled(story.pageTexts.length, null);
    } catch (_) {
      return const [];
    }
  }

  WatchPayload copyWith({
    String? recId,
    String? videoUrl,
    String? title,
    String? dedication,
    String? format,
    String? storyId,
    SettingsModel? settings,
    List<PageTimestamp>? pageTimestamps,
    List<String>? dynamicPageTexts,
    List<String?>? dynamicPageImages,
  }) {
    return WatchPayload(
      recId: recId ?? this.recId,
      videoUrl: videoUrl ?? this.videoUrl,
      title: title ?? this.title,
      dedication: dedication ?? this.dedication,
      format: format ?? this.format,
      storyId: storyId ?? this.storyId,
      settings: settings ?? this.settings,
      pageTimestamps: pageTimestamps ?? this.pageTimestamps,
      dynamicPageTexts: dynamicPageTexts ?? this.dynamicPageTexts,
      dynamicPageImages: dynamicPageImages ?? this.dynamicPageImages,
    );
  }
}
