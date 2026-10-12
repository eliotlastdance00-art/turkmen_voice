import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/core/widgets/app_widgets.dart';
import 'package:turkmen_ses/features/session/session.dart';
import 'package:turkmen_ses/features/sync/sync_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final stats = session.stats;
    final local = ref.watch(recordingsProvider).valueOrNull ?? const <Recording>[];
    final today = ref.watch(todayActivityProvider).valueOrNull;
    final sync = ref.watch(syncControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    final localSeconds = local.fold<int>(0, (sum, row) => sum + row.durationMs) ~/ 1000;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: GradientHeader(
            title: session.displayName,
            subtitle: '${session.levelName} · ${session.points} ball',
            leading: AvatarCircle(name: session.displayName, seed: session.avatarSeed, radius: 26),
            trailing: IconButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => _EditNameDialog(
                  initial: session.displayName,
                  onSubmit: (value) => ref.read(sessionProvider.notifier).updateDisplayName(value),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          sliver: SliverList.list(
            children: <Widget>[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Derejä ýetmek',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          session.rank == null ? '—' : '${session.rank}. orun',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: session.levelProgress, minHeight: 8),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Icon(Icons.local_fire_department_rounded, color: AppTheme.accent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${session.streakDays} günlük yhlas',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          'Şu gün: ${today?.seconds ?? 0}s / ${AppConfig.dailyGoalSeconds}s',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      label: 'Serwerdäki ýazgy',
                      value: '${stats['recordings'] ?? local.length}',
                      hint: '${stats['approved'] ?? 0} tassyklandy',
                      icon: Icons.mic_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Ses wagty',
                      value: '${stats['seconds'] ?? localSeconds}s',
                      hint: '${(localSeconds / 60).toStringAsFixed(1)} minut',
                      icon: Icons.timer_outlined,
                      color: AppTheme.brandLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      label: 'Berlen baha',
                      value: '${stats['ratings_given'] ?? 0}',
                      hint: 'jemgyýetçilik barlagy',
                      icon: Icons.reviews_rounded,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Alnan baha',
                      value: '${stats['ratings_received'] ?? 0}',
                      hint: stats['avg_quality'] == null ? 'baha ýok' : 'orta ⭐ ${stats['avg_quality']}',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFE7A34E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionTitle('Nyşanlar', subtitle: 'Ýazgylaryňyz köpeldikçe açylýar'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: session.badges.isEmpty
                    ? <Widget>[
                        SurfaceCard(
                          child: Text(
                            'Internet gelende nyşanlar ýüklenýär.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ]
                    : session.badges.map((badge) {
                        final earned = badge['earned'] == true;
                        return Container(
                          width: 108,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: earned
                                ? scheme.primary.withValues(alpha: 0.12)
                                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: earned ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: <Widget>[
                              Icon(
                                _badgeIcon('${badge['icon']}'),
                                color: earned ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${badge['name']}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: earned ? null : scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.library_music_outlined),
                      title: const Text('Ýazgylarym'),
                      subtitle: Text('${local.length} lokal ýazgy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/recordings'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_sync_outlined),
                      title: const Text('Sinhronizasiýa'),
                      subtitle: Text(
                        sync.running
                            ? 'Iberilýär... ${sync.done}/${sync.total}'
                            : sync.lastMessage ?? 'Nobat boş',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => ref.read(syncControllerProvider.notifier).run(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Sazlamalar'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/settings'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hasap barada',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hasabyňyz anonim: diňe şu enjamyň belgisinden döredilýär. '
                      'Şahsy maglumat (at, telefon, e-poçta) ýygnalmaýar.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Serwer: ${AppConfig.shortServerLabel}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => ref.read(sessionProvider.notifier).refresh(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Täzele'),
                        ),
                      ],
                    ),
                    if (session.status == SessionStatus.offline && session.message != null)
                      Text(
                        session.message!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _badgeIcon(String name) {
    switch (name) {
      case 'mic':
        return Icons.mic_rounded;
      case 'library':
        return Icons.library_music_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'timer':
        return Icons.timer_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'graphic_eq':
        return Icons.graphic_eq_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial, required this.onSubmit});

  final String initial;
  final Future<void> Function(String value) onSubmit;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adyňyzy üýtgediň'),
      content: TextField(
        controller: _controller,
        maxLength: 24,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Mysal: Aýna M.'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ýatyr'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  try {
                    await widget.onSubmit(_controller.text);
                  } on ApiException {
                    // offline — stored locally, synced later
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: const Text('Sakla'),
        ),
      ],
    );
  }
}
