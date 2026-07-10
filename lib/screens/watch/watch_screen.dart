import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import '../../data/stories.dart';
import '../../theme/tokens.dart';
import '../../models/watch_payload.dart';
import '../../models/app_state.dart';
import '../../models/settings_model.dart';
import '../../models/page_timestamp.dart';
import '../../services/firestore_service.dart';
import '../../widgets/safe_image.dart';

/// Public screen — no auth required.
///
/// Opened via a share link such as:
///   storybridge://watch/<recId>?t=<base64url_token>
///
/// [payload] is pre-decoded by the router from the ?t= token.
/// When absent (old links, deep-link edge cases) the screen fetches the
/// payload from the Firestore `shares/{recId}` collection and falls back
/// further to the legacy `recordings` collectionGroup query.
class WatchScreen extends StatefulWidget {
  final String recordingId;

  /// Pre-decoded from the share URL token.  Null triggers a Firestore fetch.
  final WatchPayload? payload;
  final Map<String, String>? queryParams;

  const WatchScreen({
    super.key,
    required this.recordingId,
    this.payload,
    this.queryParams,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  WatchPayload? _payload;
  VideoPlayerController? _videoController;
  VideoPlayerController? _musicController;
  ChewieController? _chewieController;

  bool _isLoading = true;
  bool _hasError = false;
  bool _showDedication = false;
  int _currentPage = 0;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _lockOrientation();
    _loadInitialPayload();
  }

  Future<void> _loadInitialPayload() async {
    if (widget.payload != null) {
      var payload = widget.payload!;
      if (widget.queryParams != null && widget.queryParams!.isNotEmpty) {
        final overrideSettings = SettingsModel.fromQueryParams(widget.queryParams!);
        payload = payload.copyWith(settings: overrideSettings);
      }
      _showDedication = payload.dedication.isNotEmpty;
      
      payload = await _loadDynamicPagesIfNeeded(payload);

      if (mounted) {
        setState(() {
          _payload = payload;
        });
        _initPlayer(payload);
        _precacheWatchImages(payload);
      }
    } else {
      _fetchPayloadThenInit();
    }
  }

  Future<WatchPayload> _loadDynamicPagesIfNeeded(WatchPayload payload) async {
    final storyId = payload.storyId;
    if (storyId == null || storyId.isEmpty) return payload;

    final localStory = kStories.firstWhereOrNull((s) => s.id == storyId);
    if (localStory != null) return payload;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('story_pages')
          .where('story_id', isEqualTo: storyId)
          .get();

      final rows = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList()
        ..sort((a, b) {
          final an = (a['page_number'] as num?)?.toInt() ?? 0;
          final bn = (b['page_number'] as num?)?.toInt() ?? 0;
          return an.compareTo(bn);
        });

      final texts  = rows.map((d) => (d['content']   as String?) ?? '').toList();
      final images = rows.map((d) => (d['image_url'] as String?) ?? '').toList();

      final cleanedImages = images.map((url) {
        var cleaned = url.trim().replaceAll(RegExp(r'\s+'), '');
        if (cleaned.contains('firebasestorage.googleapis.com') && !cleaned.contains('alt=media')) {
          cleaned = cleaned.contains('?') ? '$cleaned&alt=media' : '$cleaned?alt=media';
        }
        return cleaned;
      }).toList();

      return payload.copyWith(
        dynamicPageTexts: texts,
        dynamicPageImages: cleanedImages,
      );
    } catch (e) {
      debugPrint('[WatchScreen] Error fetching dynamic pages: $e');
      return payload;
    }
  }

