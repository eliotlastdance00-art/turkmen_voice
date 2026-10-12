import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/core/widgets/app_widgets.dart';
import 'package:turkmen_ses/features/session/session.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  String _period = 'all';

  static const Map<String, String> _periods = <String, String>{
    'all': 'Hemme wagt',
    'month': 'Şu aý',
    'week': 'Şu hepde',
  };

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(leaderboardProvider(_period));
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(
          child: GradientHeader(
            title: 'Reyting',
            subtitle: 'Iň işjeň gürleýjiler we barlaýjylar',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          sliver: SliverList.list(
            children: <Widget>[
              Row(
                children: _periods.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _period == entry.key,
                          label: Text(entry.value),
                          onSelected: (_) => setState(() => _period = entry.key),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Row(
                  children: <Widget>[
                    AvatarCircle(name: session.displayName, seed: session.avatarSeed, radius: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            session.isReady ? session.displayName : 'Myhman',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${session.levelName} · ${session.points} ball'
                            '${session.rank == null ? '' : ' · ${session.rank}. orun'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.brandLight.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        session.rank == null ? '—' : '#${session.rank}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              board.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ErrorView(
                  message: error is ApiException ? error.message : 'Reyting ýüklenmedi.',
                  onRetry: () => ref.invalidate(leaderboardProvider(_period)),
                ),
                data: (data) {
                  final entries = (data['entries'] as List? ?? <dynamic>[])
                      .whereType<Map>()
                      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
                      .toList();
                  final levels = (data['levels'] as List? ?? <dynamic>[])
                      .whereType<Map>()
                      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
                      .toList();
                  if (entries.isEmpty) {
                    return const EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'Reyting boş',
                      message: 'Ilkinji ýazgylary ýükleseňiz, şu ýerde görüner.',
                    );
                  }
                  return Column(
                    children: <Widget>[
                      ...entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _entryTile(context, entry),
                          )),
                      const SizedBox(height: 8),
                      SectionTitle('Derejeler', subtitle: 'Ballaryňyza görä derejeňiz ösýär'),
                      SurfaceCard(
                        child: Column(
                          children: levels
                              .map(
                                (level) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.military_tech_rounded,
                                        size: 18,
                                        color: (level['index'] as num?)?.toInt() == session.levelProgress * 5
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text('${level['name']}')),
                                      Text(
                                        '${level['min_points']} ball',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entryTile(BuildContext context, Map<String, dynamic> entry) {
    final scheme = Theme.of(context).colorScheme;
    final isMe = entry['is_me'] == true;
    final rank = (entry['rank'] as num?)?.toInt() ?? 0;
    final medal = switch (rank) {
      1 => const Color(0xFFF1C40F),
      2 => const Color(0xFFBFC9CA),
      3 => const Color(0xFFCD7F32),
      _ => Colors.transparent,
    };
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          border: isMe ? Border.all(color: scheme.primary, width: 1.4) : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: medal == Colors.transparent ? scheme.onSurfaceVariant : medal,
                    ),
              ),
            ),
            const SizedBox(width: 6),
            AvatarCircle(
              name: '${entry['display_name'] ?? 'Anonim'}',
              seed: (entry['avatar_seed'] as num?)?.toInt() ?? 0,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '${entry['display_name'] ?? 'Anonim'}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isMe)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'siz',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: scheme.primary),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry['level_name'] ?? ''} · ${entry['recordings'] ?? 0} ýazgy'
                    '${entry['avg_score'] == null ? '' : ' · ⭐ ${entry['avg_score']}'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${entry['points'] ?? 0}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'ball',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
