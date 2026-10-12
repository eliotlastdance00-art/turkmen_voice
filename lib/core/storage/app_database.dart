import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Local-first storage.
///
/// Schema v2 adds the offline rating queue, the daily activity counter and
/// the server side columns (remote id, community score, sync attempts).  The
/// v1 database of the first APK is migrated in place, so nobody loses takes.
@DataClassName('Sentence')
class Sentences extends Table {
  TextColumn get id => text()();
  TextColumn get textValue => text().named('text')();
  TextColumn get language => text().withDefault(const Constant('tk'))();
  TextColumn get category => text().withDefault(const Constant('general'))();
  TextColumn get packageId => text().named('package_id').withDefault(const Constant('package_001'))();
  IntColumn get wordCount => integer().named('word_count').withDefault(const Constant(0))();
  IntColumn get difficulty => integer().withDefault(const Constant(1))();
  DateTimeColumn get cachedAt => dateTime().named('cached_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('Recording')
class Recordings extends Table {
  TextColumn get id => text()();
  TextColumn get sentenceId => text().named('sentence_id')();
  TextColumn get textValue => text().named('text')();
  TextColumn get audioPath => text().named('audio_path')();
  IntColumn get durationMs => integer().named('duration_ms')();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get consentType => text().named('consent_type').withDefault(const Constant('dataset'))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get uploadedAt => dateTime().named('uploaded_at').nullable()();
  TextColumn get errorMessage => text().named('error_message').nullable()();
  TextColumn get category => text().withDefault(const Constant('general'))();
  TextColumn get packageId => text().named('package_id').withDefault(const Constant(''))();
  IntColumn get syncAttempts => integer().named('sync_attempts').withDefault(const Constant(0))();
  RealColumn get qualityScore => real().named('quality_score').nullable()();
  IntColumn get ratingCount => integer().named('rating_count').withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Ratings the user gave while offline — flushed to the server by the sync
/// service, then marked as synced.
@DataClassName('Rating')
class Ratings extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId => text().named('recording_id')();
  IntColumn get score => integer()();
  BoolColumn get matchesText => boolean().named('matches_text').withDefault(const Constant(true))();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteText => text().named('remote_text').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('DailyStat')
class DailyStats extends Table {
  TextColumn get day => text()();
  IntColumn get seconds => integer().withDefault(const Constant(0))();
  IntColumn get recordings => integer().withDefault(const Constant(0))();
  IntColumn get ratings => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{day};
}

@DriftDatabase(tables: <Type>[Sentences, Recordings, Ratings, DailyStats])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // v1 databases (first APK) miss these columns/tables.
            await m.addColumn(recordings, recordings.category);
            await m.addColumn(recordings, recordings.packageId);
            await m.addColumn(recordings, recordings.syncAttempts);
            await m.addColumn(recordings, recordings.qualityScore);
            await m.addColumn(recordings, recordings.ratingCount);
            await m.createTable(ratings);
            await m.createTable(dailyStats);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ------------------------------------------------------------- recordings
  Stream<List<Recording>> watchRecordings() {
    return (select(recordings)..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Recording>> allRecordings() => select(recordings).get();

  Future<List<Recording>> pendingRecordings() {
    return (select(recordings)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<void> saveRecording(RecordingsCompanion row) => into(recordings).insertOnConflictUpdate(row);

  Future<void> updateStatus(String id, String status, {String? error}) {
    return (update(recordings)..where((t) => t.id.equals(id))).write(
      RecordingsCompanion(status: Value(status), errorMessage: Value(error)),
    );
  }

  Future<void> markUploaded(String id, {double? qualityScore, int? ratingCount}) {
    return (update(recordings)..where((t) => t.id.equals(id))).write(
      RecordingsCompanion(
        status: const Value('uploaded'),
        uploadedAt: Value(DateTime.now()),
        errorMessage: const Value(null),
        qualityScore: qualityScore == null ? const Value.absent() : Value(qualityScore),
        ratingCount: ratingCount == null ? const Value.absent() : Value(ratingCount),
      ),
    );
  }

  Future<void> bumpSyncAttempt(String id) async {
    final row = await (select(recordings)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return;
    }
    await (update(recordings)..where((t) => t.id.equals(id)))
        .write(RecordingsCompanion(syncAttempts: Value(row.syncAttempts + 1)));
  }

  Future<void> deleteRecording(String id) =>
      (delete(recordings)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAllRecordings() => delete(recordings).go();

  // -------------------------------------------------------------- sentences
  Stream<List<Sentence>> watchSentences() {
    return (select(sentences)..orderBy([(t) => OrderingTerm(expression: t.id)])).watch();
  }

  Future<List<Sentence>> cachedSentences({String? packageId}) {
    final query = select(sentences);
    if (packageId != null && packageId.isNotEmpty) {
      query.where((t) => t.packageId.equals(packageId));
    }
    return query.get();
  }

  Future<int> cachedSentenceCount() async {
    final rows = await select(sentences).get();
    return rows.length;
  }

  Future<void> replaceSentences(List<SentencesCompanion> rows) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(sentences, rows);
    });
  }

  // ---------------------------------------------------------------- ratings
  Future<void> queueRating(RatingsCompanion row) => into(ratings).insertOnConflictUpdate(row);

  Future<List<Rating>> pendingRatings() =>
      (select(ratings)..where((t) => t.synced.equals(false))).get();

  Future<void> markRatingSynced(String id) =>
      (update(ratings)..where((t) => t.id.equals(id))).write(const RatingsCompanion(synced: Value(true)));

  Future<void> deleteRating(String id) => (delete(ratings)..where((t) => t.id.equals(id))).go();

  Stream<List<Rating>> watchRatings() {
    return (select(ratings)..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // ------------------------------------------------------------ daily stats
  static String todayKey([DateTime? moment]) {
    final value = moment ?? DateTime.now();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> addDailyActivity({int seconds = 0, int recordings = 0, int ratings = 0}) async {
    final today = todayKey();
    final existing = await (select(dailyStats)..where((t) => t.day.equals(today))).getSingleOrNull();
    final row = existing ?? const DailyStat(day: '', seconds: 0, recordings: 0, ratings: 0);
    await into(dailyStats).insertOnConflictUpdate(
      DailyStatsCompanion(
        day: Value(today),
        seconds: Value(row.seconds + seconds),
        recordings: Value(row.recordings + recordings),
        ratings: Value(row.ratings + ratings),
      ),
    );
  }

  Future<DailyStat?> todayActivity() =>
      (select(dailyStats)..where((t) => t.day.equals(todayKey()))).getSingleOrNull();

  Stream<DailyStat?> watchTodayActivity() =>
      (select(dailyStats)..where((t) => t.day.equals(todayKey()))).watchSingleOrNull();

  Future<List<DailyStat>> recentActivity({int days = 14}) {
    return (select(dailyStats)
          ..orderBy([(t) => OrderingTerm(expression: t.day, mode: OrderingMode.desc)])
          ..limit(days))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'turkmen_ses.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final recordingsProvider = StreamProvider<List<Recording>>(
  (ref) => ref.watch(databaseProvider).watchRecordings(),
);

final ratingsProvider = StreamProvider<List<Rating>>(
  (ref) => ref.watch(databaseProvider).watchRatings(),
);

final todayActivityProvider = StreamProvider<DailyStat?>(
  (ref) => ref.watch(databaseProvider).watchTodayActivity(),
);
