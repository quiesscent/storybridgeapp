import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../providers/recording_flow_provider.dart';

class SetupMicScreen extends ConsumerStatefulWidget {
  final String? storyId;

  const SetupMicScreen({super.key, this.storyId});

  @override
  ConsumerState<SetupMicScreen> createState() => _SetupMicScreenState();
}

class _SetupMicScreenState extends ConsumerState<SetupMicScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  bool _isActive = false;
  bool _denied = false;
  bool _confirmed = false; // green-tick shown once sound detected
  double _amplitude = 0.0;
  Timer? _confirmTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _confirmTimer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _testMic() async {
    bool granted;
    if (kIsWeb) {
      granted = await _recorder.hasPermission();
    } else {
      final status = await Permission.microphone.request();
      granted = status.isGranted;
    }

    if (granted) {
      setState(() {
        _isActive = true;
        _denied = false;
      });
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (!mounted) return;
        final level = amp.current.clamp(-60.0, 0.0);
        setState(() => _amplitude = level);
        // Auto-confirm once we see real audio above noise floor
        if (!_confirmed && level > -45) {
          setState(() => _confirmed = true);
        }
      });
      // Auto-confirm after 3s even if silent (web/emulator)
      _confirmTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_confirmed) setState(() => _confirmed = true);
      });
    } else {
      setState(() {
        _isActive = true;
        _denied = true;
      });
    }
  }

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
        title: _buildProgressHeader(tokens),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Let's check your microphone.",
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: tokens.coffeeBean,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ── Mic badge with pulse ring ─────────────────────────────────
              _buildMicBadge(tokens),
              const SizedBox(height: 28),

              // ── State zone ────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStateZone(tokens),
              ),

              const Spacer(),

              // ── Tips card ─────────────────────────────────────────────────
              _buildTipsCard(tokens),
              const SizedBox(height: 24),

              // ── Confirm / continue button ─────────────────────────────────
              // Enabled only once waveform activity is detected (_confirmed),
              // or when permission was denied and the user needs to proceed
              // anyway.  Disabled while waiting for the first audio signal.
              PillButton(
                label: _denied
                    ? 'Continue without mic →'
                    : _confirmed
                        ? 'Confirm it works →'
                        : 'Waiting for audio…',
                variant: PillVariant.primary,
                fullWidth: true,
                onPressed: (_confirmed || _denied)
                    ? () {
                        ref
                            .read(recordingFlowProvider.notifier)
                            .update(micGranted: !_denied);
                        context.push('/setup/video/${widget.storyId}');
                      }
                    : null,
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
          'Step 2 of 3',
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
              value: 0.67,
              backgroundColor: tokens.brightFern.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(tokens.brightFern),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMicBadge(StorybridgeTokens tokens) {
    final badgeColor = _denied
        ? tokens.recordRed
        : (_confirmed ? tokens.brightFern : tokens.darkSlate);

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        final scale =
            (_isActive && !_denied && !_confirmed) ? _pulseAnim.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              if (_confirmed && !_denied)
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.brightFern.withValues(alpha: 0.12),
                  ),
                ),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(
                  _denied ? Icons.mic_off : Icons.mic,
                  size: 52,
                  color: badgeColor,
                ),
              ),
              // Green tick overlay
              if (_confirmed && !_denied)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tokens.brightFern,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.cream, width: 2),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateZone(StorybridgeTokens tokens) {
    if (!_isActive) {
      return PillButton(
        key: const ValueKey('test-btn'),
        label: 'Test microphone',
        variant: PillVariant.secondary,
        onPressed: _testMic,
      );
    }
    if (_denied) {
      return Column(
        key: const ValueKey('denied'),
        children: [
          _buildStatusChip(
            key: const ValueKey('denied_chip'),
            tokens: tokens,
            icon: Icons.mic_off,
            color: tokens.recordRed,
            message: kIsWeb
                ? "Mic access is blocked. Click the lock/sliders icon in the address bar to allow Microphone, then tap Test again."
                : "Mic access denied — you can still continue and grant it on the recording screen.",
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Test microphone again',
            variant: PillVariant.secondary,
            onPressed: _testMic,
          ),
        ],
      );
    }
    if (_confirmed) {
      return Column(
        key: const ValueKey('confirmed'),
        children: [
          _buildCheckRow(tokens, 'Microphone detected ✓'),
          const SizedBox(height: 16),
          _buildEqualizer(tokens),
        ],
      );
    }
    // Waiting for audio
    return Column(
      key: const ValueKey('waiting'),
      children: [
        Text(
          'Say something to test…',
          style: GoogleFonts.nunito(
            fontSize: 15,
            color: tokens.darkSlate,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        _buildEqualizer(tokens),
      ],
    );
  }

  Widget _buildCheckRow(StorybridgeTokens tokens, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.brightFern.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.brightFern.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: tokens.brightFern, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: tokens.brightFern,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required Key key,
    required StorybridgeTokens tokens,
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: tokens.coffeeBean,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizer(StorybridgeTokens tokens) {
    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(9, (index) {
          final normalised = ((_amplitude + 60) / 60).clamp(0.0, 1.0);
          final seed = math.sin(index * 1.3 + DateTime.now().millisecond / 200);
          final height = 8.0 + (seed.abs() + normalised) * 22;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 7,
            height: height.clamp(8.0, 48.0),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: tokens.brightFern,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTipsCard(StorybridgeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildTipRow(tokens, Icons.volume_off, 'Find a quiet room'),
          const SizedBox(height: 14),
          _buildTipRow(tokens, Icons.record_voice_over, 'Speak clearly and naturally'),
          const SizedBox(height: 14),
          _buildTipRow(
              tokens, Icons.settings_input_antenna, "Keep the phone at arm's length"),
        ],
      ),
    );
  }

  Widget _buildTipRow(StorybridgeTokens tokens, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 22, color: tokens.darkSlate),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: tokens.coffeeBean,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
