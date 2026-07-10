import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart' hide VideoFormat;
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/tokens.dart';
import '../../providers/app_state_provider.dart';
import '../../models/app_state.dart';
import '../../providers/stories_provider.dart';
import '../../models/story.dart';
import '../../services/firestore_service.dart';
import '../../services/stories_service.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/story_tile.dart';
import '../../widgets/safe_image.dart';
import '../../widgets/profile_top_bar.dart';

String _formatLabel(Recording rec) {
  switch (rec.format) {
    case VideoFormat.face:
      return 'Face-led';
    case VideoFormat.split:
      return 'Split view';
    case VideoFormat.bookOnly:
      return 'Book only';
    case VideoFormat.book:
      return 'Book-led';
    case VideoFormat.audio:
      return 'Audio';
  }
}

IconData _formatIcon(Recording rec) =>
    rec.format == VideoFormat.audio ? Icons.mic : Icons.videocam;

// ─────────────────────────────────────────────────────────────────────────────

class PreviewScreen extends ConsumerStatefulWidget {
  final String recordingId;
  const PreviewScreen({super.key, required this.recordingId});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoLoading = false;
  bool _videoReady = false;
  String? _videoError;
  String? _lastResolvedPath;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isDragging = false;

  bool _isHovering = false;
  bool _userInteracted = false;
  Timer? _hideControlsTimer;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<String?> _fetchCloudVideoUrl(String recordingId) async {
    try {
      // 1. Check if we can get it from the public shares collection
      final payload = await FirestoreService.getPublicPayload(recordingId);
      if (payload != null && payload.videoUrl.isNotEmpty) {
        return payload.videoUrl;
      }

      // 2. Check if we can get it from the top-level recordings collection
      final doc = await FirebaseFirestore.instance
          .collection('recordings')
          .doc(recordingId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final url = data['videoUrl'] ?? data['downloadUrl'];
          if (url is String && url.isNotEmpty) {
            return url;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _initPlayer() async {
    final recordings = ref.read(appStateProvider).recordings;
    final matches = recordings.where((r) => r.id == widget.recordingId).toList();
    if (matches.isEmpty) return;

    final rec = matches.first;
    if (rec.storyId != null && rec.storyId != 'null') {
      StoriesService.loadPagesForStory(rec.storyId!);
    }

    // Set _lastResolvedPath immediately to prevent the build loop for both video and audio formats.
    _lastResolvedPath = rec.localVideoPath ?? rec.localAudioPath;

    // Dispose old controllers before setting up new player state
    final oldChewie = _chewieController;
    final oldVideo = _videoController;
    _chewieController = null;
    _videoController = null;
    oldChewie?.dispose();
    if (oldVideo != null) {
      oldVideo.removeListener(_onPlayerPositionChanged);
      oldVideo.dispose();
    }

    final path = rec.localVideoPath ?? rec.localAudioPath;
    _lastResolvedPath = path;
    var resolvedPath = path;
    if (path != null && !kIsWeb && !File(path).existsSync()) {
      final filename = path.split('/').last;
      final docs = await getApplicationDocumentsDirectory();
      final docsFile = File('${docs.path}/$filename');
      if (docsFile.existsSync()) {
        resolvedPath = docsFile.path;
      } else {
        final temp = await getTemporaryDirectory();
        final tempFile = File('${temp.path}/$filename');
        if (tempFile.existsSync()) {
          resolvedPath = tempFile.path;
        }
      }
    }
    String? mediaUrl = resolvedPath;
    bool isLocal = true;

    final bool existsLocally = mediaUrl != null &&
        (kIsWeb
            ? (mediaUrl.startsWith('blob:') ||
                mediaUrl.startsWith('http:') ||
                mediaUrl.startsWith('https:'))
            : File(mediaUrl).existsSync());

    if (!existsLocally) {
      setState(() => _videoLoading = true);
      final cloudUrl = await _fetchCloudVideoUrl(widget.recordingId);
      if (cloudUrl != null) {
        mediaUrl = cloudUrl;
        isLocal = false;
      } else {
        if (mounted) {
          setState(() {
            _videoLoading = false;
            _videoError = rec.format == VideoFormat.audio
                ? 'Audio file not found locally or on the cloud.'
                : 'Video file not found locally or on the cloud.';
          });
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _videoLoading = true);

    try {
      final VideoPlayerController controller;
      if (isLocal) {
        if (kIsWeb) {
          controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
        } else {
          controller = VideoPlayerController.file(File(mediaUrl));
        }
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
      }
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.addListener(_onPlayerPositionChanged);

      final ChewieController? chewie;
      if (rec.format != VideoFormat.audio) {
        chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showControls: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: Theme.of(context).extension<StorybridgeTokens>()!.tigerFlame,
            handleColor: Theme.of(context).extension<StorybridgeTokens>()!.tigerFlame,
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white12,
          ),
        );
      } else {
        chewie = null;
      }

      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _videoLoading = false;
        _videoReady = true;
        _videoError = null;
        _currentPosition = controller.value.position.isNegative ? Duration.zero : controller.value.position;
        final dur = controller.value.duration;
        _totalDuration = (dur.isNegative || dur == Duration.zero)
            ? Duration(seconds: rec.durationSeconds)
            : dur;
      });
    } catch (e) {
      if (isLocal) {
        try {
          final cloudUrl = await _fetchCloudVideoUrl(widget.recordingId);
          if (cloudUrl != null) {
            final controller = VideoPlayerController.networkUrl(Uri.parse(cloudUrl));
            await controller.initialize();
            if (!mounted) {
              controller.dispose();
              return;
            }
            controller.addListener(_onPlayerPositionChanged);

            final ChewieController? chewie;
            if (rec.format != VideoFormat.audio) {
              chewie = ChewieController(
                videoPlayerController: controller,
                autoPlay: false,
                looping: false,
                allowFullScreen: true,
                allowMuting: true,
                showControls: false,
                materialProgressColors: ChewieProgressColors(
                  playedColor: Theme.of(context).extension<StorybridgeTokens>()!.tigerFlame,
                  handleColor: Theme.of(context).extension<StorybridgeTokens>()!.tigerFlame,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              );
            } else {
              chewie = null;
            }

            setState(() {
              _videoController = controller;
              _chewieController = chewie;
              _videoLoading = false;
              _videoReady = true;
              _videoError = null;
              _currentPosition = controller.value.position.isNegative ? Duration.zero : controller.value.position;
              final dur = controller.value.duration;
              _totalDuration = (dur.isNegative || dur == Duration.zero)
                  ? Duration(seconds: rec.durationSeconds)
                  : dur;
            });
            return;
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _videoLoading = false;
          _videoError = rec.format == VideoFormat.audio
              ? 'Could not load audio: ${e.toString().split('\n').first}'
              : 'Could not load video: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  void _onPlayerPositionChanged() {
    if (!mounted || _videoController == null || _isDragging) return;
    
    final value = _videoController!.value;
    
    final recordings = ref.read(appStateProvider).recordings;
    final matches = recordings.where((r) => r.id == widget.recordingId).toList();
    final recSeconds = matches.isNotEmpty ? matches.first.durationSeconds : 0;
    
    setState(() {
      _currentPosition = value.position.isNegative ? Duration.zero : value.position;
      
      final dur = value.duration;
      if (dur.isNegative || dur == Duration.zero) {
        _totalDuration = Duration(seconds: recSeconds);
      } else {
        _totalDuration = dur;
      }
      
      if (_currentPosition > _totalDuration) {
        _currentPosition = _totalDuration;
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) duration = Duration.zero;
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onHoverChanged(bool hovering) {
    setState(() {
      _isHovering = hovering;
    });
    if (hovering) {
      _resetHideControlsTimer();
    }
  }

  void _onPlayerTapped() {
    setState(() {
      _userInteracted = !_userInteracted;
    });
    if (_userInteracted) {
      _resetHideControlsTimer();
    }
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _userInteracted = false;
        });
      }
    });
  }

  bool _shouldShowControlsOverlay() {
    if (_videoController == null) return false;
    if (!_videoController!.value.isPlaying) return true;
    if (_isDragging) return true;
    return _isHovering || _userInteracted;
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || _videoController == null || _isDragging) return;
      if (!_videoController!.value.isPlaying) {
        timer.cancel();
        return;
      }
      
      final recordings = ref.read(appStateProvider).recordings;
      final matches = recordings.where((r) => r.id == widget.recordingId).toList();
      final recSeconds = matches.isNotEmpty ? matches.first.durationSeconds : 0;
      
      setState(() {
        _currentPosition = _videoController!.value.position.isNegative ? Duration.zero : _videoController!.value.position;
        final dur = _videoController!.value.duration;
        if (dur.isNegative || dur == Duration.zero) {
          _totalDuration = Duration(seconds: recSeconds);
        } else {
          _totalDuration = dur;
        }
        if (_currentPosition > _totalDuration) {
          _currentPosition = _totalDuration;
        }
      });
    });
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      _positionTimer?.cancel();
    } else {
      _videoController!.play();
      _startPositionTimer();
    }
    setState(() {});
    _resetHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _positionTimer?.cancel();
    _chewieController?.dispose();
    if (_videoController != null) {
      _videoController!.removeListener(_onPlayerPositionChanged);
      _videoController!.dispose();
    }
    super.dispose();
  }

  // ──────────────────────── build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final recordings = ref.watch(appStateProvider).recordings;
    final rec = recordings.cast<Recording?>().firstWhere(
      (r) => r?.id == widget.recordingId,
      orElse: () => null,
    );

    if (rec != null) {
      final currentPath = rec.localVideoPath ?? rec.localAudioPath;
      if (currentPath != _lastResolvedPath) {
        _lastResolvedPath = currentPath;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _initPlayer();
        });
      }
    }
    if (rec == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).extension<StorybridgeTokens>()!.cream,
        body: const Center(child: Text('Recording not found.')),
      );
    }
    final asyncStories = ref.watch(storiesProvider);
    final stories = asyncStories.value ?? [];
    
    final storyIdx = rec.storyId != null
        ? stories.indexWhere((s) => s.id == rec.storyId)
        : -1;
    final story = storyIdx != -1 ? stories[storyIdx] : null;
    final lovedOnes = ref.watch(appStateProvider).lovedOnes;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/stories');
      },
      child: Scaffold(
        backgroundColor: tokens.cream,
        appBar: ProfileTopBar(
          subtitle: 'Preview',
          onBackTap: () => context.go('/stories'),
          tokens: tokens,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPlayerWidget(tokens, rec, story),
              if (story != null) _buildPageStrip(tokens, story),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.title,
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: tokens.coffeeBean,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story != null ? 'by ${story.author}' : 'Original story',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChips(tokens, rec, lovedOnes),
                    if (rec.dedication.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tokens.porcelain,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: tokens.brightFern.withValues(alpha: 0.05)),
                        ),
                        child: Text(
                          rec.dedication,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                            color: tokens.coffeeBean,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    PillButton(
                      label: 'Share Story',
                      variant: PillVariant.primary,
                      fullWidth: true,
                      onPressed: () => _openShareSheet(context, tokens, rec),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Edit Details
                        Expanded(
                          child: PillButton(
                            label: 'Edit Details',
                            variant: PillVariant.outline,
                            onPressed: () => context.push('/edit/${rec.id}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Re-record
                        Expanded(
                          child: PillButton(
                            label: 'Re-record',
                            variant: PillVariant.outline,
                            foregroundColor: tokens.recordRed,
                            onPressed: () => _confirmReRecord(context, tokens, rec),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildRecommended(context, tokens, stories),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────── player widget & controls ─────────────────────────

  Widget _buildPlayerWidget(StorybridgeTokens tokens, Recording rec, Story? story) {
    final showControls = _videoReady && _videoController != null;
    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onPlayerTapped,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.coffeeBean,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: tokens.coffeeBean.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  // Video Player (takes full size of AspectRatio)
                  Positioned.fill(
                    child: _buildMediaArea(tokens, story, rec),
                  ),

                  // Center Play Button Overlay
                  if (_videoController != null && !_videoController!.value.isPlaying)
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Custom Control Bar Overlay
                  if (showControls)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedOpacity(
                        opacity: _shouldShowControlsOverlay() ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: IgnorePointer(
                          ignoring: !_shouldShowControlsOverlay(),
                          child: GestureDetector(
                            onTap: () {
                              // Consume tap to prevent triggering play/pause on the outer container
                              _resetHideControlsTimer();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.8),
                                  ],
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Play Time and Seek Slider
                                  Row(
                                    children: [
                                      Text(
                                        _formatDuration(_currentPosition),
                                        style: GoogleFonts.nunito(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 4,
                                            activeTrackColor: tokens.tigerFlame,
                                            inactiveTrackColor: Colors.white24,
                                            thumbColor: tokens.tigerFlame,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                          ),
                                          child: Slider(
                                            value: () {
                                              final currentMs = _currentPosition.inMilliseconds.toDouble();
                                              final totalMs = _totalDuration.inMilliseconds.toDouble();
                                              final maxVal = totalMs > 0.0 ? totalMs : 1.0;
                                              return currentMs.clamp(0.0, maxVal);
                                            }(),
                                            min: 0.0,
                                            max: _totalDuration.inMilliseconds.toDouble() > 0.0
                                                ? _totalDuration.inMilliseconds.toDouble()
                                                : 1.0,
                                            onChanged: (val) {
                                              setState(() {
                                                _isDragging = true;
                                                _currentPosition = Duration(milliseconds: val.toInt());
                                              });
                                              _resetHideControlsTimer();
                                            },
                                            onChangeEnd: (val) async {
                                              if (_videoController != null) {
                                                await _videoController!.seekTo(Duration(milliseconds: val.toInt()));
                                              }
                                              setState(() {
                                                _isDragging = false;
                                              });
                                              _resetHideControlsTimer();
                                            },
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(_totalDuration),
                                        style: GoogleFonts.nunito(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Control Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Play / Pause
                                      IconButton(
                                        icon: Icon(
                                          _videoController?.value.isPlaying == true 
                                              ? Icons.pause_circle_filled 
                                              : Icons.play_circle_filled,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                        onPressed: _togglePlayPause,
                                      ),
                                      const SizedBox(width: 20),
                                      // Skip Forward 10s
                                      IconButton(
                                        icon: const Icon(
                                          Icons.forward_10,
                                          size: 26,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () {
                                          if (_videoController != null) {
                                            final target = _videoController!.value.position + const Duration(seconds: 10);
                                            final duration = _totalDuration;
                                            _videoController!.seekTo(target > duration ? duration : target);
                                          }
                                          _resetHideControlsTimer();
                                        },
                                      ),
                                      if (rec.format != VideoFormat.audio) ...[
                                        const SizedBox(width: 20),
                                        // Full Screen
                                        IconButton(
                                          icon: const Icon(
                                            Icons.fullscreen,
                                            size: 26,
                                            color: Colors.white70,
                                          ),
                                          onPressed: () {
                                            _chewieController?.enterFullScreen();
                                            _resetHideControlsTimer();
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaArea(StorybridgeTokens tokens, Story? story, Recording rec) {
    if (_videoLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: tokens.brightFern),
            const SizedBox(height: 12),
            Text(rec.format == VideoFormat.audio ? 'Loading audio…' : 'Loading video…',
                style: GoogleFonts.nunito(
                    color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    if (_videoError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: tokens.tigerFlame, size: 40),
              const SizedBox(height: 8),
              Text(_videoError!,
                  style: GoogleFonts.nunito(
                      color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_videoReady && _chewieController != null && rec.format != VideoFormat.audio) {
      return Chewie(controller: _chewieController!);
    }

    // Audio / no-video fallback
    if (story != null) {
      final cover = story.coverAsset;
      if (cover.isNotEmpty) {
        return cover.startsWith('http') || cover.startsWith('https')
            ? SafeNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                placeholder: _audioFallback(tokens),
              )
            : Image.asset(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _audioFallback(tokens),
              );
      }
    }
    return _audioFallback(tokens);
  }

  Widget _audioFallback(StorybridgeTokens tokens) {
    return Container(
      color: tokens.coffeeBean,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 64, color: tokens.brightFern),
            const SizedBox(height: 8),
            Text('Audio recording',
                style: GoogleFonts.nunito(
                    fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── page strip ─────────────────────────────────────

  Widget _buildPageStrip(StorybridgeTokens tokens, Story story) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Story Pages',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: tokens.coffeeBean,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: story.pageTexts.length,
              itemBuilder: (_, i) {
                final imagePath = (i < story.pageImages.length && story.pageImages[i].isNotEmpty)
                    ? story.pageImages[i]
                    : story.coverAsset;

                return Container(
                  width: 320,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.porcelain,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tokens.brightFern.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 90,
                          height: 116,
                          child: imagePath.startsWith('http') || imagePath.startsWith('https')
                              ? SafeNetworkImage(
                                  imageUrl: imagePath,
                                  fit: BoxFit.cover,
                                  width: 90,
                                  height: 116,
                                  placeholder: Container(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  width: 90,
                                  height: 116,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    child: Icon(
                                      Icons.image,
                                      color: tokens.coffeeBean.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Page text & number
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Page ${i + 1}',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: tokens.tigerFlame,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                story.pageTexts[i],
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: tokens.coffeeBean,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── chips ──────────────────────────────────────────

  Widget _buildChips(
      StorybridgeTokens tokens, Recording rec, List<String> lovedOnes) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(tokens, rec.duration, Icons.timer_outlined),
          const SizedBox(width: 8),
          _chip(tokens, _formatLabel(rec), _formatIcon(rec)),
          if (lovedOnes.isNotEmpty) ...[
            const SizedBox(width: 8),
            _chip(tokens, 'For ${lovedOnes.first}', Icons.favorite),
          ],
          if (rec.shared) ...[
            const SizedBox(width: 8),
            _chip(tokens, 'Shared ✓', Icons.check_circle, accent: true),
          ] else if (rec.shareUrl != null) ...[
            const SizedBox(width: 8),
            _chip(tokens, 'Ready to share', Icons.share, accent: true),
          ],
        ],
      ),
    );
  }

  Widget _chip(StorybridgeTokens tokens, String label, IconData icon,
      {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? tokens.brightFern.withValues(alpha: 0.1)
            : tokens.darkSlate.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: accent ? tokens.brightFern : tokens.darkSlate),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent ? tokens.brightFern : tokens.darkSlate)),
        ],
      ),
    );
  }

  // ──────────────────────── recommended ────────────────────────────────────

  Widget _buildRecommended(BuildContext context, StorybridgeTokens tokens, List<Story> stories) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.porcelain.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.brightFern.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recommended next',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                      fontSize: 18, color: tokens.coffeeBean)),
              GestureDetector(
                onTap: () => context.go('/library'),
                child: Text('See all',
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.brightFern)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: stories.length,
              itemBuilder: (_, i) {
                final s = stories[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: StoryTile(
                    title: s.title,
                    coverUrl: s.coverAsset,
                    duration: s.duration,
                    width: 132,
                    onTap: () => context.push('/library/book/${s.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── re-record ──────────────────────────────────────

  void _confirmReRecord(
      BuildContext context, StorybridgeTokens tokens, Recording rec) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.porcelain,
        title: Text('Re-record story?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: tokens.coffeeBean)),
        content: Text(
            'This will replace this version. Continue?',
            style: GoogleFonts.nunito(color: tokens.darkSlate)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(color: tokens.darkSlate))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (rec.storyId != null) {
                context.push('/setup/text/${rec.storyId}');
              } else {
                context.push('/own-title');
              }
            },
            child: Text('Re-record',
                style: GoogleFonts.nunito(
                    color: tokens.recordRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }



  // ──────────────────────── share ──────────────────────────────────────────

  void _openShareSheet(
      BuildContext context, StorybridgeTokens tokens, Recording rec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.porcelain,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ShareSheet(recordingId: rec.id, tokens: tokens),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ShareSheet extends ConsumerStatefulWidget {
  final String recordingId;
  final StorybridgeTokens tokens;

  const _ShareSheet({required this.recordingId, required this.tokens});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final bool _uploading = false;
  final double _progress = 0;
  String? _shareUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rec = _freshRec();
    if (rec?.shareUrl != null) _shareUrl = rec!.shareUrl;
  }

  Recording? _freshRec() {
    final recs = ref.read(appStateProvider).recordings;
    final matches = recs.where((r) => r.id == widget.recordingId).toList();
    return matches.isNotEmpty ? matches.first : null;
  }

  Future<void> _ensureUploaded() async {
    if (_shareUrl != null) return;

    final rec = _freshRec();
    if (rec == null) {
      setState(() => _error = 'Recording not found.');
      return;
    }

    // Already uploaded by the background job — use it directly
    if (rec.shareUrl != null) {
      setState(() => _shareUrl = rec.shareUrl);
      return;
    }

    // Share link is generated on the draft page using: https://storybridgeapp.co.uk/#watch/
    setState(() {
      _error = 'Sharing is only available once saving has completed on the draft page.';
    });
  }

  Future<void> _shareWhatsApp() async {
    await _ensureUploaded();
    if (_shareUrl == null || !mounted) return;

    ref.read(appStateProvider.notifier).updateRecording(
          widget.recordingId,
          (r) => r.copyWith(shared: true),
        );

    final rec = _freshRec();
    final title = rec?.title ?? 'a story';
    final text = Uri.encodeComponent(
      '🎙️ $title\n\nI recorded a story for you on Storybridge! '
      'Tap the link to watch:\n$_shareUrl',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open WhatsApp. Is it installed?');
      }
    }
  }

  Future<void> _copyLink() async {
    await _ensureUploaded();
    if (_shareUrl == null || !mounted) return;

    await Clipboard.setData(ClipboardData(text: _shareUrl!));

    ref.read(appStateProvider.notifier).updateRecording(
          widget.recordingId,
          (r) => r.copyWith(shared: true),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied! Share it with the child to watch.'),
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: tokens.darkSlate.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Share story',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                    fontSize: 24, color: tokens.coffeeBean)),
            const SizedBox(height: 6),
            Text(
              _shareUrl != null
                  ? 'Your story is ready to share!'
                  : 'Tap a button below to upload and share.',
              style: GoogleFonts.nunito(fontSize: 13, color: tokens.darkSlate),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (_uploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 6,
                  backgroundColor: tokens.brightFern.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(tokens.brightFern),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _progress > 0
                    ? 'Uploading… ${(_progress * 100).toInt()}%'
                    : 'Preparing upload…',
                style: GoogleFonts.nunito(fontSize: 12, color: tokens.darkSlate),
              ),
              const SizedBox(height: 16),
            ],

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: GoogleFonts.nunito(
                              fontSize: 13, color: Colors.red.shade700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // WhatsApp
            GestureDetector(
              onTap: _uploading ? null : _shareWhatsApp,
              child: AnimatedOpacity(
                opacity: _uploading ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Share via WhatsApp',
                          style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Copy link
            GestureDetector(
              onTap: _uploading ? null : _copyLink,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: tokens.porcelain,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                      color: tokens.darkSlate.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _shareUrl != null ? Icons.check_circle : Icons.link,
                      color: _shareUrl != null
                          ? tokens.brightFern
                          : tokens.darkSlate,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _shareUrl != null
                          ? 'Link ready — tap to copy'
                          : 'Copy link',
                      style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.coffeeBean),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

