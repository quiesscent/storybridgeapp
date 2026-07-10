import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/profile_top_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Settings',
        onBackTap: () => Navigator.pop(context),
        tokens: tokens,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildSettingSection(tokens, 'App Preferences', [
              _SettingItem(tokens, Icons.language, 'Language', 'English (UK)', () {}),
              _SettingItem(tokens, Icons.dark_mode_outlined, 'Appearance', 'System Default', () {}),
              _SettingItem(tokens, Icons.storage_outlined, 'Storage & Data', 'Manage downloaded stories', () {}),
            ]),
            const SizedBox(height: 24),
            _buildSettingSection(tokens, 'Privacy & Security', [
              _SettingItem(tokens, Icons.lock_outline, 'Change Password', '', () {}),
              _SettingItem(tokens, Icons.security, 'Two-Factor Auth', 'Off', () {}),
              _SettingItem(tokens, Icons.delete_forever_outlined, 'Delete Account', '', () {}, isDestructive: true),
            ]),
            const SizedBox(height: 32),
            Text(
              'Storybridge v1.0.4',
              style: GoogleFonts.nunito(fontSize: 12, color: tokens.darkSlate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection(StorybridgeTokens tokens, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.darkSlate)),
        ),
        Container(
          decoration: BoxDecoration(
            color: tokens.porcelain,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final StorybridgeTokens tokens;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingItem(this.tokens, this.icon, this.label, this.value, this.onTap, {this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? tokens.recordRed : tokens.darkSlate),
      title: Text(label, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: isDestructive ? tokens.recordRed : tokens.coffeeBean)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) Text(value, style: GoogleFonts.nunito(fontSize: 14, color: tokens.darkSlate)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: tokens.darkSlate.withValues(alpha: 0.3)),
        ],
      ),
      onTap: onTap,
    );
  }
}
