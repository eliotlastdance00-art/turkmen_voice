import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/app/splash.dart';
import 'package:turkmen_ses/core/bootstrap.dart';
import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/router/app_router.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';

class TurkmenSesApp extends ConsumerWidget {
  const TurkmenSesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    // Sözlem goraghanasy ýüklenýänçä splash görkezilýär (birnäçe on millisekunt).
    final bootstrap = ref.watch(bootstrapProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: preferences.themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        if (!bootstrap.done) {
          return SplashScreen(message: bootstrap.step);
        }
        // keep the layout predictable on very large system fonts
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
