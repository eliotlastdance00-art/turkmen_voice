import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:turkmen_ses/app/app.dart';
import 'package:turkmen_ses/features/consent/consent_page.dart';
import 'package:turkmen_ses/features/home/home_page.dart';
import 'package:turkmen_ses/features/recordings/recordings_page.dart';
import 'package:turkmen_ses/features/settings/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Shell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomePage()),
            GoRoute(path: '/recordings', builder: (_, _) => const RecordingsPage()),
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ],
        ),
        GoRoute(path: '/consent', builder: (_, _) => const ConsentPage()),
      ],
    ));
