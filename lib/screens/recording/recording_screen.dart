// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../../theme/tokens.dart';
import '../../widgets/safe_image.dart';
import '../../providers/recording_flow_provider.dart';
import '../../models/recording_flow.dart';
import '../../models/page_timestamp.dart';
import '../../models/story.dart';
import '../../providers/stories_provider.dart';
import '../../providers/composite_draft_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/stories_service.dart';
import '../../widgets/pill_button.dart';
import 'web_recorder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// ─── Widget ───────────────────────────────────────────────────────────────────

class RecordingScreen extends ConsumerStatefulWidget {
  final String? storyId;
  final bool videoOn;

  const RecordingScreen({super.key, this.storyId, required this.videoOn});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  CameraController? _cameraController;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final PageController _pageController = PageController();

  bool _cameraPreviewReady = false;
  bool _isCameraRecording = false;
  bool _isAudioRecording = false;
  bool _cameraInitialising = false;
  bool _isSaving = false;
  bool _isProcessing = false;

  String _audioTempPath = '';

  // Story fetched from Firebase (populated during initState).
  Story? _currentStory;

  final List<PageTimestamp> _pageTimestamps = [];
  int _lastTrackedPage = -1;

  // Asset copies written to temp dir for ffmpeg compositing.
  // Key = page index; value = absolute path of the temp JPEG.
  final Map<int, String> _storyPageFiles = {};

  // PiP initial position — computed once from screen size in build().
  static const double _pipW = 120.0;
  static const double _pipH = 160.0;
  Offset? _pipInitialOffset;

  // Overlay entry for the PiP camera bubble.
  OverlayEntry? _pipOverlayEntry;

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  Timer? _bookFrameTimer;
  int _bookFrameCount = 0;
  String _bookFramesDirPath = '';
  bool _isCapturingFrame = false;
  int _bookStartTime = 0;
  int _cameraStartTime = 0;
  double _timestampOffsetMs = 0.0;
  int _bookFrameWidth = 720;
  int _bookFrameHeight = 1280;

  Future<void> _startBookTrackRecording() async {
    _bookFrameCount = 0;
    _isCapturingFrame = false;
    if (_bookStartTime == 0) {
      _bookStartTime = DateTime.now().millisecondsSinceEpoch;
    }

    int initialW = 720;
    int initialH = 1280;
    final boundary =
        _repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary != null && boundary.hasSize) {
      initialW = (boundary.size.width.toInt() ~/ 2) * 2;
      initialH = (boundary.size.height.toInt() ~/ 2) * 2;
    }

