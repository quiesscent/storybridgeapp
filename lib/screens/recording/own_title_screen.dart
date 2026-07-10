import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../providers/recording_flow_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/app_state_provider.dart';

class OwnTitleScreen extends ConsumerStatefulWidget {
  const OwnTitleScreen({super.key});

  @override
  ConsumerState<OwnTitleScreen> createState() => _OwnTitleScreenState();
}

class _OwnTitleScreenState extends ConsumerState<OwnTitleScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final isSubscribed = ref.watch(isSubscribedProvider);
    final recordings = ref.watch(appStateProvider).recordings;

    if (!isSubscribed && recordings.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/paywall');
      });
      return Scaffold(
        backgroundColor: tokens.cream,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record your own story',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: tokens.coffeeBean,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Give it a title so you can find it later.',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  color: tokens.darkSlate,
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter title...',
                  filled: true,
                  fillColor: tokens.porcelain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w600),
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              PillButton(
                label: 'Continue →',
                variant: PillVariant.primary,
                fullWidth: true,
                onPressed: _controller.text.trim().isNotEmpty
                    ? () {
                        ref.read(recordingFlowProvider.notifier).update(ownTitle: _controller.text.trim());
                        context.push('/setup/mic/null');
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
