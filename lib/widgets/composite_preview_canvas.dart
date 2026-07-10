import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../services/compositor_engine.dart';
import '../theme/google_fonts.dart';
import '../theme/tokens.dart';
import 'safe_image.dart';

class IOSPathHelper {
  static Future<String> resolveToAbsolute(String path) async {
    if (kIsWeb) return path;
    if (path.startsWith('http') || path.startsWith('blob:') || path.startsWith('mock_')) {
      return path;
    }
    final file = File(path);
    if (file.existsSync()) return path;

    // Resolve iOS sandbox dynamic GUID change
    final filename = path.split('/').last;
    if (path.contains('/Documents/')) {
      final docs = await getApplicationDocumentsDirectory();
      final docsFile = File('${docs.path}/$filename');
      if (docsFile.existsSync()) return docsFile.path;
    } else if (path.contains('/tmp/')) {
      final temp = await getTemporaryDirectory();
      final tempFile = File('${temp.path}/$filename');
      if (tempFile.existsSync()) return tempFile.path;
    }
    return path;
  }
}

class CompositePreviewCanvas extends StatefulWidget {
  final LayerStack layerStack;
  final String? storyCoverAsset;

  const CompositePreviewCanvas({
    super.key,
    required this.layerStack,
    this.storyCoverAsset,
  });

  @override
  State<CompositePreviewCanvas> createState() => _CompositePreviewCanvasState();
}

class _CompositePreviewCanvasState extends State<CompositePreviewCanvas> {
  VideoPlayerController? _videoController;
  VideoPlayerController? _bookVideoController;
  bool _isInitialized = false;
  bool _isBookInitialized = false;
  String? _currentVideoPath;
  String? _currentBookVideoPath;
  bool _isPlaying = false;
  String? _errorMessage;

  // GlobalKeys to preserve the video player's element state when it is reparented
  // during layout changes (e.g. from fullscreen background to small PiP overlay)
  final GlobalKey _videoPlayerKey = GlobalKey(debugLabel: 'face_video_player');
  final GlobalKey _bookVideoPlayerKey = GlobalKey(debugLabel: 'book_video_player');

  @override
  void initState() {
    super.initState();
    _checkAndInitVideo();
  }

  @override
  void didUpdateWidget(covariant CompositePreviewCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndInitVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _bookVideoController?.dispose();
    super.dispose();
  }

  FaceVideoLayer? _findFaceVideoLayer() {
    for (final layer in widget.layerStack.layers) {
      if (layer is FaceVideoLayer) {
        return layer;
      }
    }
    return null;
  }

  BookAnimationLayer? _findBookAnimationLayer() {
    for (final layer in widget.layerStack.layers) {
      if (layer is BookAnimationLayer) {
        return layer;
      }
    }
    return null;
  }

