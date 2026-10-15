import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/core/network/api_client.dart';
import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';

/// The API client is configured from the persisted device id + token, so a
/// reinstall-free upgrade keeps the same anonymous account.
///
/// It is created **once** and updated in place: `watch`ing the preferences
/// would rebuild every dependent provider (and refetch the overview) on each
/// preference write.
final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.read(preferencesProvider);
  final client = ApiClient(baseUrl: prefs.serverUrl.isEmpty ? null : prefs.serverUrl);

  void apply(AppPreferences value) {
    client.deviceId = value.deviceId;
    client.token = value.token.isEmpty ? null : value.token;
    if (value.serverUrl.isNotEmpty) {
      client.baseUrl = value.serverUrl;
    }
  }

  apply(prefs);
  ref.listen<AppPreferences>(preferencesProvider, (_, next) => apply(next));
  return client;
});

enum SessionStatus { idle, loading, ready, offline }

@immutable
class SessionState {
  const SessionState({
    this.status = SessionStatus.idle,
    this.profile,
    this.message,
    this.fromCache = false,
  });

  final SessionStatus status;
  final Map<String, dynamic>? profile;
  final String? message;

  /// Profil tordan däl-de, telefondaky ýatdan görkezilýär.
  final bool fromCache;

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

/// Owns the anonymous account.
///
/// The account is created on the first launch and the token the server returns
/// is stored on the device (and in the server database).  When the server is
/// unreachable the app keeps working from the cached profile and retries in the
/// background — a failed registration is never permanent.
class SessionController extends Notifier<SessionState> {
  Timer? _retryTimer;
  int _attempt = 0;
  bool _busy = false;

  @override
  SessionState build() {
    ref.onDispose(() => _retryTimer?.cancel());

    // Profil deň saklanýar: programma açylan badyna at/ball görünýär.
    final cached = ref.read(preferencesProvider).profileSnapshot;
    final initial = cached.isEmpty
        ? const SessionState(status: SessionStatus.loading)
        : SessionState(
            status: SessionStatus.ready,
            profile: Map<String, dynamic>.from(cached),
            fromCache: true,
          );

    Future<void>.microtask(refresh);
    return initial;
  }

  /// Hasaby tassyklaýar: token bar bolsa `/users/me`, ýok bolsa `register`.
  ///
  /// `force` — hasaby noldan täzeden döretmek (sazlamalardaky düwme üçin).
  Future<bool> refresh({bool force = false}) async {
    if (_busy) {
      return state.isReady;
    }
    _busy = true;
    final prefs = ref.read(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final api = ref.read(apiClientProvider);

    try {
      api
        ..deviceId = prefs.deviceId
        ..token = prefs.token.isEmpty ? null : prefs.token;

      if (force) {
        await notifier.clearAccount();
      }

      final token = force ? '' : prefs.token;
      if (token.isEmpty) {
        await _register(api, prefs.deviceId, prefs.displayName, prefs.consentType);
      } else {
        try {
          await _loadProfile(api);
        } on ApiException catch (error) {
          // Token serwerde nädogry (DB täzelenen / başga serwer) → täzeden döret
          if (error.statusCode == 401 || error.statusCode == 403 || error.statusCode == 404) {
            await notifier.clearAccount();
            api.token = null;
            await _register(api, prefs.deviceId, prefs.displayName, prefs.consentType);
          } else {
            rethrow;
          }
        }
      }

      _attempt = 0;
      _retryTimer?.cancel();
      return true;
    } on ApiException catch (error) {
      _setOffline(error.message);
      _scheduleRetry();
      return false;
    } catch (error) {
      _setOffline('Hasaby barlap bolmady: $error');
      _scheduleRetry();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> _register(
    ApiClient api,
    String deviceId,
    String displayName,
    String consentType,
  ) async {
    final result = await api.registerDevice(
      deviceId: deviceId,
      displayName: displayName.isEmpty ? null : displayName,
      consentType: consentType,
    );
    final token = result['token'];
    final user = result['user'];
    final profile = user is Map
        ? user.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    await ref.read(preferencesProvider.notifier).saveAccount(
          token: token is String ? token : '',
          userId: '${profile['id'] ?? ''}',
          displayName: profile['display_name'] is String ? profile['display_name'] as String : null,
        );
    await ref.read(preferencesProvider.notifier).saveProfileSnapshot(profile);
    api.token = token is String && token.isNotEmpty ? token : null;
    state = SessionState(status: SessionStatus.ready, profile: profile);
  }

  Future<void> _loadProfile(ApiClient api) async {
    final response = await api.fetchMe();
    final user = response['user'];
    final profile = user is Map
        ? user.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    await ref.read(preferencesProvider.notifier).saveProfileSnapshot(profile);
    state = SessionState(status: SessionStatus.ready, profile: profile);
  }

  void _setOffline(String? message) {
    state = SessionState(
      status: SessionStatus.offline,
      profile: state.profile ?? _cachedProfile(),
      message: message,
      fromCache: state.profile != null,
    );
  }

  Map<String, dynamic>? _cachedProfile() {
    final snapshot = ref.read(preferencesProvider).profileSnapshot;
    return snapshot.isEmpty ? null : Map<String, dynamic>.from(snapshot);
  }

  /// Tor ýok bolsa, hasaby döretmek üçin yzly-yzyna synanyşýar
  /// (5s → 10s → 20s → … iň köp 2 minut).
  void _scheduleRetry() {
    if (state.isReady || _retryTimer != null) {
      return;
    }
    final step = _attempt < 5 ? _attempt : 5;
    _attempt = _attempt + 1;
    final seconds = 5 * (1 << step);
    final delay = seconds > 120 ? const Duration(minutes: 2) : Duration(seconds: seconds);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(refresh());
    });
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
