import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/stories_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/app_state.dart';

class AuthHomeScreen extends ConsumerStatefulWidget {
  const AuthHomeScreen({super.key});

  @override
  ConsumerState<AuthHomeScreen> createState() => _AuthHomeScreenState();
}

class _AuthHomeScreenState extends ConsumerState<AuthHomeScreen> {
  bool _guestLoading = false;
  bool _socialLoading = false;

  Future<void> _continueAsGuest() async {
    setState(() => _guestLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final uid = cred.user!.uid;
      // Fire-and-forget — don't block guest entry on Firestore availability.
      FirestoreService.createUserProfile(uid, name: 'Guest', email: '')
          .catchError((_) {});
      ref.read(appStateProvider.notifier).update((s) => s.copyWith(
            user: const AppUser(name: 'Guest', email: '', avatar: null),
            isGuest: true,
          ));
      
      // Eagerly pre-load story data in the background
      try {
        ref.read(storiesProvider);
      } catch (_) {}

      if (mounted) context.go('/onboard/role');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not continue as guest: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guestLoading = false);
    }
  }

  Future<void> _handleSocialSignIn(bool isGoogle) async {
    setState(() => _socialLoading = true);
    try {
      final cred = isGoogle
          ? await AuthService.signInWithGoogle()
          : await AuthService.signInWithFacebook();
      final uid = cred.user!.uid;
      final name = cred.user!.displayName ?? (isGoogle ? 'Google Reader' : 'Facebook Reader');
      final email = cred.user!.email ?? (isGoogle ? 'google.user@example.com' : 'facebook.user@example.com');

      await FirestoreService.createUserProfile(uid, name: name, email: email);
      ref.read(appStateProvider.notifier).update((s) => s.copyWith(
            user: AppUser(name: name, email: email, avatar: null),
            isGuest: false,
          ));

      try {
        ref.read(storiesProvider);
      } catch (_) {}

      if (mounted) {
        context.go('/onboard/role');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Social Sign In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64.0, // Account for vertical padding
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/main-logo.jpeg',
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Bring stories to life.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: tokens.coffeeBean,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Record yourself reading for the ones you love, no matter the distance.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          color: tokens.darkSlate,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      PillButton(
                        label: 'Create account',
                        variant: PillVariant.primary,
                        fullWidth: true,
                        onPressed: _socialLoading ? null : () => context.push('/auth/create'),
                      ),
                      const SizedBox(height: 16),
                      PillButton(
                        label: 'Sign in',
                        variant: PillVariant.secondary,
                        fullWidth: true,
                        onPressed: _socialLoading ? null : () => context.push('/auth/signin'),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Divider(color: tokens.darkSlate.withValues(alpha: 0.15))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              'or continue with',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: tokens.darkSlate.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: tokens.darkSlate.withValues(alpha: 0.15))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_socialLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _SocialButton(
                                label: 'Google',
                                icon: Text('G',
                                    style: GoogleFonts.nunito(
                                        color: const Color(0xFF4285F4),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900)),
                                onTap: () => _handleSocialSignIn(true),
                                tokens: tokens,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SocialButton(
                                label: 'Facebook',
                                icon: const Icon(Icons.facebook,
                                    color: Color(0xFF1877F2), size: 24),
                                onTap: () => _handleSocialSignIn(false),
                                tokens: tokens,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      _guestLoading
                          ? const CircularProgressIndicator()
                          : PillButton(
                              label: 'Continue as guest',
                              variant: PillVariant.tertiary,
                              onPressed: _socialLoading ? null : _continueAsGuest,
                            ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final StorybridgeTokens tokens;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.porcelain,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.coffeeBean.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: tokens.coffeeBean,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