  Future<void> _checkAndInitVideo() async {
    final faceLayer = _findFaceVideoLayer();
    final bookLayer = _findBookAnimationLayer();

    final facePath = faceLayer?.path;
    final bookPath = bookLayer?.path;

    // 1. Initialize Face Video Controller
    if (facePath != null && facePath.isNotEmpty) {
      if (_currentVideoPath != facePath) {
        setState(() {
          _errorMessage = null;
          _isInitialized = false;
        });

        try {
          final resolvedPath = await IOSPathHelper.resolveToAbsolute(facePath);
          _videoController?.dispose();

          final controller = kIsWeb
              ? VideoPlayerController.networkUrl(Uri.parse(resolvedPath))
              : resolvedPath.startsWith('http')
                  ? VideoPlayerController.networkUrl(Uri.parse(resolvedPath))
                  : VideoPlayerController.file(File(resolvedPath));

          await controller.initialize();
          controller.setLooping(true);
          // Explicit volume ensures audio plays on all platforms; the camera
          // records with enableAudio: true so the track is always present.
          await controller.setVolume(1.0);

          if (_isPlaying) {
            await controller.play();
          }

          if (mounted) {
            setState(() {
              _videoController = controller;
              _isInitialized = true;
              _currentVideoPath = facePath;
              _isPlaying = controller.value.isPlaying;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Could not play video: ${e.toString().split('\n').first}';
              _isInitialized = false;
            });
          }
        }
      }
    } else {
      if (_videoController != null) {
        setState(() {
          _videoController?.dispose();
          _videoController = null;
          _isInitialized = false;
          _currentVideoPath = null;
        });
      }
    }

    // 2. Initialize Book Video Controller
    if (bookPath != null && bookPath.isNotEmpty) {
      final bool isBookVideo = bookPath.endsWith('.mp4') || bookPath.endsWith('.webm') || bookPath.startsWith('blob:');
      if (isBookVideo) {
        if (_currentBookVideoPath != bookPath) {
          setState(() {
            _isBookInitialized = false;
          });

          try {
            final resolvedPath = await IOSPathHelper.resolveToAbsolute(bookPath);
            _bookVideoController?.dispose();

            final controller = kIsWeb
                ? VideoPlayerController.networkUrl(Uri.parse(resolvedPath))
                : resolvedPath.startsWith('http')
                    ? VideoPlayerController.networkUrl(Uri.parse(resolvedPath))
                    : VideoPlayerController.file(File(resolvedPath));

            await controller.initialize();
            controller.setLooping(true);
            await controller.setVolume(0.0); // Mute book video track

            if (_isPlaying) {
              await controller.play();
            }

            if (mounted) {
              setState(() {
                _bookVideoController = controller;
                _isBookInitialized = true;
                _currentBookVideoPath = bookPath;
              });
            }
          } catch (e) {
            debugPrint('Failed to load book video preview: $e');
          }
        }
      } else {
        if (_bookVideoController != null) {
          setState(() {
            _bookVideoController?.dispose();
            _bookVideoController = null;
            _isBookInitialized = false;
            _currentBookVideoPath = null;
          });
        }
      }
    } else {
      if (_bookVideoController != null) {
        setState(() {
          _bookVideoController?.dispose();
          _bookVideoController = null;
          _isBookInitialized = false;
          _currentBookVideoPath = null;
        });
      }
    }
  }

  void _togglePlay() {
    bool playingNow = false;

    if (_videoController != null && _isInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        playingNow = false;
      } else {
        _videoController!.play();
        playingNow = true;
      }
    } else if (_bookVideoController != null && _isBookInitialized) {
      if (_bookVideoController!.value.isPlaying) {
        _bookVideoController!.pause();
        playingNow = false;
      } else {
        _bookVideoController!.play();
        playingNow = true;
      }
    }

    if (_bookVideoController != null && _isBookInitialized) {
      if (playingNow) {
        _bookVideoController!.play();
      } else {
        _bookVideoController!.pause();
      }
    }
    if (_videoController != null && _isInitialized) {
      if (playingNow) {
        _videoController!.play();
      } else {
        _videoController!.pause();
      }
    }

