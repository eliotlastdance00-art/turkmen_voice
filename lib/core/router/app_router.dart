import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:turkmen_ses/app/shell.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';
import 'package:turkmen_ses/features/home/home_page.dart';
import 'package:turkmen_ses/features/onboarding/onboarding_page.dart';
import 'package:turkmen_ses/features/profile/profile_page.dart';
import 'package:turkmen_ses/features/ratings/leaderboard_page.dart';
import 'package:turkmen_ses/features/ratings/rate_page.dart';
import 'package:turkmen_ses/features/record/record_page.dart';
import 'package:turkmen_ses/features/recordings/recordings_page.dart';
import 'package:turkmen_ses/features/settings/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(preferencesProvider).onboardingDone;

  return GoRouter(
    initialLocation: onboarded ? '/' : '/onboarding',
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (BuildContext context, GoRouterState state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/record',
                builder: (BuildContext context, GoRouterState state) => const RecordPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/rate',
                builder: (BuildContext context, GoRouterState state) => const RatePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/leaderboard',
                builder: (BuildContext context, GoRouterState state) => const LeaderboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (BuildContext context, GoRouterState state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/recordings',
        builder: (BuildContext context, GoRouterState state) => const Scaffold(body: RecordingsPage()),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) => const Scaffold(body: SettingsPage()),
      ),
    ],
  );
});
