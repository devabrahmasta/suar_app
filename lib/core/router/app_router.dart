import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suar_app/features/map_evacuation/presentation/map_screen.dart';
import 'package:suar_app/features/onboarding/presentation/onboarding_screen.dart';
import '../../features/map_evacuation/presentation/cache_management_screen.dart';

import '../../features/user/presentation/user_notifier.dart';
import '../../features/user/presentation/profile_screen.dart';
import 'shell_screen.dart';
import '../../features/ews_ai/presentation/home_screen.dart';
import '../../features/ews_ai/presentation/ews_testing_screen.dart';
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
        path: '/cache-management',
        name: 'cache_management',
        builder: (context, state) => const CacheManagementScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Chat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                name: 'chat',
                builder: (context, state) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: 'dm/:peerId',
                    name: 'direct_message',
                    builder: (context, state) {
                      final peerId = state.pathParameters['peerId']!;
                      return Scaffold(
                        appBar: AppBar(title: const Text('Private Chat')),
                        body: Center(child: Text('Chatting dengan: $peerId')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Risk Map
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/risk-map',
                name: 'risk_map',
                builder: (context, state) => const RiskMapScreen(),
              ),
            ],
          ),
          // Branch 3: Profile
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
