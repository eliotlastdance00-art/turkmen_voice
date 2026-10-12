import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/core/widgets/app_widgets.dart';
import 'package:turkmen_ses/features/session/session.dart';
import 'package:turkmen_ses/features/sync/sync_service.dart';

/// Community quality control: listen to another speaker's take and rate it.
class RatePage extends ConsumerStatefulWidget {
  const RatePage({super.key});

  @override
  ConsumerState<RatePage> createState() => _RatePageState();
}

class _RatePageState extends ConsumerState<RatePage> {
  final AudioPlayer _player = AudioPlayer();
  int _index = 0;
  int _score = 0;
  bool _matchesText = true;
  bool _busy = false;
  bool _playing = false;
  String? _message;
  bool _messageIsError = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _play(String url) async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() {
      _playing = true;
      _message = null;
    });
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {
      setState(() {
        _playing = false;
        _messageIsError = true;
        _message = 'Sesi ýüklemek başartmady (${AppConfig.shortServerLabel}).';
      });
    }
  }

  Future<void> _submit(Map<String, dynamic> item) async {
    if (_score == 0) {
      setState(() {
        _messageIsError = true;
        _message = 'Iň az 1 ýyldyz saýlaň.';
      });
      return;
    }
    setState(() => _busy = true);
    final recordingId = '${item['recording_id']}';
    final api = ref.read(apiClientProvider);
    var points = 0;
    try {
      final result = await api.submitRating(
        recordingId: recordingId,
        score: _score,
        matchesText: _matchesText,
        comment: _commentController.text,
      );
      points = (result['points_awarded'] as num?)?.round() ?? 0;
      setState(() {
        _messageIsError = false;
        _message = 'Sag boluň! +$points ball'
            '${result['auto_approved'] == true ? ' · ýazgy awtomatik tassyklandy' : ''}';
      });
    } on ApiException catch (error) {
      if (error.offline || error.isNetwork) {
        await ref.read(ratingQueueProvider).queue(
              recordingId: recordingId,
              score: _score,
              matchesText: _matchesText,
              comment: _commentController.text,
              remoteText: '${item['text']}',
            );
        setState(() {
          _messageIsError = false;
          _message = 'Internet ýok — bahaňyz nobatda saklandy.';
        });
      } else {
        setState(() {
          _messageIsError = true;
          _message = error.message;
        });
        setState(() => _busy = false);
        return;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _score = 0;
      _matchesText = true;
      _commentController.clear();
      _index++;
    });
    ref.invalidate(ratingQueueProvider(5));
    ref.invalidate(myStatsProvider);
  }

  Future<void> _report(Map<String, dynamic> item) async {
    try {
      await ref.read(apiClientProvider).reportRecording('${item['recording_id']}', reason: 'Hil pes');
      setState(() {
        _messageIsError = false;
        _message = 'Şikaýat iberildi. Sag boluň!';
      });
    } on ApiException catch (error) {
      setState(() {
        _messageIsError = true;
        _message = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(ratingQueueProvider(5));
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(
          child: GradientHeader(
            title: 'Baha ber',
            subtitle: 'Başgalaryň ýazgylaryny diňläp, hilini tassyklaň',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          sliver: SliverToBoxAdapter(
            child: queue.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorView(
                message: error is ApiException
                    ? error.message
                    : 'Nobat ýüklenmedi. Interneti barlaň.',
                onRetry: () => ref.invalidate(ratingQueueProvider(5)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'Häzir barlamaly ýazgy ýok',
                    message: 'Siz ähli elýeterli ýazgylary bahaladyňyz. '
                        'Täze ýazgylar goşulanda şu ýerde peýda bolar.',
                  );
                }
                final item = items[_index % items.length];
                return Column(
                  children: <Widget>[
                    SurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              AvatarCircle(
                                name: '${item['speaker_name'] ?? 'Anonim'}',
                                seed: (item['speaker_avatar_seed'] as num?)?.toInt() ?? 0,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${item['speaker_name'] ?? 'Anonim'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${((item['duration_ms'] as num?)?.toInt() ?? 0) / 1000} sekunt'
                                      ' · ${item['category'] ?? 'general'}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _report(item),
                                icon: const Icon(Icons.flag_outlined, size: 20),
                                tooltip: 'Şikaýat',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${item['text'] ?? ''}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: FilledButton.tonalIcon(
                              onPressed: () => _play('${item['audio_url']}'),
                              icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                              label: Text(_playing ? 'Duruz' : 'Diňle'),
                            ),
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
                            'Sesiň hili',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: StarRating(
                              value: _score,
                              size: 42,
                              onChanged: (value) => setState(() => _score = value),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Aýdylan ses sözleme gabat gelýärmi?',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _verdictButton(
                                  label: 'Gabat gelýär',
                                  icon: Icons.thumb_up_alt_rounded,
                                  selected: _matchesText,
                                  onTap: () => setState(() => _matchesText = true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _verdictButton(
                                  label: 'Gabat gelmeýär',
                                  icon: Icons.thumb_down_alt_rounded,
                                  selected: !_matchesText,
                                  onTap: () => setState(() => _matchesText = false),
                                  danger: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _commentController,
                            maxLines: 2,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              labelText: 'Bellik (islege görä)',
                              hintText: 'Mysal: bir söz nädogry aýdyldy',
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : () => _submit(item),
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(_busy ? 'Iberilýär...' : 'Bahany iber'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_message != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (_messageIsError ? AppTheme.danger : scheme.primary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _message!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _messageIsError ? AppTheme.danger : scheme.primary,
                              ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    SurfaceCard(
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.info_outline_rounded, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Her baha üçin 2 ball, jikme-jik bellikli nädogry tapgyr üçin 3 ball alýarsyňyz. '
                              '3 ýokary baha ýygnan ýazgy awtomatik tassyk edilýär.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _verdictButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? AppTheme.danger : scheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : scheme.outlineVariant, width: selected ? 1.8 : 1),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: selected ? color : scheme.onSurfaceVariant, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? color : scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
