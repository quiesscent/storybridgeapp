import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/tokens.dart';
import '../../providers/app_state_provider.dart';
import '../../models/app_state.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/profile_top_bar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  String? _selectedImagePath;
  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appStateProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedImagePath = user?.avatar;
    
    // Add listener to update avatar letter in real-time
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

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

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    final newPassword = _newPasswordController.text;
    if (newPassword.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your current password to update it.')),
        );
        return;
      }
      if (newPassword.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New password must be at least 6 characters.')),
        );
        return;
      }
      if (newPassword != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match.')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String? avatarUrl = _selectedImagePath;

      if (uid != null && _selectedImagePath != null) {
        // Only upload to Firebase Storage if it's a new local file or blob URL
        if (!_selectedImagePath!.startsWith('http://') &&
            !_selectedImagePath!.startsWith('https://')) {
          avatarUrl = await StorageService.uploadAvatar(
            userId: uid,
            localPath: _selectedImagePath!,
          );
        }
      }

      final appState = ref.read(appStateProvider);
      final user = appState.user;

      if (user != null) {
        ref.read(appStateProvider.notifier).setUser(user.copyWith(
          name: newName,
          avatar: avatarUrl,
        ));
      } else {
        ref.read(appStateProvider.notifier).setUser(AppUser(
          name: newName,
          email: 'guest@storybridge.app',
          avatar: avatarUrl,
        ));
      }

      if (uid != null) {
        // Save to Firestore user profile document
        await FirestoreService.updateUserProfile(uid, {
          'name': newName,
          'avatar': avatarUrl,
        });

        // Save display name & photo URL to Firebase Auth user profile
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await firebaseUser.updateDisplayName(newName);
          if (avatarUrl != null) {
            await firebaseUser.updatePhotoURL(avatarUrl);
          }

          // Handle password change if specified
          if (newPassword.isNotEmpty) {
            final cred = EmailAuthProvider.credential(
              email: firebaseUser.email!,
              password: _currentPasswordController.text,
            );
            await firebaseUser.reauthenticateWithCredential(cred);
            await firebaseUser.updatePassword(newPassword);
          }
        }
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is FirebaseAuthException && e.code == 'wrong-password') {
          msg = 'Incorrect current password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile changes: $msg')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final isGuest = ref.watch(appStateProvider).isGuest;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Edit Profile',
        onBackTap: () => context.pop(),
        tokens: tokens,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _isSaving ? null : _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: tokens.brightFern,
                    backgroundImage: _getAvatarProvider(_selectedImagePath),
                    child: _selectedImagePath == null 
                      ? Text(
                          _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'G',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 48, color: tokens.porcelain),
                        )
                      : null,
                  ),
                  if (!_isSaving)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.tigerFlame,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.porcelain, width: 2),
                        ),
                        child: Icon(Icons.camera_alt, color: tokens.porcelain, size: 20),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _buildTextField(tokens, 'Full Name', _nameController, Icons.person_outline, enabled: !_isSaving),
            const SizedBox(height: 20),
            _buildTextField(tokens, 'Email Address', _emailController, Icons.mail_outline, enabled: false),
            
            // Password change section for registered users
            if (!isGuest) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Change Password',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tokens.coffeeBean,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                tokens,
                'Current Password',
                _currentPasswordController,
                _obscureCurrent,
                (val) => setState(() => _obscureCurrent = val),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                tokens,
                'New Password',
                _newPasswordController,
                _obscureNew,
                (val) => setState(() => _obscureNew = val),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                tokens,
                'Confirm New Password',
                _confirmPasswordController,
                _obscureConfirm,
                (val) => setState(() => _obscureConfirm = val),
                enabled: !_isSaving,
              ),
            ],
            
            const SizedBox(height: 48),
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : PillButton(
                    label: 'Save Changes',
                    variant: PillVariant.primary,
                    fullWidth: true,
                    onPressed: _saveChanges,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(StorybridgeTokens tokens, String label, TextEditingController controller, IconData icon, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.darkSlate)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: GoogleFonts.nunito(fontSize: 16, color: tokens.coffeeBean),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: tokens.darkSlate),
            filled: true,
            fillColor: tokens.porcelain,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    StorybridgeTokens tokens,
    String label,
    TextEditingController controller,
    bool obscure,
    void Function(bool) onToggleObscure, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.darkSlate)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          style: GoogleFonts.nunito(fontSize: 16, color: tokens.coffeeBean),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline, color: tokens.darkSlate),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: tokens.darkSlate),
              onPressed: () => onToggleObscure(!obscure),
            ),
            filled: true,
            fillColor: tokens.porcelain,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }
}
