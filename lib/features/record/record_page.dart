import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/core/widgets/app_widgets.dart';
import 'package:turkmen_ses/features/record/recording_controller.dart';
import 'package:turkmen_ses/features/sentences/sentence_providers.dart';
import 'package:turkmen_ses/features/session/session.dart';

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _saving = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(recorderProvider.notifier);
    final state = ref.read(recorderProvider);
    if (state.isRecording) {
      await recorder.stop();
      await HapticFeedback.mediumImpact();
      return;
    }
    final sentence = await _ensureSentence();
    if (sentence == null) {
      _toast('Sözlem ýüklenmedi. Interneti barlaň ýa-da soňrak synanyşyň.');
      return;
    }
    recorder.prepare(
      sentenceId: sentence.id,
      text: sentence.textValue,
      category: sentence.category,
      packageId: sentence.packageId,
    );
    await recorder.start();
    await HapticFeedback.lightImpact();
  }

  Future<Sentence?> _ensureSentence() async {
    final state = ref.read(recorderProvider);
    final pack = ref.read(selectedPackProvider);
    if (state.text.isEmpty) {
      final sentence = await ref.read(nextSentenceProvider(pack).future);
      if (sentence != null) {
        ref.read(recorderProvider.notifier).prepare(
              sentenceId: sentence.id,
              text: sentence.textValue,
              category: sentence.category,
              packageId: sentence.packageId,
            );
      }
      return sentence;
    }
    final cached = ref.read(localSentencesProvider).valueOrNull ?? const <Sentence>[];
    final match = cached.where((row) => row.id == state.sentenceId).toList();
    return match.isEmpty
        ? Sentence(
            id: state.sentenceId,
            textValue: state.text,
            language: 'tk',
            category: state.category,
            packageId: state.packageId,
            wordCount: state.text.split(' ').length,
            difficulty: 1,
          )
        : match.first;
  }

  Future<void> _play() async {
    final path = ref.read(recorderProvider).path;
    if (path == null) {
      return;
    }
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    await _player.setFilePath(path);
    await _player.play();
    if (mounted) {
      setState(() => _playing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final prefs = ref.read(preferencesProvider);
    final ok = await ref.read(recorderProvider.notifier).save(
          consentType: prefs.consentType,
          serverReachable: session.status != SessionStatus.offline,
          pushImmediately: prefs.autoSync,
        );
    setState(() => _saving = false);
    if (!ok) {
      _toast('Ýazgy saklanmady.');
      return;
    }
    await HapticFeedback.selectionClick();
    _toast('Ýazgy telefonda saklandy. Internet gelende iberiler.');
    ref.invalidate(nextSentenceProvider(ref.read(selectedPackProvider)));
    ref.invalidate(overviewProvider);
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recorderProvider);
    final packs = ref.watch(sentencePacksProvider);
    final selectedPack = ref.watch(selectedPackProvider);
    final scheme = Theme.of(context).colorScheme;

    final progress = (state.elapsedMs / AppConfig.maxRecordingMs).clamp(0, 1).toDouble();
    final nearLimit = state.elapsedMs >= AppConfig.warningMs;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: GradientHeader(
              title: 'Ses ýazga al',
              subtitle: 'Sözlemi arassa we düşnükli okaň',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            sliver: SliverList.list(
              children: <Widget>[
                packs.maybeWhen(
                  data: (items) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _packChip('', 'Ählisi', selectedPack),
                        for (final pack in items) _packChip(pack.id, pack.name, selectedPack),
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                SurfaceCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: <Widget>[
                      Text(
                        'OKALMALY SÖZLEM',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.6,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Text(
                          state.text.isEmpty ? 'Sözlem ýüklenýär...' : state.text,
                          key: ValueKey<String>(state.text),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      LiveWaveform(
                        values: state.amplitudes,
                        height: 64,
                        color: state.isRecording ? AppTheme.danger : scheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${state.seconds.toStringAsFixed(1)} / ${AppConfig.maxRecordingMs / 1000} sekunt',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: nearLimit ? AppTheme.danger : scheme.primary,
                        ),
                      ),
                      if (nearLimit && state.isRecording) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          'Çäk ýetýär — sözlemi tamamlaň.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: PulsingMicButton(
                    recording: state.isRecording,
                    onTap: state.stage == RecorderStage.saving ? () {} : _toggleRecording,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    state.isRecording
                        ? 'Duruzmak üçin basyň'
                        : state.canSave
                            ? 'Diňläň ýa-da täzeden ýazga alyň'
                            : 'Ýazga başlamak üçin mikrofona basyň',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (state.canSave) ...<Widget>[
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _play,
                          icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                          label: Text(_playing ? 'Duruz' : 'Diňle'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _player.stop();
                            setState(() => _playing = false);
                            await ref.read(recorderProvider.notifier).reset();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Täzeden'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'Saklanýar...' : 'Kabul et we sakla'),
                    ),
                  ),
                ],
                if (state.error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
                        const SizedBox(width: 10),
                        Expanded(child: Text(state.error!)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Whisper taýýarlyk maslahatlary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _tip('Mikrofondan 15–20 sm uzaklykda duruň.'),
                      _tip('Gürültili ýerde däl-de, asuda otagda ýazga alyň.'),
                      _tip('Sözlemi adaty tizlikde, düşnükli aýdyň.'),
                      _tip('Sesiňiz 16 kHz mono WAV görnüşinde saklanýar.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _packChip(String value, String label, String selected) {
    final isSelected = value == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => ref.read(selectedPackProvider.notifier).state = value,
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_outline_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