  void _lockOrientation() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _chewieController?.dispose();
    _videoController?.dispose();
    _musicController?.dispose();
    super.dispose();
  }

  // ── payload loading ────────────────────────────────────────────────────────

  Future<void> _fetchPayloadThenInit() async {
    try {
      // 1. Fast path — public `shares` collection (no auth required).
      WatchPayload? payload =
          await FirestoreService.getPublicPayload(widget.recordingId);

      // 2. Fallback — collectionGroup query on user recordings subcollections.
      if (payload == null) {
        final rec =
            await FirestoreService.getPublicRecording(widget.recordingId);
        if (rec != null) payload = _payloadFromLegacyRecording(rec);
      }

      // 3. Fallback — top-level recordings collection.
      if (payload == null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('recordings')
              .doc(widget.recordingId)
              .get();
          if (doc.exists) {
            final data = doc.data()!;
            final videoUrl = data['videoUrl'] ?? data['downloadUrl'] ?? '';
            final title = data['title'] ?? 'Story';
            final dedication = data['dedication'] ?? '';
            final storyId = data['storyId'] ?? '';

            List<PageTimestamp> timestamps = [];
            final pts = data['pageTimestamps'];
            if (pts is List) {
              timestamps = pts
                  .whereType<Map>()
                  .map((j) => PageTimestamp.fromJson(
                      Map<String, dynamic>.from(j)))
                  .toList();
            }

            payload = WatchPayload(
              recId: widget.recordingId,
              videoUrl: videoUrl,
              title: title,
              dedication: dedication,
              format: data['format'] as String? ?? 'book',
              storyId: storyId,
              settings: SettingsModel.fromQueryParams(widget.queryParams ?? {}),
              pageTimestamps: timestamps,
            );
          }
        } catch (_) {}
      }

      if (payload == null) {
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
        return;
      }

      // Apply overrides from queryParams
      if (widget.queryParams != null && widget.queryParams!.isNotEmpty) {
        final overrideSettings = SettingsModel.fromQueryParams(widget.queryParams!);
        payload = payload.copyWith(settings: overrideSettings);
      }

      // Load dynamic pages if needed
      payload = await _loadDynamicPagesIfNeeded(payload);

      _payload = payload;
      _showDedication = payload.dedication.isNotEmpty;
      await _initPlayer(payload);
      _precacheWatchImages(payload);
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _precacheWatchImages(WatchPayload payload) {
    if (payload.pageImages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final image in payload.pageImages) {
          if (image != null && image.isNotEmpty) {
            safePrecacheImage(image, getSafeImageProvider(image), context);
          }
        }
      });
    }
  }

  /// Builds a [WatchPayload] from a legacy [Recording] document that predates
  /// the token-based share URL format.
  WatchPayload _payloadFromLegacyRecording(Recording rec) {
    // Extract the raw HTTPS video URL from the old storybridge:// deep link.
    String videoUrl = rec.shareUrl ?? '';
    if (videoUrl.startsWith('storybridge://')) {
      try {
        final uri = Uri.parse(videoUrl);
        // Old format: ?url=<encoded_https_url>
        videoUrl = uri.queryParameters['url'] ?? videoUrl;
      } catch (_) {}
    }

    final settings = SettingsModel.fromJsonString(rec.settingsJson);

    List<PageTimestamp> timestamps = [];
    if (rec.pageTimestampsJson?.isNotEmpty == true) {
      try {
        final list = jsonDecode(rec.pageTimestampsJson!) as List;
        timestamps = list
            .map((j) => PageTimestamp.fromJson(
                Map<String, dynamic>.from(j as Map)))
            .toList();
      } catch (_) {}
    }

    return WatchPayload(
      recId: rec.id,
      videoUrl: videoUrl,
      title: rec.title,
      dedication: rec.dedication,
      format: rec.format.name,
      storyId: rec.storyId,
      settings: settings,
      pageTimestamps: timestamps,
    );
  }

  // ── player initialisation ──────────────────────────────────────────────────

  Future<void> _initPlayer(WatchPayload payload) async {
    if (payload.videoUrl.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
      return;
    }

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(payload.videoUrl));
      await controller.initialize();
      await controller.setLooping(payload.settings.loop);
      await controller.setPlaybackSpeed(payload.settings.playbackSpeed);

      // Attach auto-advance listener when applicable.
      if (payload.settings.autoAdvance && payload.pageTimestamps.isNotEmpty) {
        controller.addListener(_onVideoPositionChanged);
      }

      // Attach listener to control background music play/pause states.
      controller.addListener(_onVideoStateChanged);

      if (!mounted) {
        controller.dispose();
        return;
      }

      final tokens = Theme.of(context).extension<StorybridgeTokens>();
      final chewie = ChewieController(
        videoPlayerController: controller,
        // Don't auto-play while the dedication overlay is visible.
        autoPlay: !_showDedication,
        looping: payload.settings.loop,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: tokens?.tigerFlame ?? Colors.orange,
          handleColor: tokens?.tigerFlame ?? Colors.orange,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
      );

      if (mounted) {
        setState(() {
          _videoController = controller;
          _chewieController = chewie;
          _isLoading = false;
        });
        _initMusic(payload);
      } else {
        chewie.dispose();
        controller.dispose();
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _initMusic(WatchPayload payload) {
    if (payload.settings.backgroundMusic) {
      _musicController = VideoPlayerController.networkUrl(
        Uri.parse('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3'),
      );
      _musicController!.initialize().then((_) {
        if (!mounted) return;
        _musicController!.setVolume(0.08); // low volume
        _musicController!.setLooping(true);
        if (_videoController?.value.isPlaying == true) {
          _musicController!.play();
        }
      }).catchError((_) {});
    }
  }

  void _onVideoStateChanged() {
    if (!mounted || _videoController == null) return;
    if (_musicController != null && _musicController!.value.isInitialized) {
      final isPlaying = _videoController!.value.isPlaying;
      if (isPlaying && !_musicController!.value.isPlaying) {
        _musicController!.play();
      } else if (!isPlaying && _musicController!.value.isPlaying) {
        _musicController!.pause();
      }
    }
  }

  // ── auto-advance ───────────────────────────────────────────────────────────

  void _onVideoPositionChanged() {
    if (!mounted || _videoController == null || _payload == null) return;
    final ctrl = _videoController!;
    if (!ctrl.value.isInitialized) return;

    final posMs = ctrl.value.position.inMilliseconds;
    int targetPage = 0;
    for (final ts in _payload!.pageTimestamps) {
      if (posMs >= ts.elapsedMs) {
        targetPage = ts.pageIndex;
      } else {
        break; // timestamps are sorted ascending
      }
    }
    if (targetPage != _currentPage) {
      setState(() => _currentPage = targetPage);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    if (_isLoading) return _buildLoading(tokens);
    if (_hasError) return _buildError(tokens);

    final payload = _payload!;
    final pages = payload.pageTexts;
    final images = payload.pageImages;

    final videoPos = payload.settings.narratorVideoPos;
    final showPlayer = payload.format != 'audio';
    final isBottom = videoPos.startsWith('bottom');

    Widget playerWidget = showPlayer
        ? Expanded(child: _buildPlayerArea(tokens, payload, pages))
        : Offstage(
            offstage: true,
            child: SizedBox(
              width: 1,
              height: 1,
              child: _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : const SizedBox.shrink(),
            ),
          );

    Widget cardWidget = pages.isNotEmpty
        ? (showPlayer
            ? _buildReadAlongCard(tokens, payload, pages, images)
            : Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: _buildReadAlongCard(tokens, payload, pages, images),
                  ),
                ),
              ))
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(tokens, payload),
                ... (isBottom ? [cardWidget, playerWidget] : [playerWidget, cardWidget]),
                _buildFooter(),
              ],
            ),
          ),

          // Dedication overlay — shown before the video starts when a
          // dedication text is present.  Tapping it dismisses the overlay
          // and begins playback.
          if (_showDedication) _buildDedicationOverlay(tokens, payload),
        ],
      ),
    );
  }

  // ── top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(StorybridgeTokens tokens, WatchPayload payload) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Watch',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              payload.title,
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.white60),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (payload.settings.playbackSpeed != 1.0) ...[
            const SizedBox(width: 6),
            _badge('${payload.settings.playbackSpeed}×', tokens),
          ],
          if (payload.settings.loop) ...[
            const SizedBox(width: 6),
            _badge('Loop', tokens),
          ],
          if (payload.settings.backgroundMusic) ...[
            const SizedBox(width: 6),
            _badge('♪', tokens),
          ],
        ],
      ),
    );
  }

  // ── player area (video + optional subtitle overlay) ────────────────────────

  Widget _buildPlayerArea(
      StorybridgeTokens tokens, WatchPayload payload, List<String> pages) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Chewie(controller: _chewieController!),
        ),

        // Subtitles — current page text overlaid on the bottom of the video.
        if (payload.settings.subtitles &&
            pages.isNotEmpty &&
            _currentPage < pages.length)
          Positioned(
            bottom: 52, // sit above Chewie's control bar
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pages[_currentPage],
                style: GoogleFonts.nunito(
                    fontSize: 14, color: Colors.white, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ── read-along card ────────────────────────────────────────────────────────

  Widget _buildReadAlongCard(
    StorybridgeTokens tokens,
    WatchPayload payload,
    List<String> pages,
    List<String?> images,
  ) {
    final text =
        _currentPage < pages.length ? pages[_currentPage] : '';
    final image =
        _currentPage < images.length ? images[_currentPage] : null;

    // When auto-advance is active, hide the manual nav arrows — page turns
    // are driven by the video position listener instead.
    final autoAdvancing =
        payload.settings.autoAdvance && payload.pageTimestamps.isNotEmpty;

    return Container(
      width: double.infinity,
      color: tokens.cream,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image.startsWith('http') || image.startsWith('https')
                  ? SafeNetworkImage(
                      imageUrl: image,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: const SizedBox.shrink(),
                    )
                  : Image.asset(
                      image,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                fontSize: 16, color: tokens.coffeeBean, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          if (!autoAdvancing)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  color: tokens.darkSlate,
                ),
                Text(
                  'Page ${_currentPage + 1} of ${pages.length}',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: tokens.darkSlate),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: _currentPage < pages.length - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  color: tokens.darkSlate,
                ),
              ],
            )
          else
            Text(
              'Page ${_currentPage + 1} of ${pages.length}',
              style: GoogleFonts.nunito(fontSize: 12, color: tokens.darkSlate),
            ),
        ],
      ),
    );
  }

  // ── dedication overlay ─────────────────────────────────────────────────────

  Widget _buildDedicationOverlay(
      StorybridgeTokens tokens, WatchPayload payload) {
    return GestureDetector(
      onTap: () {
        setState(() => _showDedication = false);
        _videoController?.play();
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.93),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite,
                      color: Color(0xFFE05C5C), size: 52),
                  const SizedBox(height: 28),
                  Text(
                    payload.title,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                        fontSize: 24, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    payload.dedication,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Tap anywhere to begin',
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: Colors.white30),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'Shared with ❤️ via Storybridge',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.white30),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── loading / error states ─────────────────────────────────────────────────

  Widget _buildLoading(StorybridgeTokens tokens) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: tokens.brightFern),
            const SizedBox(height: 16),
            Text(
              'Loading your story…',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                  fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(StorybridgeTokens tokens) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: tokens.tigerFlame, size: 52),
              const SizedBox(height: 20),
              Text(
                'Could not load this story.',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                    fontSize: 22, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'The link may have expired or the recording\nhas been removed.',
                style: GoogleFonts.nunito(
                    fontSize: 14, color: Colors.white38, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── badge helper ───────────────────────────────────────────────────────────

  Widget _badge(String label, StorybridgeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.tigerFlame.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
    );
  }
}
