import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/core/network/api_client.dart';
import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';

/// The API client is configured from the persisted device id + token, so a
/// reinstall-free upgrade keeps the same anonymous account.
final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(preferencesProvider);
  final client = ApiClient();
  client.deviceId = prefs.deviceId;
  client.token = prefs.token.isEmpty ? null : prefs.token;
  return client;
});

enum SessionStatus { idle, loading, ready, offline }

@immutable
class SessionState {
  const SessionState({this.status = SessionStatus.idle, this.profile, this.message});

  final SessionStatus status;
  final Map<String, dynamic>? profile;
  final String? message;

  bool get isReady => status == SessionStatus.ready;
  bool get isOffline => status == SessionStatus.offline;

  String get displayName {
    final value = profile?['display_name'];
    return value is String && value.isNotEmpty ? value : 'Myhman';
  }

  int get points => _int(profile?['points']);

  int get avatarSeed => _int(profile?['avatar_seed']);

  int get streakDays => _int(profile?['streak_days']);

  int? get rank => profile?['rank'] == null ? null : _int(profile?['rank']);

  String get levelName {
    final level = profile?['level'];
    if (level is Map && level['name'] is String) {
      return level['name'] as String;
    }
    return 'Başlangyç';
  }

  double get levelProgress {
    final level = profile?['level'];
    if (level is Map && level['progress'] is num) {
      return (level['progress'] as num).toDouble();
    }
    return 0;
  }

  Map<String, dynamic> get stats {
    final value = profile?['stats'];
    return value is Map ? value.map((key, item) => MapEntry(key.toString(), item)) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> get badges {
    final value = profile?['badges'];
    if (value is List) {
      return value.whereType<Map>().map((item) => item.map((key, v) => MapEntry(key.toString(), v))).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static int _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

/// Owns the anonymous account: registers on first launch, refreshes on
/// demand and keeps the app usable while the server is unreachable.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future<void>.microtask(refresh);
    return const SessionState(status: SessionStatus.loading);
  }

  Future<void> refresh() async {
    final prefs = ref.read(preferencesProvider);
    final api = ref.read(apiClientProvider);
    api.deviceId = prefs.deviceId;
    api.token = prefs.token.isEmpty ? null : prefs.token;
    state = SessionState(status: state.profile == null ? SessionStatus.loading : state.status, profile: state.profile);

    try {
      if (prefs.token.isEmpty) {
        final result = await api.registerDevice(
          deviceId: prefs.deviceId,
          displayName: prefs.displayName.isEmpty ? null : prefs.displayName,
          consentType: prefs.consentType,
        );
        final token = result['token'];
        final user = result['user'];
        final userId = user is Map ? '${user['id']}' : '';
        await ref.read(preferencesProvider.notifier).saveAccount(
              token: token is String ? token : '',
              userId: userId,
              displayName: user is Map && user['display_name'] is String ? user['display_name'] as String : prefs.displayName,
            );
        api.token = token is String ? token : null;
        state = SessionState(
          status: SessionStatus.ready,
          profile: user is Map ? user.map((key, value) => MapEntry(key.toString(), value)) : null,
        );
        return;
      }

      final profile = await api.fetchMe();
      final user = profile['user'];
      state = SessionState(
        status: SessionStatus.ready,
        profile: user is Map ? user.map((key, value) => MapEntry(key.toString(), value)) : null,
      );
    } on ApiException catch (error) {
      state = SessionState(
        status: SessionStatus.offline,
        profile: state.profile,
        message: error.message,
      );
    }
  }

  Future<void> updateDisplayName(String name) async {
    final api = ref.read(apiClientProvider);
    await ref.read(preferencesProvider.notifier).setDisplayName(name);
    try {
      await api.updateMe(displayName: name);
      await refresh();
    } on ApiException {
      // offline: the name is stored locally and pushed on the next sync
    }
  }

  Future<void> updateConsent(String consentType) async {
    await ref.read(preferencesProvider.notifier).setConsentType(consentType);
    try {
      await ref.read(apiClientProvider).updateMe(consentType: consentType);
    } on ApiException {
      // will be retried later
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// --------------------------------------------------------------- public data

final overviewProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(apiClientProvider).fetchOverview(),
);

final myStatsProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(apiClientProvider).fetchMyStats(),
);

final leaderboardProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, period) => ref.watch(apiClientProvider).fetchLeaderboard(limit: 30, period: period),
);

final ratingQueueProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, limit) => ref.watch(apiClientProvider).fetchRatingQueue(limit: limit),
);
