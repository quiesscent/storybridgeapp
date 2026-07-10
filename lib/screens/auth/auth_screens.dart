import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/stories_provider.dart';
import '../../models/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';


// ─── Shared helper widgets ────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? hint;

  const _AuthField({
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.coffeeBean)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: tokens.porcelain,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: GoogleFonts.nunito(fontSize: 16),
        ),
      ],
    );
  }
}

Widget _errorBanner(StorybridgeTokens tokens, String message) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: GoogleFonts.nunito(
                    fontSize: 13, color: Colors.red.shade700))),
      ],
    ),
  );
}

// ─── Create Account ───────────────────────────────────────────────────────────

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await AuthService.signUp(
          email: email, password: password, displayName: name);

      final uid = cred.user!.uid;

      // Create Firestore profile
      await FirestoreService.createUserProfile(uid, name: name, email: email);

      // Update local Riverpod state so UI reflects the user immediately
      ref.read(appStateProvider.notifier).setUser(
            AppUser(name: name, email: email),
          );

      // Eagerly pre-load story data in the background
      try {
        ref.read(storiesProvider);
      } catch (_) {}

      if (!mounted) return;
      context.go('/onboard/role');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFrom(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSocialSignIn(bool isGoogle) async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
        setState(() {
          _error = 'Social Sign In failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar:
          AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/main-logo.jpeg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Create account',
                    style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: tokens.coffeeBean)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Start sharing stories with the ones you love.',
                style:
                    GoogleFonts.nunito(fontSize: 16, color: tokens.darkSlate)),
            const SizedBox(height: 32),
            _AuthField(
                label: 'Full Name',
                controller: _nameController,
                hint: 'Your name'),
            const SizedBox(height: 16),
            _AuthField(
                label: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                hint: 'you@example.com'),
            const SizedBox(height: 16),
            _AuthField(
                label: 'Password',
                controller: _passwordController,
                isPassword: true,
                hint: 'At least 6 characters'),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _errorBanner(tokens, _error!),
            ],
            const SizedBox(height: 32),
            PillButton(
              label: _loading ? 'Creating account…' : 'Create account →',
              variant: PillVariant.primary,
              fullWidth: true,
              onPressed: _loading ? null : _submit,
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
                    onTap: _loading ? () {} : () => _handleSocialSignIn(true),
                    tokens: tokens,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SocialButton(
                    label: 'Facebook',
                    icon: const Icon(Icons.facebook,
                        color: Color(0xFF1877F2), size: 24),
                    onTap: _loading ? () {} : () => _handleSocialSignIn(false),
                    tokens: tokens,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => context.go('/auth/signin'),
                child: Text('Already have an account? Sign in',
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: tokens.brightFern,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sign In ──────────────────────────────────────────────────────────────────

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred =
          await AuthService.signIn(email: email, password: password);
      final user = cred.user!;

      // `onAuthStateChanged` in AppStateNotifier will load Firestore data,
      // but set a quick local snapshot so the router redirects immediately.
      ref.read(appStateProvider.notifier).setUser(
            AppUser(
              name: user.displayName ?? 'Narrator',
              email: user.email ?? email,
            ),
          );

      // Eagerly pre-load story data in the background
      try {
        ref.read(storiesProvider);
      } catch (_) {}

      if (!mounted) return;
      // The router's redirect will send us to /library once onboarded is true.
      // If the user never finished onboarding, they'll land on /onboard/role.
      context.go('/library');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFrom(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSocialSignIn(bool isGoogle) async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
        context.go('/library');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Social Sign In failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar:
          AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/main-logo.jpeg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Sign in',
                    style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: tokens.coffeeBean)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Welcome back.',
                style:
                    GoogleFonts.nunito(fontSize: 16, color: tokens.darkSlate)),
            const SizedBox(height: 32),
            _AuthField(
                label: 'Email Address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                hint: 'you@example.com'),
            const SizedBox(height: 16),
            _AuthField(
                label: 'Password',
                controller: _passwordController,
                isPassword: true),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/auth/forgot'),
                child: Text('Forgot password?',
                    style: GoogleFonts.nunito(
                        color: tokens.darkSlate,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _errorBanner(tokens, _error!),
            ],
            const SizedBox(height: 24),
            PillButton(
              label: _loading ? 'Signing in…' : 'Sign in',
              variant: PillVariant.primary,
              fullWidth: true,
              onPressed: _loading ? null : _submit,
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
                    onTap: _loading ? () {} : () => _handleSocialSignIn(true),
                    tokens: tokens,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SocialButton(
                    label: 'Facebook',
                    icon: const Icon(Icons.facebook,
                        color: Color(0xFF1877F2), size: 24),
                    onTap: _loading ? () {} : () => _handleSocialSignIn(false),
                    tokens: tokens,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => context.go('/auth/create'),
                child: Text("Don't have an account? Create one",
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: tokens.brightFern,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Forgot Password ──────────────────────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFrom(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar:
          AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/main-logo.jpeg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Reset password',
                    style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: tokens.coffeeBean)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Enter your email and we'll send you a link to reset your password.",
              style:
                  GoogleFonts.nunito(fontSize: 16, color: tokens.darkSlate),
            ),
            const SizedBox(height: 32),
            if (_sent)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: tokens.brightFern.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: tokens.brightFern, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reset link sent! Check your inbox.',
                        style: GoogleFonts.nunito(
                            fontSize: 15, color: tokens.brightFern),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _AuthField(
                  label: 'Email Address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'you@example.com'),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _errorBanner(tokens, _error!),
              ],
              const SizedBox(height: 32),
              PillButton(
                label: _loading ? 'Sending…' : 'Send reset link',
                variant: PillVariant.primary,
                fullWidth: true,
                onPressed: _loading ? null : _submit,
              ),
            ],
          ],
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
