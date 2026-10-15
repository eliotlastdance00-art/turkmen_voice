import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:turkmen_ses/app/app.dart';
import 'package:turkmen_ses/app/splash.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';

/// Ilkinji kadr **haçan-da bolsa bir wagt** çyzylmagy üçin:
/// `SharedPreferences` we drift fonda taýýarlanýar, ekranda bolsa şol bada
/// brendlenen splash görünýär (öň: ak ekran + garaşmak).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TurkmenSesBootstrap());
}

class TurkmenSesBootstrap extends StatefulWidget {
  const TurkmenSesBootstrap({super.key});

  @override
  State<TurkmenSesBootstrap> createState() => _TurkmenSesBootstrapState();
}

class _TurkmenSesBootstrapState extends State<TurkmenSesBootstrap> {
  late final Future<SharedPreferences> _preferences = SharedPreferences.getInstance();
  late final AppDatabase _database = AppDatabase();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _preferences,
      builder: (BuildContext context, AsyncSnapshot<SharedPreferences> snapshot) {
        final preferences = snapshot.data;
        if (preferences == null) {
          return MaterialApp(
            title: 'Türkmen Ses',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const SplashScreen(message: 'Sazlamalar açylýar...'),
          );
        }
        return ProviderScope(
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(preferences),
            databaseProvider.overrideWithValue(_database),
          ],
          child: const TurkmenSesApp(),
        );
      },
    );
  }
}
