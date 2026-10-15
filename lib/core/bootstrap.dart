import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/features/sentences/sentence_providers.dart';
import 'package:turkmen_ses/features/session/session.dart';

/// Programma açylyşynyň ýagdaýy (splash ekranda görkezilýär).
@immutable
class BootstrapState {
  const BootstrapState({this.done = false, this.step = 'Taýýarlanýar...'});

  final bool done;
  final String step;
}

/// Programma işe girýän badyna ýerine ýetirilýän ädimler:
///
/// 1. ýerli maglumat bazasyny açmak (drift),
/// 2. sözlem goraghanasyny `assets/sentences_seed.json`-dan ýüklemek,
/// 3. hasaby tora garaşman fonda tassyklamak.
///
/// Hiç bir ädim tor garaşmaýar — UI şol bada çyzylýar.
class BootstrapController extends Notifier<BootstrapState> {
  @override
  BootstrapState build() {
    Future<void>.microtask(_run);
    return const BootstrapState();
  }

  Future<void> _run() async {
    await _setStep('Ýerli maglumat bazasy açylýar...');
    try {
      final database = ref.read(databaseProvider);
      await database.cachedSentenceCount();
    } catch (error) {
      debugPrint('bootstrap: database warmup failed: $error');
    }

    await _setStep('Sözlem goraghanasy taýýarlanýar...');
    try {
      await ref.read(sentenceRepositoryProvider).ensureLocalSeed();
    } catch (error) {
      debugPrint('bootstrap: seed load failed: $error');
    }

    await _setStep('Hasap barlanýar...');
    unawaited(ref.read(sessionProvider.notifier).refresh());

    state = const BootstrapState(done: true, step: 'Taýýar');
  }

  Future<void> _setStep(String step) async {
    state = BootstrapState(done: false, step: step);
    // UI-nyň täzelenmegine mümkinçilik ber (setir kuwwatyny boşatmak).
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

final bootstrapProvider = NotifierProvider<BootstrapController, BootstrapState>(
  BootstrapController.new,
);
