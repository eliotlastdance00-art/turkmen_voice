import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/app/app.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWith((_) => database)],
      child: const TurkmenSesApp(),
    ),
  );
}
