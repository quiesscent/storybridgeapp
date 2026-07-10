// lib/screens/profile/profile_screen.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../models/app_state.dart';
import '../../providers/app_state_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/profile_top_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  ImageProvider? _getAvatarProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:') ||
        kIsWeb) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  Future<void> _handlePasswordReset(BuildContext context, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Text('Send a password reset email to $email?', style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Send', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Email Sent', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            content: Text('A password reset link has been sent to $email.', style: GoogleFonts.nunito()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reset link: $e')),
        );
      }
    }
  }

  Future<void> _handleChangePassword(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    if (!context.mounted) return;

    final success = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Change Password',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Current Password
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          labelStyle: GoogleFonts.nunito(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your current password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // New Password
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: GoogleFonts.nunito(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a new password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          labelStyle: GoogleFonts.nunito(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text('Update', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (success != true) return;

    // Show loading indicator
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user first for security
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(cred);
        
        // Update password
        await user.updatePassword(newPasswordController.text);

        if (context.mounted) {
          Navigator.pop(context); // Pop loading dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Success', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              content: Text('Your password has been successfully updated.', style: GoogleFonts.nunito()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading dialog
        String msg = e.toString();
        if (e is FirebaseAuthException) {
          if (e.code == 'wrong-password') {
            msg = 'Incorrect current password.';
          } else {
            msg = e.message ?? msg;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update password: $msg')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final appState = ref.watch(appStateProvider);
    final user = appState.user;
    final plan = (kIsWeb && Uri.base.host.toLowerCase() == 'beta.storybridgeapp.co.uk')
        ? Plan.premium
        : appState.plan;
    final isGuest = appState.isGuest;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Profile',
        hasBackButton: false,
        tokens: tokens,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeroCard(tokens, user, plan),
            const SizedBox(height: 24),
            if (isGuest) ...[
              _buildGuestPromptCard(ref, context, tokens),
              const SizedBox(height: 24),
            ],
            _buildMenuList(context, tokens, ref, isGuest, user?.email),
            // Comfortable margin so the floating bottom nav bar never covers the last list item
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(StorybridgeTokens tokens, AppUser? user, Plan plan) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.brightFern.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: tokens.brightFern,
            backgroundImage: _getAvatarProvider(user?.avatar),
            child: (user?.avatar == null) 
              ? Text(
                  (user?.name != null && user!.name.isNotEmpty) 
                      ? user.name[0].toUpperCase() 
                      : 'G',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 32, color: tokens.porcelain),
                )
              : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user?.name != null && user!.name.isNotEmpty) ? user.name : 'Guest User', 
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 22, color: tokens.coffeeBean),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: tokens.tigerFlame.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(plan == Plan.premium ? 'PREMIUM' : 'FREE', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.tigerFlame)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestPromptCard(WidgetRef ref, BuildContext context, StorybridgeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.tigerFlame.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tokens.tigerFlame.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: tokens.tigerFlame, size: 28),
              const SizedBox(width: 10),
              Text(
                'Unlock StoryBridge',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: tokens.coffeeBean,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You are currently logged in as a guest. Create an account to backup your stories, customize your profile, and read across all your devices!',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: tokens.darkSlate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.tigerFlame,
                foregroundColor: tokens.porcelain,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                // Completely reset guest session to allow routing to account creation without guard bounce
                await ref.read(appStateProvider.notifier).clearGuestSession();
                if (context.mounted) {
                  context.go('/auth/create');
                }
              },
              child: Text(
                'Create Account',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, StorybridgeTokens tokens, WidgetRef ref, bool isGuest, String? email) {
    return Container(
      decoration: BoxDecoration(color: tokens.porcelain, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          // Integrated Profile Navigation options:
          _MenuItem(
            tokens,
            Icons.edit_outlined,
            'Edit Profile',
            () => context.push('/profile/edit'),
          ),
          const Divider(height: 1),
          _MenuItem(
            tokens,
            Icons.format_size,
            'Text Size',
            () => context.push('/profile/text-size'),
          ),
          const Divider(height: 1),
          _MenuItem(
            tokens,
            Icons.card_membership_outlined,
            'Subscription Plan',
            () => context.push('/profile/subscription'),
          ),
          const Divider(height: 1),
          _MenuItem(
            tokens,
            Icons.notifications_none,
            'Notifications',
            () => context.push('/profile/notifications'),
          ),
          const Divider(height: 1),
          _MenuItem(
            tokens,
            Icons.help_outline,
            'Help & Support',
            () => context.push('/profile/help'),
          ),
          const Divider(height: 1),
          _MenuItem(
            tokens,
            Icons.settings_outlined,
            'Settings',
            () => context.push('/profile/settings'),
          ),
          const Divider(height: 1),
          _MenuItem(
            tokens,
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            () => context.push('/profile/privacy'),
          ),
          const Divider(height: 1),
          _MenuItem(
            tokens,
            Icons.description_outlined,
            'Terms of Service',
            () => context.push('/profile/terms'),
          ),
          const Divider(height: 1),
          // Password actions for authenticated accounts
          if (!isGuest && email != null && email.isNotEmpty) ...[
            _MenuItem(
              tokens,
              Icons.lock_outline,
              'Change Password',
              () => _handleChangePassword(context),
            ),
            const Divider(height: 1),
            _MenuItem(
              tokens,
              Icons.lock_reset,
              'Reset Password via Email',
              () => _handlePasswordReset(context, email),
            ),
            const Divider(height: 1),
          ],
          _MenuItem(
            tokens,
            Icons.logout,
            'Sign out',
            () async {
              await AuthService.signOut();
              if (context.mounted) context.go('/auth');
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final StorybridgeTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _MenuItem(this.tokens, this.icon, this.label, this.onTap, {this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? tokens.recordRed : tokens.darkSlate),
      title: Text(label, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: isDestructive ? tokens.recordRed : tokens.coffeeBean)),
      trailing: isDestructive ? null : Icon(Icons.chevron_right, size: 20, color: tokens.darkSlate.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}
