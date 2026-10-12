import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/features/session/session.dart';

@immutable
class SentencePack {
  const SentencePack({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.sentenceCount,
    required this.approvedRecordings,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int sentenceCount;
  final int approvedRecordings;

  double get progress => sentenceCount == 0 ? 0 : (approvedRecordings / sentenceCount).clamp(0, 1);

  factory SentencePack.fromJson(Map<String, dynamic> json) {
    return SentencePack(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Paket'}',
      description: '${json['description'] ?? ''}',
      category: '${json['category'] ?? 'general'}',
      sentenceCount: _int(json['sentence_count']),
      approvedRecordings: _int(json['approved_recordings']),
    );
  }

  static int _int(Object? value) => value is num ? value.round() : int.tryParse('$value') ?? 0;
}

/// Remote sentence library + local cache in drift (offline first).
class SentenceRepository {
  SentenceRepository(this.ref);

  final Ref ref;

  Future<List<SentencePack>> fetchPackages() async {
    final rows = await ref.read(apiClientProvider).fetchPackages();
    return rows.map(SentencePack.fromJson).toList();
  }

  Future<int> cacheRemoteSentences({String? packageId}) async {
    final rows = await ref.read(apiClientProvider).fetchSentences(packageId: packageId, limit: 2000);
    if (rows.isEmpty) {
      return 0;
    }
    final now = DateTime.now();
    final companions = rows.map((row) {
      final text = '${row['text'] ?? ''}';
      return SentencesCompanion.insert(
        id: '${row['id']}',
        textValue: text,
        language: Value('${row['language'] ?? 'tk'}'),
        category: Value('${row['category'] ?? 'general'}'),
        packageId: Value('${row['package_id'] ?? 'package_001'}'),
        wordCount: Value(_int(row['word_count'], fallback: text.split(' ').length)),
        difficulty: Value(_int(row['difficulty'], fallback: 1)),
        cachedAt: Value(now),
      );
    }).toList();
    await ref.read(databaseProvider).replaceSentences(companions);
    return companions.length;
  }

  /// The next sentence for the recorder: prefers sentences with no local take.
  Future<Sentence?> nextSentence({String? packageId, List<String> exclude = const <String>[]}) async {
    final database = ref.read(databaseProvider);
    var cached = await database.cachedSentences(packageId: packageId);
    if (cached.isEmpty) {
      try {
        await cacheRemoteSentences(packageId: packageId);
      } catch (_) {
        return null;
      }
      cached = await database.cachedSentences(packageId: packageId);
    }
    if (cached.isEmpty) {
      return null;
    }
    final taken = await database.allRecordings();
    final usedIds = taken.map((row) => row.sentenceId).toSet();
    final fresh = cached.where((row) => !usedIds.contains(row.id)).toList();
    final pool = fresh.isNotEmpty ? fresh : cached;
    pool.shuffle(Random());
    return pool.first;
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse('$value') ?? fallback;
  }
}

final sentenceRepositoryProvider = Provider<SentenceRepository>(SentenceRepository.new);

final sentencePacksProvider = FutureProvider<List<SentencePack>>(
  (ref) => ref.watch(sentenceRepositoryProvider).fetchPackages(),
);

/// Offline sentence cache: seeded on first run, refreshed in the background.
final localSentencesProvider = StreamProvider<List<Sentence>>(
  (ref) => ref.watch(databaseProvider).watchSentences(),
);

final nextSentenceProvider = FutureProvider.family<Sentence?, String>(
  (ref, packageId) async {
    final repository = ref.watch(sentenceRepositoryProvider);
    try {
      return await repository.nextSentence(packageId: packageId.isEmpty ? null : packageId);
    } catch (_) {
      return null;
    }
  },
);

final selectedPackProvider = StateProvider<String>((ref) => '');