    setState(() {
      _isPlaying = playingNow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    BookAnimationLayer? bookLayer;
    FaceVideoLayer? faceLayer;
    MetadataOverlayLayer? metadataLayer;
    AudioNarrationLayer? audioLayer;

    for (final layer in widget.layerStack.layers) {
      if (layer is BookAnimationLayer) {
        bookLayer = layer;
      } else if (layer is FaceVideoLayer) {
        faceLayer = layer;
      } else if (layer is MetadataOverlayLayer) {
        metadataLayer = layer;
      } else if (layer is AudioNarrationLayer) {
        audioLayer = layer;
      }
    }

    final hasVideo = (faceLayer != null && _isInitialized) || (bookLayer != null && _isBookInitialized);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: tokens.coffeeBean,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Background Layers based on layout ─────────────────────────
            _buildLayoutContent(tokens, bookLayer, faceLayer, audioLayer),

            // ── Metadata Overlay ──────────────────────────────────────────
            if (metadataLayer != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        metadataLayer.title.isNotEmpty ? metadataLayer.title : 'Untitled Story',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (metadataLayer.dedication.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          metadataLayer.dedication,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // ── Play/Pause Control Overlay (if there's video) ─────────────
            if (hasVideo)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutContent(
    StorybridgeTokens tokens,
    BookAnimationLayer? book,
    FaceVideoLayer? face,
    AudioNarrationLayer? audio,
  ) {
    // 1. Audio Only
    if (face == null && book == null) {
      return Container(
        color: tokens.coffeeBean,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.audiotrack_rounded, size: 56, color: tokens.brightFern),
              const SizedBox(height: 12),
              Text(
                'Audio Narration Only',
                style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Book Only (No Face Video)
    if (face == null && book != null) {
      return SizedBox.expand(
        child: _buildBookView(tokens, book.path),
      );
    }

    // 3. Face Video Present
    if (face != null) {
      final videoWidget = _buildVideoWidget();

      // Face Led (Face is background/dominant, Book is PiP inset)
      if (face.isBackground) {
        return Stack(
          children: [
            Positioned.fill(child: videoWidget),
            if (book != null)
              Positioned(
                bottom: 80,
                right: 16,
                width: 100,
                height: 140,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white54, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.5),
                    child: _buildBookView(tokens, book.path),
                  ),
                ),
              ),
          ],
        );
      }

      // Book Led (Book is background/dominant, Face is overlay)
      if (face.isFloatingOverlay) {
        return Stack(
          children: [
            if (book != null) Positioned.fill(child: _buildBookView(tokens, book.path)),
            Positioned(
              top: 16,
              right: 16,
              width: 100,
              height: 133,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white54, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.5),
                  child: videoWidget,
                ),
              ),
            ),
          ],
        );
      }

      // Split View (Side-by-side)
      if (face.isSplitView) {
        return Row(
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                child: Center(child: videoWidget),
              ),
            ),
            Container(width: 1, color: Colors.white24),
            Expanded(
              child: book != null
                  ? _buildBookView(tokens, book.path)
                  : Container(color: tokens.coffeeBean),
            ),
          ],
        );
      }
    }

    // Default Fallback
    return Container(color: tokens.coffeeBean);
  }

  Widget _buildVideoWidget() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_isInitialized || _videoController == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white54),
          ),
        ),
      );
    }

    return FittedBox(
      key: _videoPlayerKey,
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _videoController!.value.size.width,
        height: _videoController!.value.size.height,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  Widget _buildBookView(StorybridgeTokens tokens, String path) {
    if (path.isEmpty) {
      return Container(color: tokens.coffeeBean);
    }

    final bool isVideo = path.endsWith('.mp4') || path.endsWith('.webm') || path.startsWith('blob:');
    if (isVideo) {
      if (_bookVideoController != null && _isBookInitialized) {
        return FittedBox(
          key: _bookVideoPlayerKey,
          fit: BoxFit.contain, // Ensure it fits the view entirely
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _bookVideoController!.value.size.width,
            height: _bookVideoController!.value.size.height,
            child: VideoPlayer(_bookVideoController!),
          ),
        );
      }
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white54),
          ),
        ),
      );
    }

    // Network image — use SafeNetworkImage which handles CORS/Firebase on web
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return SafeNetworkImage(
        imageUrl: path,
        fit: BoxFit.contain, // Ensure it fits the view entirely
        placeholder: _audioFallback(tokens),
      );
    }
    // Asset cover or dynamic path
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.contain, // Ensure it fits the view entirely
        errorBuilder: (_, __, ___) => _audioFallback(tokens),
      );
    }
    // Local file image (supported only on non-web platforms)
    if (!kIsWeb) {
      return Image.file(
        File(path),
        fit: BoxFit.contain, // Ensure it fits the view entirely
        errorBuilder: (_, __, ___) => _audioFallback(tokens),
      );
    }
    return _audioFallback(tokens);
  }

  Widget _audioFallback(StorybridgeTokens tokens) {
    return Container(
      color: tokens.coffeeBean,
      child: const Center(
        child: Icon(Icons.book_rounded, color: Colors.white38, size: 32),
      ),
    );
  }
}
