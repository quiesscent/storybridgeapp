import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../models/app_state.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/profile_top_bar.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final appState = ref.watch(appStateProvider);
    final plan = (kIsWeb && Uri.base.host.toLowerCase() == 'beta.storybridgeapp.co.uk')
        ? Plan.premium
        : appState.plan;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Subscription',
        onBackTap: () => Navigator.pop(context),
        tokens: tokens,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [tokens.brightFern, tokens.brightFern.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Plan', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.porcelain.withValues(alpha: 0.8), letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(plan.name.toUpperCase(), style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 32, color: tokens.porcelain)),
                  const SizedBox(height: 24),
                  PillButton(
                    label: 'Manage subscription',
                    variant: PillVariant.primary,
                    backgroundColor: tokens.porcelain,
                    foregroundColor: tokens.brightFern,
                    onPressed: () => context.push('/profile/plans'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Text('Why upgrade to Premium?', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 22, color: tokens.coffeeBean)),
            const SizedBox(height: 24),
            _buildBenefit(tokens, Icons.cloud_upload_outlined, 'Unlimited cloud storage', 'Keep all your stories safe forever.'),
            const SizedBox(height: 16),
            _buildBenefit(tokens, Icons.videocam_outlined, 'HD Video Recording', 'Crystal clear video for your loved ones.'),
            const SizedBox(height: 16),
            _buildBenefit(tokens, Icons.family_restroom, 'Family Sharing', 'Invite up to 5 family members.'),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(StorybridgeTokens tokens, IconData icon, String title, String desc) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: tokens.brightFern.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: tokens.brightFern),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.coffeeBean)),
              Text(desc, style: GoogleFonts.nunito(fontSize: 14, color: tokens.darkSlate)),
            ],
          ),
        ),
      ],
    );
  }
}
