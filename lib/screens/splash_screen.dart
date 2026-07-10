import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../theme/tokens.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Minimum splash display time for branding
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    // Wait for Firebase Auth to emit its first value (usually instant from cache)
    final authAsync = ref.read(firebaseUserProvider);

    // If still loading, give it a short extra window
    if (authAsync is AsyncLoading) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
    }

    final firebaseUser = ref.read(firebaseUserProvider).valueOrNull;
    final appState = ref.read(appStateProvider);

    if (firebaseUser != null) {
      // Authenticated — go to library (router will redirect to onboarding if needed)
      context.go('/library');
    } else if (appState.isGuest && appState.onboarded) {
      // Guest who already went through onboarding
      context.go('/library');
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.brightFern,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/main-logo.jpeg',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'storybridge',
              style: GoogleFonts.nunito(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: tokens.porcelain,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.porcelain.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
