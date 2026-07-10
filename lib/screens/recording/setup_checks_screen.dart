// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/tokens.dart';
import '../../providers/recording_flow_provider.dart';
import '../../widgets/pill_button.dart';

class SetupChecksScreen extends ConsumerStatefulWidget {
  final String? storyId;
  const SetupChecksScreen({super.key, this.storyId});

  @override
  ConsumerState<SetupChecksScreen> createState() => _SetupChecksScreenState();
}

class _SetupChecksScreenState extends ConsumerState<SetupChecksScreen>
    with TickerProviderStateMixin {
  // ── mic ───────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _animTimer;

  bool _micChecking = true;
  bool _micGranted = false;
  bool _micDenied = false;
  bool _micPermanentlyDenied = false;
  // true once we see real audio — gates the "Start recording" button
  bool _micConfirmed = false;
  double _amplitude = -60.0;
  Timer? _micConfirmTimer;
  late AnimationController _micTickAnim;

  // ── camera ────────────────────────────────────────────────────────────────
  CameraController? _cameraController;

  bool _camLoading = true;
  bool _camGranted = false;
  bool _camDenied = false;
  bool _camPermanentlyDenied = false;
  bool _camNoHardware = false;
  bool _videoOn = true;
  late AnimationController _camTickAnim;

  // ─── platform ─────────────────────────────────────────────────────────────

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

  /// permission_handler works on Android / iOS / macOS only.
  bool get _usePermissionHandler {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  // Mic must be granted AND confirmed (waveform heard), or denied (skip).
  bool get _canStart =>
      (_micConfirmed || _micDenied) &&
      (!_cameraSupported || !_videoOn || _camGranted);

  /// On iOS/macOS the OS only shows a permission dialog once.
  /// After the first denial, re-calling request() returns denied instantly
  /// without any dialog. We must send the user to Settings instead.
  bool get _micNeedsSettings =>
      _micPermanentlyDenied ||
      (kIsWeb && _micDenied) ||
      (_usePermissionHandler &&
          _micDenied &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS));

  bool get _camNeedsSettings =>
      _camPermanentlyDenied ||
      (_usePermissionHandler &&
          _camDenied &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS));

  // ─── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _micTickAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _camTickAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _videoOn = ref.read(recordingFlowProvider).videoOn;

    // Defer to after first frame so setState is safe, and chain mic → camera
    // so the dialogs appear in the same order as the UI cards (mic first).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkMic();
      if (!mounted) return;
      if (_cameraSupported && _videoOn) {
        await _initCamera();
      } else {
        setState(() {
          _camLoading = false;
          _camGranted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _animTimer?.cancel();
    _micConfirmTimer?.cancel();
    _micTickAnim.dispose();
    _camTickAnim.dispose();
    _recorder.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─── mic permission + amplitude stream ────────────────────────────────────

  Future<void> _checkMic() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _animTimer?.cancel();
    _micConfirmTimer?.cancel();
    // Stop any previous monitoring recording before re-checking.
    try { await _recorder.stop(); } catch (_) {}

    setState(() {
      _micChecking = true;
      _micGranted = false;
      _micDenied = false;
      _micPermanentlyDenied = false;
      _micConfirmed = false;
      _amplitude = -60.0;
    });

    try {
      bool granted;

      if (_usePermissionHandler) {
        final status = await Permission.microphone.request();
        if (status.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _micChecking = false;
              _micDenied = true;
              _micPermanentlyDenied = true;
            });
          }
          return;
        }
        granted = status.isGranted;
      } else {
        // Web / Windows / Linux — the record package handles the browser/OS prompt.
        granted = await _recorder.hasPermission();
      }

      if (!mounted) return;

      if (granted) {
        // onAmplitudeChanged only emits while the recorder is in recording state.
        // Start a silent monitoring session — the data is discarded; we only
        // need the amplitude stream to detect voice activity.
        try {
          final path = kIsWeb
              ? ''
              : '${(await getTemporaryDirectory()).path}/sb_mic_chk_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _recorder.start(
            RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc),
            path: path,
          );
        } catch (_) {
          // Can't start monitoring — amplitude stream stays silent, but the
          // auto-confirm fallback timer will still enable the proceed button.
        }

        _amplitudeSub = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen(
          (amp) {
            if (!mounted) return;
            final level = amp.current.clamp(-60.0, 0.0);
            setState(() => _amplitude = level);
            if (!_micConfirmed && level > -45) {
              setState(() => _micConfirmed = true);
            }
          },
          onError: (_) {},
          cancelOnError: false,
        );

        _animTimer = Timer.periodic(const Duration(milliseconds: 120),
            (_) { if (mounted) setState(() {}); });

        // Auto-confirm after 3 s for web / emulator where amplitude may stay
        // silent even with a live microphone.
        _micConfirmTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && !_micConfirmed) setState(() => _micConfirmed = true);
        });

        setState(() {
          _micGranted = true;
          _micChecking = false;
        });
        _micTickAnim.forward(from: 0);
      } else {
        setState(() {
          _micChecking = false;
          _micDenied = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _micChecking = false;
          _micDenied = true;
        });
      }
    }
  }

  Future<void> _retryMic() async {
    // On iOS/macOS the OS never re-shows the dialog after first denial —
    // _micNeedsSettings catches both isPermanentlyDenied and iOS first-denial.
    if (_micNeedsSettings) {
      if (kIsWeb) {
        await _checkMic();
      } else {
        await openAppSettings();
        if (mounted) await _checkMic();
      }
    } else {
      await _checkMic();
    }
  }

  // ─── camera permission + preview ──────────────────────────────────────────

  Future<void> _initCamera() async {
    _cameraController?.dispose();
    _cameraController = null;

    setState(() {
      _camLoading = true;
      _camGranted = false;
      _camDenied = false;
      _camPermanentlyDenied = false;
      _camNoHardware = false;
    });

    try {
      if (_usePermissionHandler) {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _camLoading = false;
              _camDenied = true;
              _camPermanentlyDenied = true;
            });
          }
          return;
        }
        if (!status.isGranted) {
          if (mounted) {
            setState(() { _camLoading = false; _camDenied = true; });
          }
          return;
        }
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _camLoading = false;
            _camNoHardware = true;
            _camGranted = true; // no hardware → auto-pass
          });
          _camTickAnim.forward(from: 0);
        }
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
          front, ResolutionPreset.medium, enableAudio: !kIsWeb && _videoOn);
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }

      _cameraController = ctrl;
      setState(() {
        _camLoading = false;
        _camGranted = true;
      });
      _camTickAnim.forward(from: 0);
    } catch (_) {
      if (mounted) {
        setState(() { _camLoading = false; _camDenied = true; });
      }
    }
  }

  Future<void> _retryCamera() async {
    if (_camNeedsSettings) {
      await openAppSettings();
      if (mounted) await _initCamera();
    } else {
      await _initCamera();
    }
  }

  // ─── video toggle ──────────────────────────────────────────────────────────

  void _toggleVideo() {
    final newVal = !_videoOn;
    setState(() => _videoOn = newVal);
    ref.read(recordingFlowProvider.notifier).update(videoOn: newVal);

    if (!newVal) {
      _cameraController?.dispose();
      _cameraController = null;
      _camTickAnim.reset();
      setState(() {
        _camLoading = false;
        _camGranted = true;
        _camDenied = false;
        _camNoHardware = false;
      });
      _camTickAnim.forward(from: 0);
    } else if (_cameraSupported) {
      _camTickAnim.reset();
      _initCamera();
    }
  }

  // ─── navigate to recording ─────────────────────────────────────────────────

  void _startRecording() {
    _micConfirmTimer?.cancel();
    _amplitudeSub?.cancel();
    _animTimer?.cancel();
    _recorder.dispose(); // stops monitoring recording and releases resources

    final videoArg = _videoOn && _cameraSupported && !_camNoHardware && _camGranted;
    if (!kIsWeb && videoArg && _cameraController != null) {
      ref.read(activeCameraControllerProvider.notifier).state = _cameraController;
    } else {
      _cameraController?.dispose();
    }
    _cameraController = null;

    ref.read(recordingFlowProvider.notifier).update(
      storyId: widget.storyId,
      videoOn: videoArg,
    );
    context.pushReplacement('/recording/${widget.storyId ?? 'null'}?video=$videoArg');
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text('Step 2 of 2',
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.darkSlate)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 100,
                height: 6,
                child: LinearProgressIndicator(
                  value: 0.66,
                  backgroundColor: tokens.brightFern.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(tokens.brightFern),
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Let's check your setup.",
                  style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: tokens.coffeeBean)),
              const SizedBox(height: 8),
              Text("We'll ask for mic and camera access — just tap Allow.",
                  style: GoogleFonts.nunito(
                      fontSize: 15, color: tokens.darkSlate)),
              const SizedBox(height: 32),

              // ── Mic card ──────────────────────────────────────────────────
              _CheckCard(
                tokens: tokens,
                title: 'Microphone',
                subtitle: 'Checking you can be heard clearly.',
                icon: Icons.mic_rounded,
                iconColor: tokens.tigerFlame,
                isGranted: _micGranted,
                tickAnim: _micTickAnim,
                child: _buildMicBody(tokens),
              ),

              const SizedBox(height: 16),

              // ── Camera card ───────────────────────────────────────────────
              if (_cameraSupported)
                _CheckCard(
                  tokens: tokens,
                  title: 'Camera',
                  subtitle: 'So the child can see your face while you read.',
                  icon: Icons.videocam_rounded,
                  iconColor: tokens.brightFern,
                  isGranted: _camGranted,
                  tickAnim: _camTickAnim,
                  trailingWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Video',
                          style: GoogleFonts.nunito(
                              fontSize: 13, color: tokens.darkSlate)),
                      const SizedBox(width: 4),
                      Switch(
                        value: _videoOn,
                        onChanged: (_) => _toggleVideo(),
                        activeThumbColor: tokens.brightFern,
                      ),
                    ],
                  ),
                  child: _buildCameraBody(tokens),
                ),

              const SizedBox(height: 32),

              if (!_canStart)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14,
                          color: tokens.darkSlate.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _micChecking
                              ? 'Requesting microphone access…'
                              : _camLoading
                                  ? 'Requesting camera access…'
                                  : _micGranted && !_micConfirmed
                                      ? 'Say something into the mic to continue.'
                                      : 'Allow access above to continue.',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: tokens.darkSlate
                                  .withValues(alpha: 0.6)),
                        ),
                      ),
                    ],
                  ),
                ),

              PillButton(
                label: 'Start recording →',
                variant:
                    _canStart ? PillVariant.primary : PillVariant.outline,
                fullWidth: true,
                onPressed: _canStart ? _startRecording : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── mic card body ─────────────────────────────────────────────────────────

  Widget _buildMicBody(StorybridgeTokens tokens) {
    if (_micChecking) {
      return _StatusRow(
        icon: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: tokens.darkSlate),
        ),
        label: 'Requesting microphone access…',
        tokens: tokens,
      );
    }

    if (_micDenied) {
      return _PermissionPrompt(
        tokens: tokens,
        icon: Icons.mic_off_rounded,
        iconColor: tokens.recordRed,
        title: _micNeedsSettings
            ? 'Microphone access is blocked'
            : 'Microphone access denied',
        description: _micNeedsSettings
            ? (kIsWeb
                ? 'Click the site settings icon (lock or sliders) in your browser address bar to enable Microphone, then tap Try Again.'
                : 'Go to your device Settings and enable Microphone for this app, then come back.')
            : "Tap below — your device will ask for permission. Choose 'Allow'.",
        buttonLabel: _micNeedsSettings ? (kIsWeb ? 'Try Again' : 'Open Settings') : 'Allow Microphone',
        onTap: _retryMic,
      );
    }

    // Granted — show waveform + speak prompt or confirmed state.
    final normalised = ((_amplitude + 60) / 60).clamp(0.0, 1.0);
    final waveformBars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final h = (10.0 + (i % 3 == 0 ? 40 : 20) * normalised).clamp(10.0, 60.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 5,
          height: h,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: _micConfirmed
                ? tokens.brightFern
                : tokens.brightFern.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );

    if (_micConfirmed) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded, color: tokens.brightFern, size: 18),
          const SizedBox(width: 8),
          Text('Microphone ready',
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.brightFern)),
          const Spacer(),
          waveformBars,
        ],
      );
    }

    // Not yet confirmed — prompt the user to speak.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.record_voice_over_rounded,
                size: 16, color: tokens.tigerFlame),
            const SizedBox(width: 6),
            Text(
              'Say something to test your mic…',
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: tokens.darkSlate),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(child: waveformBars),
      ],
    );
  }

  // ─── camera card body ──────────────────────────────────────────────────────

  Widget _buildCameraBody(StorybridgeTokens tokens) {
    if (!_videoOn) {
      return _StatusRow(
        icon: Icon(Icons.videocam_off_rounded,
            size: 18, color: tokens.darkSlate),
        label: 'Camera off — recording audio only.',
        tokens: tokens,
      );
    }

    if (_camLoading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: tokens.coffeeBean,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    if (_camDenied) {
      return _PermissionPrompt(
        tokens: tokens,
        icon: Icons.videocam_off_rounded,
        iconColor: tokens.recordRed,
        title: _camNeedsSettings
            ? 'Camera access is blocked'
            : 'Camera access denied',
        description: _camNeedsSettings
            ? 'Go to your device Settings and enable Camera for this app, then come back.'
            : "Tap below — your device will ask for permission. Choose 'Allow'.",
        buttonLabel: _camNeedsSettings ? 'Open Settings' : 'Allow Camera',
        onTap: _retryCamera,
      );
    }

    if (_camNoHardware) {
      return _StatusRow(
        icon: Icon(Icons.videocam_off_rounded,
            size: 18, color: tokens.darkSlate),
        label: 'No camera found — will record audio only.',
        tokens: tokens,
      );
    }

    // Live preview + confirmed status row (mirrors setup_video_screen).
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tokens.coffeeBean,
            borderRadius: BorderRadius.circular(16),
          ),
          child: (_cameraController != null &&
                  _cameraController!.value.isInitialized)
              ? CameraPreview(_cameraController!)
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
        ),
        const SizedBox(height: 10),
        _StatusRow(
          icon: Icon(Icons.check_circle_rounded,
              color: tokens.brightFern, size: 18),
          label: 'Camera preview live',
          tokens: tokens,
          labelColor: tokens.brightFern,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PermissionPrompt — shown when mic or camera access is denied
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionPrompt extends StatelessWidget {
  final StorybridgeTokens tokens;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  const _PermissionPrompt({
    required this.tokens,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: iconColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description,
              style: GoogleFonts.nunito(
                  fontSize: 13, height: 1.4, color: tokens.darkSlate)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(buttonLabel,
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CheckCard
// ─────────────────────────────────────────────────────────────────────────────

class _CheckCard extends StatelessWidget {
  final StorybridgeTokens tokens;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isGranted;
  final AnimationController tickAnim;
  final Widget? trailingWidget;
  final Widget child;

  const _CheckCard({
    required this.tokens,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isGranted,
    required this.tickAnim,
    this.trailingWidget,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGranted
            ? tokens.brightFern.withValues(alpha: 0.06)
            : tokens.porcelain,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted ? tokens.brightFern : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tokens.coffeeBean)),
                        Text(subtitle,
                            style: GoogleFonts.nunito(
                                fontSize: 12, color: tokens.darkSlate)),
                      ],
                    ),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: 8),
                    trailingWidget!,
                  ],
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),

          // Animated green tick badge — top-right corner
          Positioned(
            top: -10,
            right: -10,
            child: AnimatedBuilder(
              animation: tickAnim,
              builder: (_, __) {
                final scale = CurvedAnimation(
                  parent: tickAnim,
                  curve: Curves.elasticOut,
                ).value;
                if (scale <= 0) return const SizedBox.shrink();
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tokens.brightFern,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: tokens.porcelain, width: 2.5),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 17),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusRow
// ─────────────────────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final StorybridgeTokens tokens;
  final Color? labelColor;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.tokens,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: labelColor ?? tokens.darkSlate)),
        ),
      ],
    );
  }
}
