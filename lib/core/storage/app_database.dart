import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Sentences extends Table {
  TextColumn get id => text()();
  TextColumn get textValue => text().named('text')();
  TextColumn get language => text().withDefault(const Constant('tk'))();
  TextColumn get category => text().withDefault(const Constant('general'))();
  TextColumn get packageId => text().named('package_id')();
  @override Set<Column> get primaryKey => {id};
}

class Recordings extends Table {
  TextColumn get id => text()();
  TextColumn get sentenceId => text().named('sentence_id')();
  TextColumn get textValue => text().named('text')();
  TextColumn get audioPath => text().named('audio_path')();
  IntColumn get durationMs => integer().named('duration_ms')();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get consentType => text().named('consent_type')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get uploadedAt => dateTime().named('uploaded_at').nullable()();
  TextColumn get errorMessage => text().named('error_message').nullable()();
  @override Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Sentences, Recordings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  @override int get schemaVersion => 1;

  Future<List<Recording>> pendingRecordings() => (select(recordings)..where((t) => t.status.equals('pending') | t.status.equals('failed'))).get();
  Stream<List<Recording>> watchRecordings() => select(recordings).watch();
  Future<void> saveRecording(RecordingsCompanion row) => into(recordings).insertOnConflictUpdate(row);
  Future<void> updateStatus(String id, String status, {String? error}) => (update(recordings)..where((t) => t.id.equals(id))).write(
        RecordingsCompanion(status: Value(status), errorMessage: Value(error)),
      );
  Future<void> deleteAllRecordings() => delete(recordings).go();
}

LazyDatabase _openConnection() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/turkmen_ses.sqlite');
      return NativeDatabase.createInBackground(file);
    });

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final recordingsProvider = StreamProvider<List<Recording>>((ref) => ref.watch(databaseProvider).watchRecordings());
