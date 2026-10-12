import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/core/widgets/app_widgets.dart';
import 'package:turkmen_ses/features/sentences/sentence_providers.dart';
import 'package:turkmen_ses/features/session/session.dart';
import 'package:turkmen_ses/features/sync/sync_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Map<String, dynamic>? _serverInfo;
  String? _serverError;
  bool _checking = false;
  String? _status;

  Future<void> _checkServer() async {
    setState(() {
      _checking = true;
      _serverError = null;
    });
    try {
      final info = await ref.read(apiClientProvider).readiness();
      setState(() => _serverInfo = info);
    } on ApiException catch (error) {
      setState(() {
        _serverInfo = null;
        _serverError = error.message;
      });
    }
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);
    final recordings = ref.watch(recordingsProvider).valueOrNull ?? const <Recording>[];
    final sentences = ref.watch(localSentencesProvider).valueOrNull ?? const <Sentence>[];
    final sync = ref.watch(syncControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(
          child: GradientHeader(
            title: 'Sazlamalar',
            subtitle: 'Gizlinlik, sinhronizasiýa we programma barada',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          sliver: SliverList.list(
            children: <Widget>[
              const SectionTitle('Sinhronizasiýa'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: prefs.autoSync,
                      onChanged: controller.setAutoSync,
                      secondary: const Icon(Icons.sync_rounded),
                      title: const Text('Awtomatiki sinhronizasiýa'),
                      subtitle: const Text('Internet gelende nobat özi iberiler'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: prefs.wifiOnly,
                      onChanged: controller.setWifiOnly,
                      secondary: const Icon(Icons.wifi_rounded),
                      title: const Text('Diňe Wi-Fi arkaly iber'),
                      subtitle: const Text('Mobil maglumat tygşytlanýar'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: const Text('Nobaty häzir iber'),
                      subtitle: Text(
                        sync.running
                            ? 'Iberilýär... ${sync.done}/${sync.total}'
                            : '${recordings.where((row) => row.status == 'pending' || row.status == 'failed').length} ýazgy nobatda',
                      ),
                      trailing: sync.running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: sync.running ? null : () => ref.read(syncControllerProvider.notifier).run(),
                    ),
                    if (sync.lastMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          sync.lastMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Görnüş'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.brightness_6_rounded),
                      title: const Text('Tema'),
                      subtitle: Text(_themeLabel(prefs.themeMode)),
                      onTap: () => _pickTheme(prefs.themeMode),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: prefs.haptics,
                      onChanged: controller.setHaptics,
                      secondary: const Icon(Icons.vibration_rounded),
                      title: const Text('Titrme duýgury'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Razylyk we gizlinlik', subtitle: 'Saýlawyňyzy islendik wagt üýtgedip bilersiňiz'),
              SurfaceCard(
                child: Column(
                  children: <Widget>[
                    _consentOption(
                      value: 'dataset',
                      selected: prefs.consentType,
                      title: 'Açyk dataset üçin',
                      body: 'Ses türkmençe STT datasetinde we açyk modellerde ulanylyp bilner.',
                      icon: Icons.public_rounded,
                      onChanged: (value) {
                        ref.read(sessionProvider.notifier).updateConsent(value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _consentOption(
                      value: 'internal',
                      selected: prefs.consentType,
                      title: 'Diňe içerki taýýarlyk',
                      body: 'Ses açyk paýlaşylmaz, diňe içerki model öwredişinde ulanylar.',
                      icon: Icons.lock_outline_rounded,
                      onChanged: (value) {
                        ref.read(sessionProvider.notifier).updateConsent(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Maglumatlar'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: const Text('Sözlem paketini ýükle'),
                      subtitle: Text('Lokal keşde ${sentences.length} sözlem bar'),
                      onTap: () async {
                        try {
                          final count = await ref.read(sentenceRepositoryProvider).cacheRemoteSentences();
                          _snack('$count sözlem keşe ýazyldy.');
                        } on ApiException catch (error) {
                          _snack(error.message);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storage_rounded),
                      title: const Text('Ýerli ýazgylar'),
                      subtitle: Text('${recordings.length} ýazgy telefonda saklanýar'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                      title: const Text('Ýerli maglumatlary poz', style: TextStyle(color: AppTheme.danger)),
                      subtitle: const Text('Serwere iberilen ýazgylar hem pozular (diňe telefonda)'),
                      onTap: () => _confirmDelete(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Serwer'),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          _serverError == null ? Icons.dns_rounded : Icons.error_outline_rounded,
                          color: _serverError == null ? scheme.primary : AppTheme.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppConfig.apiBaseUrl,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: _checking ? null : _checkServer,
                          child: Text(_checking ? '...' : 'Barla'),
                        ),
                      ],
                    ),
                    if (_serverInfo != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(label: Text('Format: ${_serverInfo!['audio_format']?['sample_rate'] ?? 16000} Hz')),
                          Chip(label: Text('Boş ýer: ${_serverInfo!['free_mb'] ?? '?'} MB')),
                          Chip(label: Text('Writable: ${_serverInfo!['writable'] == true ? '✔' : '✖'}')),
                        ],
                      ),
                    ],
                    if (_serverError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _serverError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Programma barada',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppConfig.appName} v${AppConfig.appVersion}\n'
                      'Ses: ${AppConfig.targetSampleRate} Hz · mono · 16 bit WAV\n'
                      'Whisper taýýarlyk maglumatlary awtomatik görnüşde düzülýär.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: () async {
                            await controller.resetOnboarding();
                            if (context.mounted) {
                              _snack('Giriş ekrany täzeden görkeziler.');
                            }
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Tanyşlyk ekranyny täzele'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_status != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(_status!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _consentOption({
    required String value,
    required String selected,
    required String title,
    required String body,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    final isSelected = selected == value;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 1.6 : 1,
          ),
          color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? scheme.primary : scheme.outlineVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTheme(ThemeMode current) async {
    final controller = ref.read(preferencesProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.brightness_auto_rounded),
              title: const Text('Ulgamyň temasyna görä'),
              trailing: current == ThemeMode.system ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                controller.setThemeMode(ThemeMode.system);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode_rounded),
              title: const Text('Ýagty tema'),
              trailing: current == ThemeMode.light ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                controller.setThemeMode(ThemeMode.light);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: const Text('Garaňky tema'),
              trailing: current == ThemeMode.dark ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                controller.setThemeMode(ThemeMode.dark);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ähli ýerli ýazgylary pozmalymy?'),
        content: const Text(
          'Telefondaky ähli ýazgy we ses faýllary pozular. '
          'Serwere iberilen nusgalar öçürilmez (olary admin panelden dolandyryp bolýar).',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ýatyr'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Poz'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(databaseProvider).deleteAllRecordings();
    ref.invalidate(recordingsProvider);
    _snack('Ýerli ýazgylar pozuldy.');
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Ýagty';
      case ThemeMode.dark:
        return 'Garaňky';
      case ThemeMode.system:
        return 'Ulgamyň temasyna görä';
    }
  }
}
