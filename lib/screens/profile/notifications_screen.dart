import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/profile_top_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _newStories = true;
  bool _reminders = true;
  bool _marketing = false;
  bool _sharedContent = true;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Notifications',
        onBackTap: () => Navigator.pop(context),
        tokens: tokens,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stay updated with your loved ones and new features.',
              style: GoogleFonts.nunito(fontSize: 16, color: tokens.darkSlate),
            ),
            const SizedBox(height: 32),
            _buildToggle(tokens, 'New Stories', 'Get notified when new stories are added to the library.', _newStories, (v) => setState(() => _newStories = v)),
            _buildToggle(tokens, 'Recording Reminders', 'Daily or weekly nudges to keep your stories flowing.', _reminders, (v) => setState(() => _reminders = v)),
            _buildToggle(tokens, 'Shared with me', 'Know exactly when someone shares a story with you.', _sharedContent, (v) => setState(() => _sharedContent = v)),
            _buildToggle(tokens, 'News & Updates', 'Occasional updates about new features and improvements.', _marketing, (v) => setState(() => _marketing = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(StorybridgeTokens tokens, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
                Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.coffeeBean)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.nunito(fontSize: 13, color: tokens.darkSlate)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: tokens.brightFern,
          ),
        ],
      ),
    );
  }
}