    if (kIsWeb) {
      final story = _currentStory;
      final maxPages = story?.pageTexts.length ?? 0;
      final urls = <String>[];
      for (int i = 0; i < maxPages; i++) {
        urls.add(_storyPageFiles[i] ?? '');
      }
      final flow = ref.read(recordingFlowProvider);
      await WebRecorder.startBookTrack(
        width: initialW,
        height: initialH,
        pageImageUrls: urls,
        initialPageIndex: flow.page,
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      _bookFramesDirPath =
          '${tempDir.path}/sb_frames_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(_bookFramesDirPath).create(recursive: true);
    }

    _bookFrameTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) async {
      final flow = ref.read(recordingFlowProvider);
      if (flow.paused || !_stopwatch.isRunning) return;
      if (_isCapturingFrame) return;

      if (kIsWeb) {
        // On Web, the JS book recorder draws the frames itself!
        // We don't need to capture the repaint boundary here.
        return;
      }

      _isCapturingFrame = true;
      try {
        final boundary =
            _repaintBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary != null && boundary.hasSize) {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (byteData != null) {
            final bytes = byteData.buffer.asUint8List();
            _bookFrameCount++;
            _bookFrameWidth = image.width;
            _bookFrameHeight = image.height;
            final framePath =
                '$_bookFramesDirPath/frame_${_bookFrameCount.toString().padLeft(5, '0')}.raw';
            await File(framePath).writeAsBytes(bytes);
          }
        }
      } catch (e) {
        debugPrint('Error capturing book frame: $e');
      } finally {
        _isCapturingFrame = false;
      }
    });
  }

  // ─── platform caps ────────────────────────────────────────────────────────

  bool get _cameraSupported {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  // ─── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Start the timer immediately so the counter starts ticking without delay
      _startTimer();

      // Pre-warm image cache AND camera in parallel so page transitions are
      // smooth and never compete with camera initialisation.
      await Future.wait([
        _precacheAndPrepareImages(),
        if (widget.videoOn && _cameraSupported)
          _warmUpCamera()
        else
          Future.value(),
      ]);
      if (mounted) {
        _updatePipOverlay();
        // On web with video, the PiP overlay insert is deferred to the next
        // frame via addPostFrameCallback inside _updatePipOverlay.  Wait two
        // frames so Flutter has inserted and rendered the CameraPreview widget
        // (and its <video> element) before the JS recorder tries to find it.
        if (kIsWeb && widget.videoOn && _cameraPreviewReady) {
          final c = Completer<void>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
          });
          await c.future;
        }
        await _startRecording();
      }
    });
  }

  @override
  void dispose() {
    _removePipOverlay();
    _timer?.cancel();
    _bookFrameTimer?.cancel();
    _pageController.dispose();
    _cameraController?.dispose();
    _audioRecorder.dispose();
    if (kIsWeb) {
      try {
        WebRecorder.stopRecording();
        WebRecorder.stopBookTrack();
      } catch (_) {}
    }
    super.dispose();
  }

  // ─── pre-warm image cache + copy assets for ffmpeg compositing ──────────────
  // Two jobs in one pass:
  //   1. precacheImage — decodes every page image into Flutter's GPU texture
  //      cache so page-swipe transitions are instantaneous and never stall the
  //      camera raster thread.
  //   2. rootBundle.load + File.write — copies each asset JPEG/PNG to a temp
  //      file path that ffmpeg can read natively after recording stops.

  Future<void> _precacheAndPrepareImages() async {
    if (widget.storyId == null) return;

    // Load pages for this story first on-demand
    if (widget.storyId != 'null') {
      await StoriesService.loadPagesForStory(widget.storyId!);
    }

    // Look up the story from the Riverpod stories provider.
    final stories = await ref.read(storiesProvider.future);
    final storyIdx = widget.storyId != null
        ? stories.indexWhere((s) => s.id == widget.storyId)
        : -1;
    final story = storyIdx != -1 ? stories[storyIdx] : null;
    if (story == null) return;
    if (mounted) setState(() => _currentStory = story);

    // 1. Pre-warm Flutter image cache asynchronously (works on all platforms including web).
    if (mounted) {
      final ctx = context;
      for (int i = 0; i < story.pageTexts.length; i++) {
        final assetPath = _pageAsset(story, i);
        if (assetPath.isEmpty) continue;
        try {
          final ImageProvider provider = assetPath.startsWith('http')
              ? CachedNetworkImageProvider(
                  assetPath,
                  cacheManager: DefaultCacheManager(),
                )
              : AssetImage(assetPath) as ImageProvider;
          
          // Do not await the precacheImage, let it resolve in the background so
          // we do not block starting the recording and timer.
          precacheImage(
            provider,
            ctx,
            onError: (exception, stackTrace) {
              debugPrint('Failed to precache image $assetPath: $exception');
            },
          );
        } catch (_) {}
      }
    }

    // On native mobile/desktop platforms, we don't need flat PNG rendering since
    // the repaint boundary captures normal Flutter widgets perfectly. Skipping
    // this saves massive CPU/GPU processing and starts the recording instantly.
    if (!kIsWeb) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    // 2. Render each page (illustration + background + text) to a PNG file/blob URL (Web only).
    try {
      Color cardColor = const Color(0xFFFBFBFB); // Fallback card background
      try {
        cardColor = Color(int.parse(story.bgColor.replaceFirst('#', '0xFF')));
      } catch (_) {}

      for (int i = 0; i < story.pageTexts.length; i++) {
        try {
          final assetPath = _pageAsset(story, i);

          final bytes = await _renderPageToBytes(
            imageAsset: assetPath,
            text: story.pageTexts[i],
            cardColor: cardColor,
            pageIndex: i,
            totalPages: story.pageTexts.length,
          );
          if (bytes != null) {
            final blobUrl = WebRecorder.createBlobUrl(bytes);
            _storyPageFiles[i] = blobUrl;
          }
        } catch (e) {
          debugPrint('Error preparing page $i: $e');
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Non-fatal — composite falls back to camera-only on failure.
    }
  }

  Future<Uint8List?> _renderPageToBytes({
    required String imageAsset,
    required String text,
    required Color cardColor,
    required int pageIndex,
    required int totalPages,
  }) async {
    try {
      return await _renderPageToBytesInternal(
        imageAsset: imageAsset,
        text: text,
        cardColor: cardColor,
        pageIndex: pageIndex,
        totalPages: totalPages,
      );
    } catch (e) {
      // Do NOT fall back to a text-only render — a PNG without the book image
      // would be stored in _storyPageFiles and every captured frame would show
      // text but no illustration (the QA "image missing" bug). Return null so
      // the caller skips storing this page and the live UI is used instead.
      debugPrint('Error rendering page $pageIndex: $e');
      return null;
    }
  }

  Future<Uint8List?> _renderPageToBytesInternal({
    required String imageAsset,
    required String text,
    required Color cardColor,
    required int pageIndex,
    required int totalPages,
  }) async {
    // Canvas is 720 × 1280 (portrait).
    // Layout mirrors the new recording screen UI:
    //   Top: Story illustration (BoxFit.cover, edge-to-edge)
    //   Middle: Green progress bar
    //   Bottom: Story text
    const double canvasW = 720.0;
    const double canvasH = 1280.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

    // 1. Background (full canvas)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()..color = cardColor,
    );

    const double imgAreaX = 0.0;
    const double imgAreaY = 0.0;
    const double imgAreaW = canvasW;
    const double imgAreaH = 600.0; // full top area

    // 2. Story illustration — top, BoxFit.cover
    try {
      if (imageAsset.isEmpty) throw Exception('No image asset');
      final Uint8List imageBytes;
      if (imageAsset.startsWith('http')) {
        // Use the cache manager so we serve from the on-disk cache that was
        // populated by precacheImage() — avoids a redundant network request
        // and works offline if the asset was previously downloaded.
        final cachedFile = await DefaultCacheManager().getSingleFile(
          imageAsset,
        );
        imageBytes = await cachedFile.readAsBytes();
      } else {
        final byteData = await rootBundle.load(imageAsset);
        imageBytes = byteData.buffer.asUint8List();
      }
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final uiImage = frameInfo.image;

      final srcW = uiImage.width.toDouble();
      final srcH = uiImage.height.toDouble();

      // Scale to cover
      final double scale = (srcW / srcH > imgAreaW / imgAreaH)
          ? imgAreaH / srcH
          : imgAreaW / srcW;

      final double drawW = srcW * scale;
      final double drawH = srcH * scale;
      final double left = imgAreaX + (imgAreaW - drawW) / 2.0;
      final double top = imgAreaY + (imgAreaH - drawH) / 2.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(imgAreaX, imgAreaY, imgAreaW, imgAreaH));
      canvas.drawImageRect(
        uiImage,
        Rect.fromLTWH(0, 0, srcW, srcH),
        Rect.fromLTWH(left, top, drawW, drawH),
        Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();
      uiImage.dispose();
    } catch (_) {
      // Placeholder tint when the asset cannot be loaded
      canvas.drawRect(
        Rect.fromLTWH(imgAreaX, imgAreaY, imgAreaW, imgAreaH),
        Paint()..color = Colors.black.withValues(alpha: 0.06),
      );
    }

    // 3. Green progress bar
    const double contentPad = 48.0;
    const double barY = imgAreaY + imgAreaH + 24.0; // 624.0
    final progressTrackPaint = Paint()
      ..color = const Color(0xFF38A700).withValues(alpha: 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(contentPad, barY, canvasW - contentPad * 2, 8),
        const Radius.circular(4),
      ),
      progressTrackPaint,
    );

    final progressPaint = Paint()..color = const Color(0xFF38A700);
    final double progressWidth = totalPages > 0
        ? (canvasW - contentPad * 2) * ((pageIndex + 1) / totalPages)
        : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(contentPad, barY, progressWidth, 8),
        const Radius.circular(4),
      ),
      progressPaint,
    );

    // 4. Story text — bottom, scrollable in UI, fully rendered here
    const double textY = barY + 32.0; // 656.0
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF110B11), // coffeeBean
          fontSize: 30,
          fontWeight: FontWeight.bold,
          height: 1.65,
          fontFamily: 'sans-serif',
        ),
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: canvasW - contentPad * 2);

    textPainter.paint(canvas, Offset(contentPad, textY));

    // 6. Return PNG bytes
    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasW.toInt(), canvasH.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return pngBytes?.buffer.asUint8List();
  }

  /// Returns the image URL for [pageIndex] of [story].
  /// Falls back to the cover asset if this page has no image.
  String _pageAsset(Story story, int i) {
    if (i < story.pageImages.length && story.pageImages[i].isNotEmpty) {
      return story.pageImages[i];
    }
    return story.coverAsset;
  }

  // ─── camera warm-up ───────────────────────────────────────────────────────

  Future<void> _warmUpCamera() async {
    if (mounted) setState(() => _cameraInitialising = true);
    try {
      if (!kIsWeb) {
        final preCtrl = ref.read(activeCameraControllerProvider);
        if (preCtrl != null && preCtrl.value.isInitialized) {
          _cameraController = preCtrl;
          ref.read(activeCameraControllerProvider.notifier).state = null;
          if (mounted) {
            setState(() {
              _cameraInitialising = false;
              _cameraPreviewReady = true;
            });
            _updatePipOverlay();
          }
          return;
        }
      }

      if (!kIsWeb) {
        final cam = await Permission.camera.request();
        final mic = await Permission.microphone.request();
        if (!cam.isGranted || !mic.isGranted) return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _cameraController = ctrl;
      setState(() {
        _cameraInitialising = false;
        _cameraPreviewReady = true;
      });
      _updatePipOverlay();
    } catch (_) {
      if (mounted) setState(() => _cameraInitialising = false);
    }
  }

  // ─── start recording ──────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!kIsWeb) {
      final tmp = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      _audioTempPath = '${tmp.path}/sb_rec_$ts.m4a';
    }

    if (widget.videoOn && _cameraSupported) {
      await _startVideoRecording();
    } else {
      await _startAudioRecording();
    }
  }

  Future<void> _startVideoRecording() async {
    // ── Web ──────────────────────────────────────────────────────────────────
    // Camera init (for the PIP overlay) is kept COMPLETELY separate from the
    // JS canvas recorder so that a JS error never tears down the camera preview.
    if (kIsWeb) {
      // Ensure the camera is warmed up (shows narrator PIP).
      if (!_cameraPreviewReady ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized) {
        await _warmUpCamera();
      }
      if (mounted && _cameraPreviewReady) _updatePipOverlay();

      // Start the JS canvas composite recorder.
      // The JS start() never rejects (top-level try-catch inside), so the
      // Dart catch below will only fire for bridge-level errors.
      try {
        await _startBookTrackRecording();
        final urls = List<String>.from(_storyPageFiles.values);
        final flow = ref.read(recordingFlowProvider);
        await WebRecorder.startRecording(
          pageImageUrls: urls,
          initialPageIndex: flow.page,
        );
        _cameraStartTime = DateTime.now().millisecondsSinceEpoch;
        _timestampOffsetMs = (_cameraStartTime - _bookStartTime).toDouble();
        if (mounted) {
          setState(() => _isCameraRecording = true);
        }
      } catch (_) {
        // Bridge error — _isCameraRecording stays false.
      }

      // ALWAYS also start the Flutter audio recorder in parallel as a fallback.
      // If the JS canvas recorder produces a valid blob URL on stop(), we use
      // that composite video and discard the audio. If JS returns null (its
      // internal start failed silently), the audio path is used instead so the
      // session is ALWAYS saveable.
      await _startAudioRecording();
      return;
    }

    // ── Native ───────────────────────────────────────────────────────────────
    if (_cameraPreviewReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      try {
        await _startBookTrackRecording();
        await _cameraController!.startVideoRecording();
        _cameraStartTime = DateTime.now().millisecondsSinceEpoch;
        _timestampOffsetMs = (_cameraStartTime - _bookStartTime).toDouble();
        if (mounted) {
          setState(() => _isCameraRecording = true);
          _updatePipOverlay();
        }
        return;
      } catch (_) {
        _cameraController?.dispose();
        _cameraController = null;
        if (mounted) {
          setState(() => _cameraPreviewReady = false);
          _updatePipOverlay();
        }
      }
    }

    if (mounted) setState(() => _cameraInitialising = true);
    try {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!cam.isGranted || !mic.isGranted)
        throw Exception('Permission denied');
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras');
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await ctrl.initialize();
      _cameraController = ctrl;
      await _startBookTrackRecording();
      await ctrl.startVideoRecording();
      _cameraStartTime = DateTime.now().millisecondsSinceEpoch;
      _timestampOffsetMs = (_cameraStartTime - _bookStartTime).toDouble();
      if (mounted) {
        setState(() {
          _isCameraRecording = true;
          _cameraPreviewReady = true;
          _cameraInitialising = false;
        });
        _updatePipOverlay();
      }
    } catch (_) {
      _cameraController?.dispose();
      _cameraController = null;
      if (mounted) {
        setState(() {
          _cameraPreviewReady = false;
          _cameraInitialising = false;
        });
        _updatePipOverlay();
      }
      await _startAudioRecording();
    }
  }

  Future<void> _startAudioRecording() async {
    try {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          return;
        }
      }
      final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
      await _audioRecorder.start(
        RecordConfig(encoder: encoder),
        path: _audioTempPath,
      );
      if (mounted) setState(() => _isAudioRecording = true);
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
  }

  void _startTimer() {
    _bookStartTime = DateTime.now().millisecondsSinceEpoch;
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _stopwatch.isRunning) {
        ref
            .read(recordingFlowProvider.notifier)
            .setElapsedMs(_stopwatch.elapsedMilliseconds);
      }
    });
    ref
        .read(recordingFlowProvider.notifier)
        .update(phase: RecordingPhase.recording);
  }

  // ─── page tracking ────────────────────────────────────────────────────────

  void _trackPageIfChanged(int page) {
    if (page != _lastTrackedPage) {
      _lastTrackedPage = page;
      _pageTimestamps.add(
        PageTimestamp(
          pageIndex: page,
          elapsedMs: _stopwatch.elapsedMilliseconds,
        ),
      );
    }
  }

  // ─── page navigation ──────────────────────────────────────────────────────

  void _goToPage(int delta, int maxPages) {
    final flow = ref.read(recordingFlowProvider);
    final newPage = (flow.page + delta).clamp(0, maxPages - 1);
    _pageController.animateToPage(
      newPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ─── pause / resume ───────────────────────────────────────────────────────

  Future<void> _pauseRecording() async {
    if (_isCameraRecording) {
      await _cameraController?.pauseVideoRecording();
    } else if (_isAudioRecording) {
      try {
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.pause();
        }
      } catch (e) {
        debugPrint('Error pausing audio: $e');
      }
    }
    _stopwatch.stop();
    ref.read(recordingFlowProvider.notifier).setPaused(true);
  }

  Future<void> _resumeRecording() async {
    if (_isCameraRecording) {
      await _cameraController?.resumeVideoRecording();
    } else if (_isAudioRecording) {
      try {
        if (await _audioRecorder.isRecording() || true) {
          // check fallback try-catch
          await _audioRecorder.resume();
        }
      } catch (e) {
        debugPrint('Error resuming audio: $e');
      }
    }
    _stopwatch.start();
    ref.read(recordingFlowProvider.notifier).setPaused(false);
  }

  // ─── stop and save ────────────────────────────────────────────────────────
  Future<void> _waitUntilFileFlushed(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    int prevSize = -1;
    for (int i = 0; i < 15; i++) {
      final size = file.lengthSync();
      if (size > 0 && size == prevSize) {
        break;
      }
      prevSize = size;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // ─── stop and save ────────────────────────────────────────────────────────

  Future<void> _stopRecording({bool discard = false}) async {
    if (_isSaving || _isProcessing) return;
    _timer?.cancel();
    _stopwatch.stop();

    final durationSecondsDouble = _stopwatch.elapsedMilliseconds / 1000.0;
    final recordDuration = durationSecondsDouble > 0.0
        ? durationSecondsDouble
        : 1.0;

    if (discard) {
      _removePipOverlay();
      context.go(
        widget.storyId != null ? '/library/book/${widget.storyId}' : '/library',
      );
      return;
    }

    // Keep PIP visible while saving so the narrator can see themselves.
    // It will be removed right before navigation.
    setState(() => _isSaving = true);

    String? videoPath;
    String? audioPath;
    String? bookVideoPath;

    _bookFrameTimer?.cancel();
    _bookFrameTimer = null;

    if (_isCameraRecording) {
      try {
        final String? rawPath;
        if (kIsWeb) {
          rawPath = await WebRecorder.stopRecording();
        } else {
          final xfile = await _cameraController?.stopVideoRecording();
          rawPath = xfile?.path;
        }

        if (rawPath != null && rawPath.isNotEmpty) {
          if (kIsWeb) {
            videoPath = rawPath;
            bookVideoPath = await WebRecorder.stopBookTrack();
          } else {
            // Wait until the camera video file is fully flushed to disk
            await _waitUntilFileFlushed(rawPath);

            // Move raw camera file to the documents directory (persistent across
            // the session) so the compositor can still find it at export time.
            String finalRawPath = rawPath;
            if (File(rawPath).existsSync()) {
              try {
                final docs = await getApplicationDocumentsDirectory();
                final dest =
                    '${docs.path}/sb_cam_${DateTime.now().millisecondsSinceEpoch}.mp4';
                await File(rawPath).copy(dest);
                try {
                  File(rawPath).deleteSync();
                } catch (_) {}
                finalRawPath = dest;
              } catch (_) {}
            }
            videoPath = finalRawPath;

            // Switch overlay to compositing state.
            setState(() {
              _isSaving = false;
              _isProcessing = true;
            });

            // Compile captured book track frames to mp4 — also saved to the
            // documents directory so it persists until export.
            final docs = await getApplicationDocumentsDirectory();
            final outBookPath =
                '${docs.path}/sb_book_${DateTime.now().millisecondsSinceEpoch}.mp4';

            final double actualFps = _bookFrameCount > 0
                ? (_bookFrameCount / recordDuration)
                : 30.0;
            debugPrint(
              'Compiling book frames: total frames=$_bookFrameCount, duration=$recordDuration s, calculated fps=$actualFps',
            );

            final args = [
              '-f',
              'rawvideo',
              '-pix_fmt',
              'rgba',
              '-s',
              '${_bookFrameWidth}x$_bookFrameHeight',
              '-framerate',
              '$actualFps',
              '-i',
              '$_bookFramesDirPath/frame_%05d.raw',
              '-r',
              '30',
              '-c:v',
              'libx264',
              '-preset',
              'ultrafast',
              '-crf',
              '28',
              '-pix_fmt',
              'yuv420p',
              '-threads',
              '0',
              outBookPath,
            ];
            final session = await FFmpegKit.executeWithArguments(args);
            final rc = await session.getReturnCode();
            setState(() => _isProcessing = false);

            if (ReturnCode.isSuccess(rc) && File(outBookPath).existsSync()) {
              bookVideoPath = outBookPath;
              try {
                Directory(_bookFramesDirPath).deleteSync(recursive: true);
              } catch (_) {}
            } else {
              bookVideoPath = null;
            }
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _isProcessing = false;
          });
        }
      }
    }

    if (_isAudioRecording) {
      if (mounted) setState(() => _isSaving = true);
      try {
        final isRec = await _audioRecorder.isRecording();
        final returned = isRec ? await _audioRecorder.stop() : null;
        if (kIsWeb) {
          // On web the audio recorder is always started as a fallback backup.
          // Only promote it to audioPath if the JS canvas recorder did NOT
          // produce a composite video — if it did, we already have something
          // better and the audio track is redundant.
          if (videoPath == null && returned != null && returned.isNotEmpty) {
            audioPath = returned;
          }
        } else {
          final src = returned ?? _audioTempPath;
          if (src.isNotEmpty) {
            await _waitUntilFileFlushed(src);
            if (File(src).existsSync()) {
              try {
                final docs = await getApplicationDocumentsDirectory();
                final dest =
                    '${docs.path}/sb_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
                await File(src).copy(dest);
                audioPath = dest;
                try {
                  File(src).deleteSync();
                } catch (_) {}
              } catch (_) {
                audioPath = src;
              }
            }
          }
        }
      } catch (_) {}
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;

    if (videoPath == null && audioPath == null) {
      if (kDebugMode || kIsWeb) {
        audioPath = 'mock_audio.m4a';
      } else {
        // Nothing captured — keep PIP alive so narrator can retry.
        _showNothingRecordedDialog();
        return;
      }
    }

    // Remove PIP now that we have a confirmed recording and are navigating.
    _removePipOverlay();

    final flow = ref.read(recordingFlowProvider);
    final durationSeconds = _stopwatch.elapsed.inSeconds;
    final durationStr = durationSeconds < 60
        ? '$durationSeconds sec'
        : '${(durationSeconds / 60).toStringAsFixed(1)} min';

    final storyTitle = _currentStory?.title;
    final recId = 'rec-${DateTime.now().millisecondsSinceEpoch}';

    ref
        .read(compositeDraftProvider.notifier)
        .initFromSession(
          id: recId,
          storyId: widget.storyId,
          title: flow.ownTitle ?? storyTitle ?? 'My story',
          faceVideoPath: videoPath,
          bookAnimationPath: _currentStory?.coverAsset,
          audioTrackPath: audioPath,
          bookVideoPath: bookVideoPath,
          timestampOffsetMs: _timestampOffsetMs,
          duration: durationStr,
          durationSeconds: durationSeconds,
          recordedAt: DateTime.now().millisecondsSinceEpoch,
          pageTimestampsJson: jsonEncode(
            _pageTimestamps.map((t) => t.toJson()).toList(),
          ),
        );

    context.go('/edit/$recId');
  }

  void _showNothingRecordedDialog() {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.porcelain,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: tokens.tigerFlame),
            const SizedBox(width: 8),
            Text(
              'Nothing captured',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: tokens.coffeeBean,
              ),
            ),
          ],
        ),
        content: Text(
          'No audio or video was captured.\n\n'
          '• Check microphone permission.\n'
          '• Check camera permission (if recording video).',
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.5,
            color: tokens.darkSlate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isCameraRecording = false;
                _isAudioRecording = false;
                _cameraPreviewReady = false;
                _pageTimestamps.clear();
                _lastTrackedPage = -1;
                _stopwatch.reset();
              });
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (widget.videoOn && _cameraSupported) await _warmUpCamera();
                if (mounted) await _startRecording();
              });
            },
            child: Text(
              'Try again',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: tokens.brightFern,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(
                widget.storyId != null
                    ? '/library/book/${widget.storyId}'
                    : '/library',
              );
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(color: tokens.darkSlate),
            ),
          ),
        ],
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final flow = ref.watch(recordingFlowProvider);
    final story = _currentStory;
    final maxPages = story?.pageTexts.length ?? 0;
    final screenSize = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    final isSubscribed = ref.watch(isSubscribedProvider);
    if (story != null && story.isPremium && !isSubscribed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/paywall?storyId=${story.id}');
      });
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Compute PiP initial position once from real screen dimensions.
    _pipInitialOffset ??= Offset(screenSize.width - _pipW - 16, topPad + 56);

    if (_isCameraRecording || _isAudioRecording) {
      _trackPageIfChanged(flow.page);
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Stack(
          children: [
            // ── Full-screen story pages ───────────────────────────────────
            _buildPagesSection(tokens, flow, story, maxPages),

            // ── Translucent REC bar (top) ─────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildRecBar(tokens, flow, maxPages),
            ),

            // ── Left chevron ──────────────────────────────────────────────
            if (maxPages > 1 && flow.page > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildChevron(
                    Icons.chevron_left_rounded,
                    () => _goToPage(-1, maxPages),
                    label: 'Previous page',
                  ),
                ),
              ),

            // ── Right chevron ─────────────────────────────────────────────
            if (maxPages > 1 && flow.page < maxPages - 1)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildChevron(
                    Icons.chevron_right_rounded,
                    () => _goToPage(1, maxPages),
                    label: 'Next page',
                  ),
                ),
              ),

            // ── Cancel X ─────────────────────────────────────────────────
            Positioned(
              top: topPad + 52,
              left: 12,
              child: GestureDetector(
                onTap: () => _showDiscardSheet(tokens),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),

            // ── Done bar (bottom) — only on the last page (or own-story) ──
            if (maxPages == 0 || flow.page == maxPages - 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildDoneBar(tokens, flow),
              ),

            // ── Compositing overlay ───────────────────────────────────────
            if (_isProcessing) _buildLoadingOverlay('Compositing your video…'),

            // ── Saving overlay ────────────────────────────────────────────
            if (_isSaving) _buildLoadingOverlay('Saving your recording…'),
          ],
        ),
      ),
    );
  }

  // ─── story pages (full screen, no RepaintBoundary) ────────────────────────

  Widget _buildPagesSection(
    StorybridgeTokens tokens,
    RecordingFlowState flow,
    Story? story,
    int maxPages,
  ) {
    if (story == null || maxPages == 0) {
      return Container(
        color: tokens.cream,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              flow.ownTitle ?? 'Recording your own story…\n\nSpeak freely.',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.6,
                color: tokens.coffeeBean,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    Color cardColor = tokens.porcelain;
    try {
      cardColor = Color(int.parse(story.bgColor.replaceFirst('#', '0xFF')));
    } catch (_) {}

    final fontSize = kStoryFontPx[flow.textSize.name] ?? 18.0;

    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: PageView.builder(
        controller: _pageController,
        itemCount: maxPages,
        onPageChanged: (newPage) {
          ref.read(recordingFlowProvider.notifier).update(page: newPage);
          _trackPageIfChanged(newPage);
          if (kIsWeb) {
            WebRecorder.updatePageIndex(newPage);
          }
        },
        itemBuilder: (_, i) {
          String imagePath = story.coverAsset;
          if (i < story.pageImages.length && story.pageImages[i].isNotEmpty) {
            imagePath = story.pageImages[i];
          }

          return _StoryPageItem(
            key: ValueKey('page_$i'),
            imageAsset: imagePath,
            preRenderedPath: _storyPageFiles[i],
            text: story.pageTexts[i],
            cardColor: cardColor,
            fontSize: fontSize,
            tokens: tokens,
            isLastPage: i == maxPages - 1,
            pageIndex: i,
            totalPages: maxPages,
          );
        },
      ),
    );
  }

  void _updatePipOverlay() {
    if (!mounted) return;

    final videoActive =
        widget.videoOn && _cameraPreviewReady && _cameraController != null;

    if (videoActive) {
      if (_pipOverlayEntry == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _pipOverlayEntry != null) return;
          try {
            _pipOverlayEntry = OverlayEntry(
              builder: (context) {
                final media = MediaQuery.of(context);
                final screenSize = media.size;
                final tokens = Theme.of(
                  context,
                ).extension<StorybridgeTokens>()!;
                final topPad = media.padding.top;

                _pipInitialOffset ??= Offset(
                  screenSize.width - _pipW - 16,
                  topPad + 56,
                );

                return _DraggablePip(
                  key: const ValueKey('pip_overlay'),
                  initialOffset: _pipInitialOffset!,
                  pipW: _pipW,
                  pipH: _pipH,
                  screenSize: screenSize,
                  child: _buildPipCamera(tokens),
                );
              },
            );
            Overlay.of(context).insert(_pipOverlayEntry!);
          } catch (_) {}
        });
      } else {
        _pipOverlayEntry!.markNeedsBuild();
      }
    } else {
      _removePipOverlay();
    }
  }

  void _removePipOverlay() {
    _pipOverlayEntry?.remove();
    _pipOverlayEntry = null;
  }

  // ─── PiP camera bubble ────────────────────────────────────────────────────

  Widget _buildPipCamera(StorybridgeTokens tokens) {
    final ready =
        _cameraPreviewReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Container(
      width: _pipW,
      height: _pipH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white30, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: ready
            ? CameraPreview(_cameraController!)
            : Container(
                color: tokens.coffeeBean,
                child: const Center(
                  child: Icon(
                    Icons.mic_rounded,
                    color: Colors.white38,
                    size: 24,
                  ),
                ),
              ),
      ),
    );
  }

  // ─── REC bar overlay ──────────────────────────────────────────────────────

  Widget _buildRecBar(
    StorybridgeTokens tokens,
    RecordingFlowState flow,
    int maxPages,
  ) {
    final dur = Duration(milliseconds: flow.elapsedMs);
    final time = [
      dur.inHours,
      dur.inMinutes.remainder(60),
      dur.inSeconds.remainder(60),
    ].map((s) => s.toString().padLeft(2, '0')).join(':');

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        10,
      ),
      child: Row(
        children: [
          _RecordingDot(color: tokens.recordRed, isPaused: flow.paused),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.robotoMono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (maxPages > 0) ...[
            Text(
              '${flow.page + 1} / $maxPages',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
              ),
            ),
            const SizedBox(width: 14),
          ],
          GestureDetector(
            onTap: flow.paused ? _resumeRecording : _pauseRecording,
            child: Icon(
              flow.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white70,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ─── chevron navigation ───────────────────────────────────────────────────

  Widget _buildChevron(
    IconData icon,
    VoidCallback onTap, {
    required String label,
  }) {
    return Semantics(
      label: label,
      button: true,
      enabled: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 30),
        ),
      ),
    );
  }

  // ─── Done bar (bottom gradient overlay) ──────────────────────────────────

  Widget _buildDoneBar(StorybridgeTokens tokens, RecordingFlowState flow) {
    final active =
        (_isCameraRecording || _isAudioRecording) &&
        !_isSaving &&
        !_isProcessing;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: PillButton(
        label: 'Done — save recording',
        variant: PillVariant.primary,
        fullWidth: true,
        onPressed: active ? () => _stopRecording() : null,
      ),
    );
  }

  // ─── loading overlay ──────────────────────────────────────────────────────

  Widget _buildLoadingOverlay(String message) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: tokens.porcelain,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: tokens.brightFern),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: tokens.coffeeBean,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── discard sheet ────────────────────────────────────────────────────────

  void _showDiscardSheet(StorybridgeTokens tokens) {
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.porcelain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Discard this recording?',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: tokens.coffeeBean,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "You'll lose everything recorded so far.",
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: tokens.darkSlate,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PillButton(
                label: 'Keep recording',
                variant: PillVariant.secondary,
                fullWidth: true,
                onPressed: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 12),
              PillButton(
                label: 'Discard & exit',
                variant: PillVariant.outline,
                foregroundColor: tokens.recordRed,
                fullWidth: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _stopRecording(discard: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RecordingDot — pulsing REC indicator
// ─────────────────────────────────────────────────────────────────────────────

class _RecordingDot extends StatefulWidget {
  final Color color;
  final bool isPaused;
  const _RecordingDot({required this.color, required this.isPaused});

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (widget.isPaused) return dot;
    return FadeTransition(opacity: _ctrl, child: dot);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DraggablePip — owns its own position state so drags never rebuild the
// parent RecordingScreen (and therefore never cause the PageView to flicker).
// ─────────────────────────────────────────────────────────────────────────────

class _DraggablePip extends StatefulWidget {
  final Offset initialOffset;
  final double pipW;
  final double pipH;
  final Size screenSize;
  final Widget child;

  const _DraggablePip({
    super.key,
    required this.initialOffset,
    required this.pipW,
    required this.pipH,
    required this.screenSize,
    required this.child,
  });

  @override
  State<_DraggablePip> createState() => _DraggablePipState();
}

class _DraggablePipState extends State<_DraggablePip> {
  // ValueNotifier instead of setState — position updates skip the widget
  // rebuild pipeline entirely, so the CameraPreview texture is never
  // invalidated during a drag.
  late final ValueNotifier<Offset> _offsetNotifier;

  @override
  void initState() {
    super.initState();
    _offsetNotifier = ValueNotifier(widget.initialOffset);
  }

  @override
  void didUpdateWidget(covariant _DraggablePip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clamp the current offset if the screen boundaries or PiP dimensions change
    if (oldWidget.screenSize != widget.screenSize ||
        oldWidget.pipW != widget.pipW ||
        oldWidget.pipH != widget.pipH) {
      final cur = _offsetNotifier.value;
      _offsetNotifier.value = Offset(
        cur.dx.clamp(0.0, widget.screenSize.width - widget.pipW),
        cur.dy.clamp(0.0, widget.screenSize.height - widget.pipH),
      );
    }
  }

  @override
  void dispose() {
    _offsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ValueListenableBuilder<Offset>(
        valueListenable: _offsetNotifier,
        // The GestureDetector and widget.child are passed as the static child
        // of ValueListenableBuilder. Thus, when _offsetNotifier triggers,
        // only the builder runs, applying the paint translation without layout invalidations.
        builder: (context, offset, child) {
          return Transform.translate(offset: offset, child: child!);
        },
        child: RepaintBoundary(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) {
              final cur = _offsetNotifier.value;
              _offsetNotifier.value = Offset(
                (cur.dx + d.delta.dx).clamp(
                  0.0,
                  widget.screenSize.width - widget.pipW,
                ),
                (cur.dy + d.delta.dy).clamp(
                  0.0,
                  widget.screenSize.height - widget.pipH,
                ),
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StoryPageItem — a kept-alive page widget so image textures are not evicted
// when the user swipes between pages, preventing reload flicker on all platforms.
// ─────────────────────────────────────────────────────────────────────────────

class _StoryPageItem extends StatefulWidget {
  final String imageAsset;
  final String? preRenderedPath;
  final String text;
  final Color cardColor;
  final double fontSize;
  final StorybridgeTokens tokens;
  final bool isLastPage;
  final int pageIndex;
  final int totalPages;

  const _StoryPageItem({
    super.key,
    required this.imageAsset,
    this.preRenderedPath,
    required this.text,
    required this.cardColor,
    required this.fontSize,
    required this.tokens,
    required this.isLastPage,
    required this.pageIndex,
    required this.totalPages,
  });

  @override
  State<_StoryPageItem> createState() => _StoryPageItemState();
}

class _StoryPageItemState extends State<_StoryPageItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Widget _buildPlaceholder(bool isPortrait) {
    return ColoredBox(
      color: widget.tokens.darkSlate.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: widget.tokens.darkSlate.withValues(alpha: 0.25),
          size: isPortrait ? 56 : 36,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;
    final screenH = mq.size.height;
    final isPortrait = mq.orientation == Orientation.portrait;

    // Reserve space for the done-bar only on the last page.
    final doneBarClearance = widget.isLastPage
        ? (96.0 + bottomInset)
        : (24.0 + bottomInset);

    // If pre-rendered path (flat image of the page) is available (especially on Web to avoid PlatformView/CORS issues during capture),
    // we render it directly as a full-screen image.
    if (widget.preRenderedPath != null && !kIsWeb) {
      return ColoredBox(
        color: widget.cardColor,
        child: Center(
          child: AspectRatio(
            aspectRatio: 720 / 1280,
            child:
                widget.preRenderedPath!.startsWith('http') ||
                    widget.preRenderedPath!.startsWith('blob')
                ? (kIsWeb
                      ? Image.network(
                          widget.preRenderedPath!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(isPortrait),
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.preRenderedPath!,
                          cacheManager: DefaultCacheManager(),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                          placeholder: (context, url) =>
                              _buildPlaceholder(isPortrait),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(isPortrait),
                        ))
                : Image.file(
                    File(widget.preRenderedPath!),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(isPortrait),
                  ),
          ),
        ),
      );
    }

    // Cover height for the image area:
    final double imageHeight = isPortrait ? screenH * 0.48 : screenH * 0.38;

    return ColoredBox(
      color: widget.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top: Illustration (Full cover edge-to-edge) ───────────────
          Container(
            height: imageHeight,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                widget.imageAsset.startsWith('http') ||
                    widget.imageAsset.startsWith('https')
                ? (kIsWeb
                      ? SafeNetworkImage(
                          imageUrl: widget.imageAsset,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: imageHeight,
                          placeholder: _buildPlaceholder(isPortrait),
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.imageAsset,
                          cacheManager: DefaultCacheManager(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: imageHeight,
                          filterQuality: FilterQuality.low,
                          placeholder: (context, url) =>
                              _buildPlaceholder(isPortrait),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(isPortrait),
                        ))
                : Image.asset(
                    widget.imageAsset,
                    fit: BoxFit.cover, // Cover edge-to-edge
                    gaplessPlayback: true,
                    width: double.infinity,
                    height: imageHeight,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(isPortrait),
                  ),
          ),

          // ── Middle: Green Progress Bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.totalPages > 0
                    ? (widget.pageIndex + 1) / widget.totalPages
                    : 0.0,
                backgroundColor: widget.tokens.brightFern.withValues(
                  alpha: 0.15,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.tokens.brightFern,
                ),
                minHeight: 8,
              ),
            ),
          ),

          // ── Bottom: Scrollable text view ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, doneBarClearance),
              child: Text(
                widget.text,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.fontSize,
                  height: 1.65,
                  color: widget.tokens.coffeeBean,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
