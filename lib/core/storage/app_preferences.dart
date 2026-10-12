import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provided (overridden) in `main.dart` after `SharedPreferences.getInstance()`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

@immutable
class AppPreferences {
  const AppPreferences({
    required this.deviceId,
    this.onboardingDone = false,
    this.displayName = '',
    this.token = '',
    this.userId = '',
    this.consentType = 'dataset',
    this.wifiOnly = false,
    this.autoSync = true,
    this.haptics = true,
    this.themeMode = ThemeMode.system,
  });

  final String deviceId;
  final bool onboardingDone;
  final String displayName;
  final String token;
  final String userId;
  final String consentType;
  final bool wifiOnly;
  final bool autoSync;
  final bool haptics;
  final ThemeMode themeMode;

  AppPreferences copyWith({
    String? deviceId,
    bool? onboardingDone,
    String? displayName,
    String? token,
    String? userId,
    String? consentType,
    bool? wifiOnly,
    bool? autoSync,
    bool? haptics,
    ThemeMode? themeMode,
  }) {
    return AppPreferences(
      deviceId: deviceId ?? this.deviceId,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      displayName: displayName ?? this.displayName,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      consentType: consentType ?? this.consentType,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoSync: autoSync ?? this.autoSync,
      haptics: haptics ?? this.haptics,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class PreferencesController extends Notifier<AppPreferences> {
  static const String _deviceKey = 'device_id';
  static const String _onboardingKey = 'onboarding_done';
  static const String _nameKey = 'display_name';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _consentKey = 'consent_type';
  static const String _wifiKey = 'wifi_only';
  static const String _autoSyncKey = 'auto_sync';
  static const String _hapticsKey = 'haptics';
  static const String _themeKey = 'theme_mode';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppPreferences build() {
    final prefs = _prefs;
    var deviceId = prefs.getString(_deviceKey) ?? '';
    if (deviceId.isEmpty) {
      final random = Random();
      deviceId = 'tk-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
          '-${random.nextInt(999999).toRadixString(36)}';
      prefs.setString(_deviceKey, deviceId);
    }
    return AppPreferences(
      deviceId: deviceId,
      onboardingDone: prefs.getBool(_onboardingKey) ?? false,
      displayName: prefs.getString(_nameKey) ?? '',
      token: prefs.getString(_tokenKey) ?? '',
      userId: prefs.getString(_userIdKey) ?? '',
      consentType: prefs.getString(_consentKey) ?? 'dataset',
      wifiOnly: prefs.getBool(_wifiKey) ?? false,
      autoSync: prefs.getBool(_autoSyncKey) ?? true,
      haptics: prefs.getBool(_hapticsKey) ?? true,
      themeMode: _themeFromName(prefs.getString(_themeKey)),
    );
  }

  Future<void> completeOnboarding({required String displayName, required String consentType}) async {
    final cleanName = displayName.trim();
    await _prefs.setBool(_onboardingKey, true);
    await _prefs.setString(_nameKey, cleanName);
    await _prefs.setString(_consentKey, consentType);
    state = state.copyWith(onboardingDone: true, displayName: cleanName, consentType: consentType);
  }

  Future<void> saveAccount({
    required String token,
    required String userId,
    String? displayName,
  }) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userIdKey, userId);
    if (displayName != null && displayName.isNotEmpty) {
      await _prefs.setString(_nameKey, displayName);
    }
    state = state.copyWith(
      token: token,
      userId: userId,
      displayName: displayName ?? state.displayName,
    );
  }

  Future<void> clearAccount() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userIdKey);
    state = state.copyWith(token: '', userId: '');
  }

  Future<void> setDisplayName(String value) async {
    await _prefs.setString(_nameKey, value.trim());
    state = state.copyWith(displayName: value.trim());
  }

  Future<void> setConsentType(String value) async {
    await _prefs.setString(_consentKey, value);
    state = state.copyWith(consentType: value);
  }

  Future<void> setWifiOnly(bool value) async {
    await _prefs.setBool(_wifiKey, value);
    state = state.copyWith(wifiOnly: value);
  }

  Future<void> setAutoSync(bool value) async {
    await _prefs.setBool(_autoSyncKey, value);
    state = state.copyWith(autoSync: value);
  }

  Future<void> setHaptics(bool value) async {
    await _prefs.setBool(_hapticsKey, value);
    state = state.copyWith(haptics: value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, _themeName(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> resetOnboarding() async {
    await _prefs.setBool(_onboardingKey, false);
    state = state.copyWith(onboardingDone: false);
  }

  static ThemeMode _themeFromName(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final preferencesProvider = NotifierProvider<PreferencesController, AppPreferences>(
  PreferencesController.new,
);
