import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../providers/recording_flow_provider.dart';
import '../../models/recording_flow.dart';

class SetupVideoScreen extends ConsumerStatefulWidget {
  final String? storyId;

  const SetupVideoScreen({super.key, this.storyId});

  @override
  ConsumerState<SetupVideoScreen> createState() => _SetupVideoScreenState();
}

class _SetupVideoScreenState extends ConsumerState<SetupVideoScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _denied = false;

  late AnimationController _tickCtrl;
  late Animation<double> _tickAnim;

  @override
  void initState() {
    super.initState();
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tickAnim = CurvedAnimation(parent: _tickCtrl, curve: Curves.elasticOut);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _controller = CameraController(front, ResolutionPreset.medium, enableAudio: !kIsWeb);
        await _controller!.initialize();
        if (mounted) {
          setState(() => _isInitialized = true);
          // Trigger tick animation after preview settles
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) _tickCtrl.forward();
        }
      } catch (_) {
        if (mounted) setState(() => _denied = true);
      }
    } else {
      if (mounted) setState(() => _denied = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final flow = ref.watch(recordingFlowProvider);

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
          onPressed: () {
            context.go('/library');
          },
        ),
        title: _buildProgressHeader(tokens),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set up your camera.',
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: tokens.coffeeBean,
                ),
              ),
              const SizedBox(height: 20),

              // ── Camera preview box with status overlay ──────────────────
              _buildCameraPreview(tokens, flow.videoOn),
              const SizedBox(height: 16),

              // ── Check row — appears once camera is ready ────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCameraStatus(tokens),
              ),
              const SizedBox(height: 16),

              // ── Video toggle card ───────────────────────────────────────
              _buildToggleCard(tokens, flow),
              const SizedBox(height: 16),

              // ── Tips card ───────────────────────────────────────────────
              _buildTipsCard(tokens),

              const Spacer(),

              // ── Start recording button ──────────────────────────────────
              PillButton(
                label: 'Start recording →',
                variant: PillVariant.primary,
                fullWidth: true,
                onPressed: () async {
                  if (!kIsWeb && flow.videoOn && _controller != null) {
                    ref.read(activeCameraControllerProvider.notifier).state = _controller;
                  } else {
                    await _controller?.dispose();
                  }
                  _controller = null;
                  if (!context.mounted) return;
                  final storyId =
                      widget.storyId == 'null' ? null : widget.storyId;
                  context.pushReplacement(
                      '/recording/$storyId?video=${flow.videoOn}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildProgressHeader(StorybridgeTokens tokens) {
    return Column(
      children: [
        Text(
          'Step 3 of 3',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tokens.darkSlate,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 100,
            height: 6,
            child: LinearProgressIndicator(
              value: 1.0,
              backgroundColor: tokens.brightFern.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(tokens.brightFern),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview(StorybridgeTokens tokens, bool videoOn) {
    return Container(
      width: double.infinity,
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.coffeeBean,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Preview
          if (_isInitialized && videoOn)
            CameraPreview(_controller!)
          else if (_isInitialized && !videoOn)
            Opacity(opacity: 0.2, child: CameraPreview(_controller!))
          else if (_denied)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Text(
                  'Camera access denied — continue with audio only.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(color: tokens.porcelain, fontSize: 14),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white54)),

          // Audio-only icon overlay
          if (!videoOn)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 52, color: tokens.brightFern),
                  const SizedBox(height: 8),
                  Text(
                    'Audio only',
                    style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Green tick badge once camera is live
          if (_isInitialized && !_denied)
            Positioned(
              top: 12,
              right: 12,
              child: ScaleTransition(
                scale: _tickAnim,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.brightFern,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Camera ready',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraStatus(StorybridgeTokens tokens) {
    if (_isInitialized) {
      return _buildCheckRow(
        key: const ValueKey('cam-ok'),
        tokens: tokens,
        icon: Icons.videocam_rounded,
        label: 'Camera detected ✓',
        color: tokens.brightFern,
      );
    }
    if (_denied) {
      return _buildCheckRow(
        key: const ValueKey('cam-denied'),
        tokens: tokens,
        icon: Icons.videocam_off_rounded,
        label: 'No camera access — audio only mode will be used.',
        color: tokens.recordRed,
      );
    }
    return const SizedBox(key: ValueKey('cam-init'), height: 0);
  }

  Widget _buildCheckRow({
    required Key key,
    required StorybridgeTokens tokens,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard(StorybridgeTokens tokens, RecordingFlowState flow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flow.videoOn ? 'Record with video' : 'Audio only',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.coffeeBean,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  flow.videoOn
                      ? 'Your face appears as a small bubble.'
                      : 'Just your voice — no video.',
                  style: GoogleFonts.nunito(fontSize: 13, color: tokens.darkSlate),
                ),
              ],
            ),
          ),
          Switch(
            value: flow.videoOn,
            onChanged: (val) =>
                ref.read(recordingFlowProvider.notifier).update(videoOn: val),
            activeThumbColor: tokens.brightFern,
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(StorybridgeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.brightFern.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.brightFern.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: tokens.brightFern, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Look your best: make sure your face is well-lit and at eye level.',
              style: GoogleFonts.nunito(fontSize: 13, color: tokens.coffeeBean),
            ),
          ),
        ],
      ),
    );
  }
}
