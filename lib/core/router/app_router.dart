import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../features/consent/consent_page.dart';
import '../../features/home/home_page.dart';
import '../../features/recordings/recordings_page.dart';
import '../../features/settings/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Shell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomePage()),
            GoRoute(path: '/recordings', builder: (_, __) => const RecordingsPage()),
            GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
          ],
        ),
        GoRoute(path: '/consent', builder: (_, __) => const ConsentPage()),
      ],
    ));
