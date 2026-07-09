import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suar_app/features/map_evacuation/presentation/map_screen.dart';
import 'package:suar_app/features/onboarding/presentation/onboarding_screen.dart';
import '../../features/map_evacuation/presentation/cache_management_screen.dart';
import '../../features/resources/presentation/emergency_numbers_screen.dart';
import '../../features/resources/presentation/first_aid_screen.dart';

import '../../features/user/presentation/user_notifier.dart';
import '../../features/user/presentation/profile_screen.dart';
import 'shell_screen.dart';
import '../../features/ews_ai/presentation/home_screen.dart';
import '../../features/ews_ai/presentation/ews_testing_screen.dart';
import '../../features/ews_ai/presentation/ews_interactive_simulator_screen.dart';
import '../../features/map_evacuation/presentation/risk_map_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(userProvider);
  final hasCompletedOnboarding = user != null;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,

    redirect: (context, state) {
      final isGoingToOnboarding = state.uri.path == '/onboarding';

      if (!hasCompletedOnboarding && !isGoingToOnboarding) {
        return '/onboarding';
      }

      if (hasCompletedOnboarding && isGoingToOnboarding) {
        return '/';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        path: '/map',
        name: 'map',
        builder: (context, state) => const MapScreen(),
      ),

      GoRoute(
        path: '/testing',
        name: 'testing',
        builder: (context, state) => const EwsTestingScreen(),
      ),

      GoRoute(
        path: '/interactive-simulator',
        name: 'interactive_simulator',
        builder: (context, state) => const EwsInteractiveSimulatorScreen(),
      ),

      GoRoute(
        path: '/cache-management',
        name: 'cache_management',
        builder: (context, state) => const CacheManagementScreen(),
      ),

      GoRoute(
        path: '/emergency-numbers',
        name: 'emergency_numbers',
        builder: (context, state) => const EmergencyNumbersScreen(),
      ),

      GoRoute(
        path: '/first-aid',
        name: 'first_aid',
        builder: (context, state) => const FirstAidScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Risk Map
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/risk-map',
                name: 'risk_map',
                builder: (context, state) => const RiskMapScreen(),
              ),
            ],
          ),
          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
