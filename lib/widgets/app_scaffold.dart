import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'bottom_tabs.dart';
import '../providers/in_app_notification_provider.dart';
import '../theme/tokens.dart';
import '../theme/google_fonts.dart';

class AppScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = ref.watch(inAppNotificationProvider);
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          if (notification != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: child!,
                    );
                  },
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    color: tokens.porcelain,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tokens.brightFern.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.brightFern.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_circle_outline, color: tokens.brightFern, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: tokens.coffeeBean,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notification.message,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: tokens.darkSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (notification.actionLabel != null && notification.actionRoute != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                ref.read(inAppNotificationProvider.notifier).dismiss();
                                context.push(notification.actionRoute!);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                notification.actionLabel!,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: tokens.tigerFlame,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: tokens.darkSlate),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              ref.read(inAppNotificationProvider.notifier).dismiss();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomTabs(
        active: AppTab.values[navigationShell.currentIndex],
        onChanged: (tab) {
          final index = tab.index;
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
