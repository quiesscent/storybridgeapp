import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../models/app_state.dart';
import '../models/settings_model.dart';
import '../models/watch_payload.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/auth_home_screen.dart';
import '../screens/auth/auth_screens.dart';
import '../screens/onboarding/role_screen.dart';
import '../screens/onboarding/loved_ones_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/library/book_detail_screen.dart';
import '../screens/recording/setup_text_screen.dart';
import '../screens/recording/setup_checks_screen.dart';
import '../screens/recording/setup_mic_screen.dart';
import '../screens/recording/setup_video_screen.dart';
import '../screens/recording/own_title_screen.dart';
import '../screens/recording/recording_screen.dart';
import '../screens/recording/preview_screen.dart';
import '../screens/recording/edit_recording_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/text_size_screen.dart';
import '../screens/profile/subscription_screen.dart';
import '../screens/profile/plans_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/notifications_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/help_support_screen.dart';
import '../screens/profile/privacy_policy_screen.dart';
import '../screens/profile/terms_service_screen.dart';
import '../screens/my_stories/my_stories_screen.dart';
import '../screens/watch/watch_screen.dart';
import '../screens/paywall/paywall_screen.dart';
import '../widgets/app_scaffold.dart';

/// Notifies GoRouter to re-evaluate its redirect whenever auth or app state changes.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AppState>(appStateProvider, (_, __) => notifyListeners());
    ref.listen<AsyncValue<User?>>(
        firebaseUserProvider, (_, __) => notifyListeners());
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Public routes — no auth check
      if (loc == '/splash') return null;
      if (loc.startsWith('/watch')) return null;

      final firebaseUser = ref.read(firebaseUserProvider).valueOrNull;
      final appState = ref.read(appStateProvider);

      final isAuth = loc.startsWith('/auth');
      final isOnboard = loc.startsWith('/onboard');

      // Not authenticated AND not continuing as guest → force to auth
      if (firebaseUser == null && !appState.isGuest) {
        return isAuth ? null : '/auth';
      }

      // Authenticated or guest but not onboarded → force through onboarding
      if (!appState.onboarded && !isOnboard && !isAuth) {
        return '/onboard/role';
      }

      // Already onboarded → bounce away from auth / onboard screens
      if (appState.onboarded && (isAuth || isOnboard)) {
        return '/library';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthHomeScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateAccountScreen(),
          ),
          GoRoute(
            path: 'signin',
            builder: (context, state) => const SignInScreen(),
          ),
          GoRoute(
            path: 'forgot',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/onboard/role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/onboard/loved',
        builder: (context, state) => const LovedOnesScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'book/:storyId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        BookDetailScreen(storyId: state.pathParameters['storyId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stories',
                builder: (context, state) => const MyStoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'text-size',
                    builder: (context, state) => const TextSizeScreen(),
                  ),
                  GoRoute(
                    path: 'subscription',
                    builder: (context, state) => const SubscriptionScreen(),
                  ),
                  GoRoute(
                    path: 'plans',
                    builder: (context, state) => const PlansScreen(),
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'help',
                    builder: (context, state) => const HelpSupportScreen(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    builder: (context, state) => const PrivacyPolicyScreen(),
                  ),
                  GoRoute(
                    path: 'terms',
                    builder: (context, state) => const TermsServiceScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/setup/text/:storyId',
        builder: (context, state) =>
            SetupTextScreen(storyId: state.pathParameters['storyId']),
      ),
      GoRoute(
        path: '/setup/check/:storyId',
        builder: (context, state) {
          final raw = state.pathParameters['storyId'];
          return SetupChecksScreen(
              storyId: (raw == null || raw == 'null') ? null : raw);
        },
      ),
      GoRoute(
        path: '/paywall',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final storyId = state.uri.queryParameters['storyId'];
          final planId = state.uri.queryParameters['planId'];
          return PaywallScreen(
            storyId: (storyId == null || storyId.isEmpty) ? null : storyId,
            planId: (planId == null || planId.isEmpty) ? null : planId,
          );
        },
      ),
      GoRoute(
        path: '/own-title',
        builder: (context, state) => const OwnTitleScreen(),
      ),
      GoRoute(
        path: '/setup/mic/:storyId',
        builder: (context, state) {
          final raw = state.pathParameters['storyId'];
          return SetupMicScreen(
              storyId: (raw == null || raw == 'null') ? null : raw);
        },
      ),
      GoRoute(
        path: '/setup/video/:storyId',
        builder: (context, state) {
          final raw = state.pathParameters['storyId'];
          return SetupVideoScreen(
              storyId: (raw == null || raw == 'null') ? null : raw);
        },
      ),
      GoRoute(
        path: '/recording/:storyId',
        builder: (context, state) {
          final video = state.uri.queryParameters['video'] == 'true';
          final raw = state.pathParameters['storyId'];
          return RecordingScreen(
            storyId: (raw == null || raw == 'null') ? null : raw,
            videoOn: video,
          );
        },
      ),
      GoRoute(
        path: '/preview/:recordingId',
        builder: (context, state) =>
            PreviewScreen(recordingId: state.pathParameters['recordingId']!),
      ),
      GoRoute(
        path: '/edit/:recordingId',
        builder: (context, state) => EditRecordingScreen(
            recordingId: state.pathParameters['recordingId']!),
      ),
      GoRoute(
        path: '/watch',
        builder: (context, state) {
          final recId = state.uri.queryParameters['recordingId'] ?? '';
          final token = state.uri.queryParameters['t'];

          WatchPayload? payload;
          if (token != null && token.isNotEmpty) {
            try {
              payload = WatchPayload.fromToken(token);
            } catch (_) {}
          }

          if (payload == null) {
            final url = state.uri.queryParameters['url'] ?? state.uri.queryParameters['videoUrl'] ?? '';
            if (url.isNotEmpty) {
              payload = WatchPayload(
                recId: recId,
                videoUrl: Uri.decodeComponent(url),
                title: 'Story',
                settings: SettingsModel.fromQueryParams(state.uri.queryParameters),
              );
            }
          }

          return WatchScreen(
            recordingId: recId,
            payload: payload,
            queryParams: state.uri.queryParameters,
          );
        },
      ),
      GoRoute(
        path: '/watch/:recordingId',
        builder: (context, state) {
          final recId = state.pathParameters['recordingId']!;
          final token = state.uri.queryParameters['t'];

          WatchPayload? payload;
          if (token != null && token.isNotEmpty) {
            try {
              payload = WatchPayload.fromToken(token);
            } catch (_) {}
          }

          if (payload == null) {
            final url = state.uri.queryParameters['url'] ?? state.uri.queryParameters['videoUrl'] ?? '';
            if (url.isNotEmpty) {
              payload = WatchPayload(
                recId: recId,
                videoUrl: Uri.decodeComponent(url),
                title: 'Story',
                settings: SettingsModel.fromQueryParams(state.uri.queryParameters),
              );
            }
          }

          return WatchScreen(
            recordingId: recId,
            payload: payload,
            queryParams: state.uri.queryParameters,
          );
        },
      ),

    ],
  );
});
