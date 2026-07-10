// lib/screens/profile/plans_screen.dart
//
// Displays available subscription plans read live from the `plans` Firestore
// collection. Never hardcoded. Tapping a plan triggers the Apple Pay
// simulation via the shared PaywallScreen flow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../providers/plans_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription_plan.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/profile_top_bar.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final asyncPlans = ref.watch(plansProvider);
    final subStatus = ref.watch(subscriptionStatusProvider);
    final sub = ref.watch(subscriptionStreamProvider).valueOrNull;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Plans',
        onBackTap: () => Navigator.pop(context),
        tokens: tokens,
      ),
      body: asyncPlans.when(
        loading: () => _buildShimmer(tokens),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load plans. Please check your connection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 15, color: tokens.darkSlate),
            ),
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Text('No plans available.',
                  style: GoogleFonts.nunito(
                      fontSize: 15, color: tokens.darkSlate)),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current subscription status banner
                if (subStatus == SubscriptionGatingStatus.subscribed &&
                    sub != null) ...[
                  _ActiveBanner(sub: sub, tokens: tokens),
                  const SizedBox(height: 24),
                ],
                if (subStatus == SubscriptionGatingStatus.expired) ...[
                  _ExpiredBanner(tokens: tokens),
                  const SizedBox(height: 24),
                ],

                Text(
                  'Choose a plan',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: tokens.coffeeBean,
                  ),
                ),
                const SizedBox(height: 16),

                ...plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PlanCard(
                      plan: plan,
                      isCurrent: sub?.planId == plan.id &&
                          subStatus ==
                              SubscriptionGatingStatus.subscribed,
                      tokens: tokens,
                      onSubscribe: () =>
                          context.push('/paywall?planId=${plan.id}'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer(StorybridgeTokens tokens) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: tokens.porcelain,
        highlightColor: tokens.cream,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

// ── Active subscription banner ────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  final dynamic sub; // UserSubscription
  final StorybridgeTokens tokens;
  const _ActiveBanner({required this.sub, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final endDate = (sub.endDate as dynamic).toDate() as DateTime;
    final remaining = endDate.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.brightFern.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: tokens.brightFern.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded,
              color: tokens.brightFern, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active — ${sub.planName}',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.coffeeBean,
                  ),
                ),
                Text(
                  'Renews in $remaining day${remaining == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: tokens.darkSlate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expired subscription banner ───────────────────────────────────────────────

class _ExpiredBanner extends StatelessWidget {
  final StorybridgeTokens tokens;
  const _ExpiredBanner({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.tigerFlame.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: tokens.tigerFlame.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: tokens.tigerFlame, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your subscription has expired. Choose a plan below to re-activate.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: tokens.coffeeBean,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final StorybridgeTokens tokens;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.tokens,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? tokens.brightFern
              : tokens.brightFern.withValues(alpha: 0.12),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — name + price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: tokens.coffeeBean,
                ),
              ),
              Text(
                plan.price,
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: tokens.brightFern,
                ),
              ),
            ],
          ),

          // Features
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: tokens.brightFern),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: tokens.darkSlate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          PillButton(
            label: isCurrent ? 'Current Plan' : 'Choose Plan',
            variant:
                isCurrent ? PillVariant.outline : PillVariant.primary,
            fullWidth: true,
            onPressed: isCurrent ? null : onSubscribe,
          ),
        ],
      ),
    );
  }
}
