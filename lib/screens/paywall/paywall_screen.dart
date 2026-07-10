// lib/screens/paywall/paywall_screen.dart
//
// Premium paywall — entered when a non-subscribed user taps a premium story.
// Plans are loaded from the `plans` Firestore collection for display.
// Tapping the CTA triggers a real Apple In-App Purchase (product 29MV66KM8Q)
// via StoreKit. On successful purchase the subscription doc is written to
// users/{uid}/subscriptions/current and the user is returned to the
// originating story (or the library home if no storyId was provided).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shimmer/shimmer.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../models/subscription_plan.dart';
import '../../providers/plans_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/iap_service.dart';
import '../../theme/tokens.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  /// The story that triggered this paywall. Null when entered from the
  /// profile → plans path. After a successful purchase the user is returned
  /// to this story if set, otherwise to the library home.
  final String? storyId;
  final String? planId;

  const PaywallScreen({super.key, this.storyId, this.planId});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  SubscriptionPlan? _selected;
  bool _purchasing = false;

  StreamSubscription<List<PurchaseDetails>>? _iapSub;

  @override
  void initState() {
    super.initState();
    _iapSub = IAPService.purchaseStream.listen(_onPurchaseUpdate);
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    super.dispose();
  }

  // ── Purchase stream handler ─────────────────────────────────────────────────

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
          await IAPService.completePurchase(purchase);
          if (mounted) await _recordAndNavigate(purchase);
        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _purchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    purchase.error?.message ?? 'Purchase failed. Please try again.'),
              ),
            );
          }
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _purchasing = false);
        case PurchaseStatus.pending:
          // Deferred purchase (e.g. parental approval) — stop spinner, inform user.
          if (mounted) {
            setState(() => _purchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase is pending approval.'),
              ),
            );
          }
        case PurchaseStatus.restored:
          await IAPService.completePurchase(purchase);
          if (mounted) await _recordAndNavigate(purchase);
      }
    }
  }

  // ── Initiate real IAP purchase ──────────────────────────────────────────────

  Future<void> _startPurchase(SubscriptionPlan plan) async {
    setState(() => _purchasing = true);
    try {
      final available = await IAPService.isAvailable();
      if (!available) {
        _showError('The App Store is not reachable. Please try again later.');
        return;
      }

      final product = await IAPService.getProductDetails();
      if (product == null) {
        _showError('Subscription product not found. Please try again later.');
        return;
      }

      // Native StoreKit sheet appears; result arrives via _onPurchaseUpdate.
      await IAPService.purchase(product);
    } catch (e) {
      _showError('Could not start purchase: $e');
    }
    // Do NOT set _purchasing = false here; the stream handler does it on
    // error/cancel, and _recordAndNavigate navigates away on success.
  }

  // ── Verify with Apple server + navigate ─────────────────────────────────────

  Future<void> _recordAndNavigate(PurchaseDetails purchase) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || purchase.purchaseID == null) return;

    try {
      // Cloud Function validates with Apple and writes to Firestore.
      await IAPService.verifyWithServer(
        transactionId: purchase.purchaseID!,
        uid: uid,
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();

      if (widget.storyId != null) {
        context.go('/library/book/${widget.storyId}');
      } else {
        context.go('/library');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _purchasing = false);
        _showError('Could not activate subscription: $e');
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _purchasing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final asyncPlans = ref.watch(plansProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0D0D0D),
                  tokens.pineBlue.withValues(alpha: 0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      if (widget.storyId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Premium Story',
                                style: GoogleFonts.nunito(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Hero copy ─────────────────────────────────────────────
                const SizedBox(height: 24),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.auto_stories_rounded,
                      color: Colors.amber, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'Unlock Premium Stories',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.storyId != null
                        ? 'Subscribe to read this story and unlock the full premium library for your family.'
                        : 'Get unlimited access to all premium stories, HD recordings, and family sharing.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      color: Colors.white60,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Plans list ────────────────────────────────────────────
                Expanded(
                  child: asyncPlans.when(
                    loading: () => _buildShimmerPlans(),
                    error: (e, _) => Center(
                      child: Text(
                        'Could not load plans.\nPlease try again.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(color: Colors.white54),
                      ),
                    ),
                    data: (plans) {
                      if (plans.isEmpty) {
                        return Center(
                          child: Text(
                            'No plans available right now.',
                            style: GoogleFonts.nunito(color: Colors.white54),
                          ),
                        );
                      }
                      if (_selected == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            if (widget.planId != null) {
                              final pre = plans.firstWhere(
                                (p) => p.id == widget.planId,
                                orElse: () => plans.first,
                              );
                              setState(() => _selected = pre);
                            } else {
                              setState(() => _selected = plans.first);
                            }
                          }
                        });
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        itemCount: plans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _PlanCard(
                          plan: plans[i],
                          isSelected: _selected?.id == plans[i].id,
                          tokens: tokens,
                          onTap: () => setState(() => _selected = plans[i]),
                        ),
                      );
                    },
                  ),
                ),

                // ── CTA button ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: _selected == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: _purchasing
                              ? null
                              : () => _startPurchase(_selected!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 56,
                            decoration: BoxDecoration(
                              color: _purchasing
                                  ? Colors.white24
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_purchasing)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                else ...[
                                  const Icon(Icons.apple,
                                      color: Colors.black, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Subscribe with Apple',
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),

                // ── Legal footnote ────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  child: Text(
                    'Subscriptions renew automatically. Cancel anytime in Settings.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: Colors.white30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerPlans() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.white10,
        highlightColor: Colors.white24,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// ── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final StorybridgeTokens tokens;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.amber
                : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2, right: 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.amber : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.amber : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),

            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan.name,
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        plan.price,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  if (plan.features.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...plan.features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                f,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
