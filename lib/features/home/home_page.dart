import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/core/widgets/app_widgets.dart';
import 'package:turkmen_ses/features/session/session.dart';
import 'package:turkmen_ses/features/sync/sync_service.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    final session = ref.watch(sessionProvider);
    final today = ref.watch(todayActivityProvider).valueOrNull;
    final recordings = ref.watch(recordingsProvider).valueOrNull ?? const <Recording>[];
    final sync = ref.watch(syncControllerProvider);
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;

    final todaySeconds = today?.seconds ?? 0;
    final goal = AppConfig.dailyGoalSeconds;
    final pending = recordings.where((row) => row.status == 'pending' || row.status == 'failed').length;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: GradientHeader(
            title: _greeting(session.displayName),
            subtitle: '${session.levelName} · ${session.points} ball'
                '${session.rank == null ? '' : ' · ${session.rank}. orun'}',
            leading: AvatarCircle(name: session.displayName, seed: session.avatarSeed, radius: 24),
            trailing: IconButton(
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          sliver: SliverList.list(
            children: <Widget>[
              ServerStatusBanner(
                online: online && session.status != SessionStatus.offline,
                message: session.status == SessionStatus.offline
                    ? 'Serwer elýeterli däl (${AppConfig.shortServerLabel}). Ýazgylar telefonda saklanýar.'
                    : null,
                onTap: () => ref.read(sessionProvider.notifier).refresh(),
              ),
              const SizedBox(height: 18),
              SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Şu günki maksat',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                todaySeconds >= goal
                                    ? 'Maksat ýerine ýetirildi! Şeýle dowam ediň.'
                                    : 'Ýene ${((goal - todaySeconds) / 60).ceil()} minut ses gerek.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  Chip(
                                    avatar: const Icon(Icons.mic_rounded, size: 16),
                                    label: Text('Şu gün: ${today?.recordings ?? 0} ýazgy'),
                                  ),
                                  if (pending > 0)
                                    Chip(
                                      avatar: const Icon(Icons.cloud_upload_rounded, size: 16),
                                      label: Text('$pending nobatda'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GoalRing(
                          size: 132,
                          progress: goal == 0 ? 0 : todaySeconds / goal,
                          centerTitle: '${todaySeconds}s',
                          centerSubtitle: 'maksat ${goal ~/ 60} min',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.go('/record'),
                            icon: const Icon(Icons.mic_rounded),
                            label: const Text('Ses ýazga al'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: sync.running ? null : () => ref.read(syncControllerProvider.notifier).run(),
                          icon: sync.running
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Icon(Icons.sync_rounded),
                          tooltip: 'Nobaty iber',
                        ),
                      ],
                    ),
                    if (sync.running) ...<Widget>[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: sync.fraction == 0 ? null : sync.fraction),
                    ],
                    if (!sync.running && sync.lastMessage != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        sync.lastMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SectionTitle(
                'Toplum görkezijileri',
                subtitle: online ? 'Serwer maglumatlary' : 'Iň soňky maglumatlar',
                action: IconButton(
                  onPressed: () => ref.invalidate(overviewProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
              overview.when(
                data: (data) => _overviewGrid(context, data),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SurfaceCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_off_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Görkezijiler ýüklenmedi. Internet gelende täzeden synanyşyň.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(overviewProvider),
                        child: const Text('Täzele'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Nähili işleýär?', subtitle: 'Üç ädimde goşant goşuň'),
              SurfaceCard(
                child: Column(
                  children: <Widget>[
                    _stepRow(context, 1, 'Sözlemi okaň', 'Ekranda görkezilen sözlemi aýdyň. 15 sekuntdan köp bolmaly däl.'),
                    const Divider(height: 26),
                    _stepRow(context, 2, 'Barlap, kabul ediň', 'Diňläň, ýalňyş bar bolsa täzeden ýazga alyň.'),
                    const Divider(height: 26),
                    _stepRow(context, 3, 'Ballaryňyzy ýygyň', 'Her tassyklanan ýazgy üçin ball we dereje alýarsyňyz.'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SectionTitle(
                'Iň soňky ýazgylarym',
                action: TextButton(
                  onPressed: () => context.go('/recordings'),
                  child: const Text('Ählisi'),
                ),
              ),
              if (recordings.isEmpty)
                const SurfaceCard(
                  child: EmptyState(
                    icon: Icons.mic_none_rounded,
                    title: 'Häzir ýazgy ýok',
                    message: 'Ilkinji sözlemiňizi ýazga alyň we ballary ýygnap başlaň.',
                  ),
                )
              else
                Column(
                  children: recordings
                      .take(3)
                      .map((row) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SurfaceCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.graphic_eq_rounded, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          row.textValue,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${(row.durationMs / 1000).toStringAsFixed(1)} sekunt · '
                                          '${row.category}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusChip(status: row.status),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overviewGrid(BuildContext context, Map<String, dynamic> data) {
    final hours = (data['hours_total'] as num?)?.toDouble() ?? 0;
    final recordings = (data['recordings_total'] as num?)?.round() ?? 0;
    final contributors = (data['contributors'] as num?)?.round() ?? 0;
    final ratings = (data['ratings_total'] as num?)?.round() ?? 0;
    final approved = (data['approved'] as num?)?.round() ?? 0;
    final quality = data['avg_quality'];
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Jemi ses',
                value: '${hours.toStringAsFixed(2)} sag',
                hint: '$recordings ýazgy',
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Gürleýjiler',
                value: '$contributors',
                hint: '$approved tassyklandy',
                icon: Icons.groups_rounded,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Berialan baha',
                value: '$ratings',
                hint: 'jemgyýetçilik barlagy',
                icon: Icons.reviews_rounded,
                color: AppTheme.brandLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Orta hillilik',
                value: quality == null ? '—' : '$quality',
                hint: '5 ýyldyz sistemasy',
                icon: Icons.star_rounded,
                color: const Color(0xFFE7A34E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepRow(BuildContext context, int number, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$number', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
        ),
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
      ],
    );
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return 'Gijäňiz rahat, $name';
    }
    if (hour < 12) {
      return 'Ertiriňiz haýyrly, $name';
    }
    if (hour < 18) {
      return 'Günüňiz haýyrly, $name';
    }
    return 'Agşamyňyz haýyrly, $name';
  }
}
