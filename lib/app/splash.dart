import 'package:flutter/material.dart';

import 'package:turkmen_ses/core/branding.dart';
import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';

/// Programma taýýarlanýan wagty görkezilýän ekran.
///
/// Maksady: birinji kadr **derrew** çyzylsyn we gara/ak boş ekran ýerine
/// at, reňk we ýagdaý görünsin.
class SplashScreen extends StatelessWidget {
  const SplashScreen({this.message = 'Taýýarlanýar...', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppTheme.brand, scheme.primary, AppTheme.brandLight],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Programmanyň ikonasy (assets/branding/app_icon.png-den öndürilen)
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Image.asset(
                  kAppIconAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.white.withValues(alpha: 0.16),
                    child: const Icon(Icons.graphic_eq_rounded, size: 48, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppConfig.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Türkmençe ses maglumat ýygnamak',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
