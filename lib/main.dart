import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'firebase_options.dart';
import 'theme/tokens.dart';
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart';
import 'router/router.dart';
import 'services/iap_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Suppress noisy image-loading HTTP errors on web.
  // Firebase Storage URLs fail Image.network with statusCode: 0 (CORS)
  // but are handled gracefully via the HTML <img> fallback in SafeNetworkImage.
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('HTTP request failed, statusCode: 0') ||
        message.contains('Failed to load network image') ||
        message.contains('NetworkImageLoadException')) {
      // Silently swallow — the SafeNetworkImage widget handles these via fallback.
      return;
    }
    defaultOnError?.call(details);
  };

  runApp(const ProviderScope(child: _IAPListener(child: StorybridgeApp())));
}

// ── App-level IAP listener ────────────────────────────────────────────────────
//
// Apple requires completePurchase() to be called for every purchase update,
// including those delivered on a fresh app launch from a previous session.
// This widget sits above StorybridgeApp and satisfies that obligation.
// It also writes the Firestore subscription record for purchases that
// complete outside of the paywall screen (e.g. after an app restart).

class _IAPListener extends ConsumerStatefulWidget {
  final Widget child;
  const _IAPListener({required this.child});

  @override
  ConsumerState<_IAPListener> createState() => _IAPListenerState();
}

class _IAPListenerState extends ConsumerState<_IAPListener> {
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = IAPService.purchaseStream.listen(_handlePurchases);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await IAPService.completePurchase(purchase);

        // Verify with Apple and write to Firestore in case the paywall screen
        // is not mounted (purchase completed in the background / on app relaunch).
        final uid = ref.read(currentUidProvider);
        if (uid != null && purchase.purchaseID != null) {
          try {
            await IAPService.verifyWithServer(
              transactionId: purchase.purchaseID!,
              uid: uid,
            );
          } catch (_) {
            // Best-effort; the paywall screen handles errors for active flows.
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── App shell ─────────────────────────────────────────────────────────────────

class StorybridgeApp extends ConsumerWidget {
  const StorybridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appState = ref.watch(appStateProvider);

    const tokens = StorybridgeTokens();
    final scale = kAppScale[appState.appTextSize.name] ?? 1.0;

    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    final customTextTheme = baseTextTheme.copyWith(
      displayLarge: const TextStyle(fontWeight: FontWeight.bold),
      displayMedium: const TextStyle(fontWeight: FontWeight.bold),
      displaySmall: const TextStyle(fontWeight: FontWeight.bold),
      headlineLarge: const TextStyle(fontWeight: FontWeight.bold),
      headlineMedium: const TextStyle(fontWeight: FontWeight.bold),
      headlineSmall: const TextStyle(fontWeight: FontWeight.bold),
      titleLarge: const TextStyle(fontWeight: FontWeight.bold),
      titleMedium: const TextStyle(fontWeight: FontWeight.bold),
      titleSmall: const TextStyle(fontWeight: FontWeight.bold),
      bodyLarge: const TextStyle(fontWeight: FontWeight.normal),
      bodyMedium: const TextStyle(fontWeight: FontWeight.normal),
      bodySmall: const TextStyle(fontWeight: FontWeight.normal),
      labelLarge: const TextStyle(fontWeight: FontWeight.normal),
      labelMedium: const TextStyle(fontWeight: FontWeight.normal),
      labelSmall: const TextStyle(fontWeight: FontWeight.normal),
    ).apply(
      fontFamily: 'Area Normal',
      fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif'],
      bodyColor: tokens.coffeeBean,
      displayColor: tokens.coffeeBean,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Storybridge',
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: tokens.cream,
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif'],
          colorScheme: ColorScheme.fromSeed(
            seedColor: tokens.brightFern,
            primary: tokens.brightFern,
            secondary: tokens.tigerFlame,
            surface: tokens.porcelain,
            onSurface: tokens.coffeeBean,
          ),
          textTheme: customTextTheme,
          extensions: const [tokens],
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
      ),
    );
  }
}

// Custom page transition as per spec
CustomTransitionPage buildPageWithTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}
