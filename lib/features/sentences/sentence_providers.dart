import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/features/session/session.dart';

/// Programmanyň içindäki sözlem goraghanasy (assets/sentences_seed.json).
const String kSeedAssetPath = 'assets/sentences_seed.json';

/// Sözlemiň nireden gelendigi — UI-da görkezilýär.
enum SentenceOrigin { bundled, remote, custom }

extension SentenceOriginLabel on SentenceOrigin {
  String get label {
    switch (this) {
      case SentenceOrigin.bundled:
        return 'Programmadaky goraghana';
      case SentenceOrigin.remote:
        return 'Serwerden täzelenen';
      case SentenceOrigin.custom:
        return 'Öz sözlemim';
    }
  }
}

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

  /// Ilkinji işledişde sözlemleri programmanyň içindäki faýldan ýükleýär.
  ///
  /// Şu ädimden soň programmatically tora garaşman ýazgy alyp bolýar —
  /// "tekstler nireden gelýär" soragyna jogap: programmanyň öz goraghanasy.
  Future<int> ensureLocalSeed() async {
    final database = ref.read(databaseProvider);
    final cached = await database.cachedSentenceCount();
    if (cached > 0) {
      return 0;
    }
    final raw = await rootBundle.loadString(kSeedAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return 0;
    }
    final sentences = decoded['sentences'];
    if (sentences is! List) {
      return 0;
    }
    final companions = <SentencesCompanion>[];
    for (final item in sentences) {
      if (item is! Map) {
        continue;
      }
      final text = '${item['text'] ?? ''}'.trim();
      if (text.isEmpty) {
        continue;
      }
      companions.add(
        SentencesCompanion.insert(
          id: '${item['id']}',
          textValue: text,
          language: Value('${item['language'] ?? 'tk'}'),
          category: Value('${item['category'] ?? 'general'}'),
          packageId: Value('${item['package_id'] ?? 'package_001'}'),
          wordCount: Value(_int(item['word_count'], fallback: text.split(' ').length)),
          difficulty: Value(_int(item['difficulty'], fallback: 1)),
        ),
      );
    }
    if (companions.isEmpty) {
      return 0;
    }
    await database.replaceSentences(companions);
    return companions.length;
  }

  Future<int> cacheRemoteSentences({String? packageId}) async {
    final rows = await ref.read(apiClientProvider).fetchSentences(packageId: packageId, limit: 2000);
    if (rows.isEmpty) {
      return 0;
    }
    await ref.read(databaseProvider).replaceSentences(_companionsFromApi(rows));
    return rows.length;
  }

  List<SentencesCompanion> _companionsFromApi(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    return rows.map((row) {
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
  }

  /// Öz sözlemiňizi goraghana goşýar (şol bir tekst täzeden soralmаz ýaly).
  Future<Sentence> addCustomSentence({
    required String text,
    required String category,
  }) async {
    final database = ref.read(databaseProvider);
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final cleanCategory = category.isEmpty ? 'custom' : category;
    final words = text.split(' ').where((word) => word.trim().isNotEmpty).length;
    await database.saveSentence(
      SentencesCompanion.insert(
        id: id,
        textValue: text,
        language: const Value('tk'),
        category: Value(cleanCategory),
        packageId: const Value('custom'),
        wordCount: Value(words),
        difficulty: const Value(1),
      ),
    );
    return Sentence(
      id: id,
      textValue: text,
      language: 'tk',
      category: cleanCategory,
      packageId: 'custom',
      wordCount: words,
      difficulty: 1,
      cachedAt: null,
    );
  }

  /// The next sentence for the recorder.
  ///
  /// Bir ulanyjy bir sözlemi **diňe bir gezek** ýazga almaly: eýýäm ýazylan
  /// sözlemler sanawdan aýrylýar. Ählisi ýazylan bolsa `null` gaýtarýar —
  /// UI "öz sözlemiňizi ýazyň" diýip görkezýär.
  Future<Sentence?> nextSentence({String? packageId}) async {
    final database = ref.read(databaseProvider);
    var cached = await database.cachedSentences(packageId: packageId);
    if (cached.isEmpty) {
      await ensureLocalSeed();
      cached = await database.cachedSentences(packageId: packageId);
    }
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
    final used = await database.recordedSentenceIds();
    final fresh = cached.where((row) => !used.contains(row.id)).toList();
    if (fresh.isEmpty) {
      return null;
    }
    fresh.shuffle(Random());
    return fresh.first;
  }

  /// Eýýäm ýazylan sözlemleriň ID-leri (ýazga alnan tekstler boýunça hem).
  Future<Set<String>> recordedSentenceIds() => ref.read(databaseProvider).recordedSentenceIds();

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

/// Offline sentence cache: bundled seed on first run, refreshed from the server.
final localSentencesProvider = StreamProvider<List<Sentence>>(
  (ref) => ref.watch(databaseProvider).watchSentences(),
);

/// Programma açylan badyna sözlem goraghanasyny taýýarlaýar.
final sentenceBootstrapProvider = FutureProvider<int>(
  (ref) => ref.watch(sentenceRepositoryProvider).ensureLocalSeed(),
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

/// Paketleriň atlary (kategoriýa boýunça ätiýaçlyk görnüşi — offline üçin).
const Map<String, String> kCategoryLabels = <String, String>{
  'daily': 'Gündelik gepleşik',
  'numbers': 'Sanlar we wagt',
  'nature': 'Tebigat we howa',
  'education': 'Bilim, iş we tehnologiýa',
  'questions': 'Soraglar we jogaplar',
  'culture': 'Ýerler we medeniýet',
  'custom': 'Öz sözlemim',
  'general': 'Umumy',
};
