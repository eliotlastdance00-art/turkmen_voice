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
  final TextEditingController _customController = TextEditingController();
  bool _playing = false;
  bool _saving = false;
  bool _customMode = false;

  /// Türkmen elipbiýi (30 harp) — serwerdäki `TURKMEN_LETTERS` bilen deň.
  static const String _turkmenLetters = 'aäbçdeňfghijžklmnöoprsştuüwýyz';

  /// Serweriň `text_service.validate_transcript` barlagynyň nusgasy
  /// (regex ýerine harp boýunça barlag — ýalňyşlyk az).
  /// Rugsat berilýän nyşanlar (serwerdäki `_PUNCT` bilen deň):
  /// . , ! ? ; : ( ) « » " ' - – —  — kod nokatlary görnüşinde.
  static const List<int> _extraCodeUnits = <int>[
    0x2E, 0x2C, 0x21, 0x3F, 0x3B, 0x3A, 0x28, 0x29,
    0xAB, 0xBB, 0x22, 0x27, 0x2D, 0x2013, 0x2014,
  ];

  static bool _allowedText(String lowered) {
    for (final rune in lowered.runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty) {
        continue; // boşluk / setir aýyryjy
      }
      if (char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39) {
        continue; // san
      }
      if (_turkmenLetters.contains(char) || _extraCodeUnits.contains(rune)) {
        continue;
      }
      return false;
    }
    return true;
  }

  static final RegExp _hasLetter = RegExp('[$_turkmenLetters]');

  /// 15 sekuntda aýdyp boljak tekst ~200 harp; ondan uzyn bolsa duýdurýarys.
  static const int _customSoftLimit = 220;
  static const int _customHardLimit = 300;

  @override
  void dispose() {
    _player.dispose();
    _customController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ text
  static String normalizeText(String raw) {
    var value = raw.replaceAll('\u00a0', ' ').replaceAll('\u200b', '');
    value = value
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('`', "'");
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  String? _customTextProblem(String raw) {
    final text = normalizeText(raw);
    if (text.isEmpty) {
      return 'Öz sözlemiňizi ýazyň — soňra ýazga alyň.';
    }
    if (text.length < 2) {
      return 'Tekst gysga — iň az 2 harp ýazyň.';
    }
    if (text.length > _customHardLimit) {
      return 'Tekst örän uzyn ($_customHardLimit harplyk çäk) — gysgaldyň.';
    }
    final lowered = text.toLowerCase().replaceAll('ý', 'y');
    if (!_allowedText(lowered)) {
      return 'Diňe türkmen harplary, sanlar we adaty nyşanlar ulanylyp bilner.';
    }
    if (!_hasLetter.hasMatch(lowered)) {
      return 'Tekstde türkmen harpy bolmaly.';
    }
    return null;
  }

  bool get _canSwitchMode {
    final state = ref.read(recorderProvider);
    return !state.isRecording && !state.canSave;
  }

  void _setCustomMode(bool value) {
    if (_customMode == value) {
      return;
    }
    if (!_canSwitchMode) {
      _toast('Öň dowam edýän ýazgyny tamamlaň (ýa-da täzeden başlaň).');
      return;
    }
    setState(() => _customMode = value);
    ref.read(recorderProvider.notifier).prepare(
          sentenceId: '',
          text: '',
          category: value ? 'custom' : 'general',
          packageId: value ? 'custom' : ref.read(selectedPackProvider),
        );
    if (!value) {
      // Paket düzgünine dolanyňda täze sözlem alynmaly.
      ref.invalidate(nextSentenceProvider(ref.read(selectedPackProvider)));
    }
  }

  /// Paket saýlananda boş (ýazylmadyk) sözlem alýarys — şol bir sözlem
  /// gaýtadan düşmez ýaly tekst hem täzelenýär.
  void _selectPack(String value) {
    if (ref.read(selectedPackProvider) == value) {
      return;
    }
    ref.read(selectedPackProvider.notifier).state = value;
    ref.invalidate(nextSentenceProvider(value));
    if (_canSwitchMode) {
      ref.read(recorderProvider.notifier).prepare(
            sentenceId: '',
            text: '',
            category: 'general',
            packageId: value,
          );
    }
  }

  // -------------------------------------------------------------- recording
  Future<void> _toggleRecording() async {
    final recorder = ref.read(recorderProvider.notifier);
    final state = ref.read(recorderProvider);
    if (state.isRecording) {
      await recorder.stop();
      await HapticFeedback.mediumImpact();
      return;
    }

    final Sentence sentence;
    if (_customMode) {
      final problem = _customTextProblem(_customController.text);
      if (problem != null) {
        _toast(problem);
        return;
      }
      // Öz sözlemimizi hem goraghana goşýarys — bir tekst iki gezek soralmasyn.
      sentence = await ref.read(sentenceRepositoryProvider).addCustomSentence(
            text: normalizeText(_customController.text),
            category: 'custom',
          );
    } else {
      final next = await _ensureSentence();
      if (next == null) {
        _toast('Bu bölümde ýazylmadyk sözlem galmady. Öz sözlemiňizi ýazyp bilersiňiz.');
        setState(() => _customMode = true);
        return;
      }
      sentence = next;
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
    if (match.isNotEmpty) {
      return match.first;
    }
    return Sentence(
      id: state.sentenceId,
      textValue: state.text,
      language: 'tk',
      category: state.category,
      packageId: state.packageId,
      wordCount: state.text.split(' ').length,
      difficulty: 1,
    );
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
    final wasCustom = _customMode;
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
    if (wasCustom) {
      _customController.clear();
    }
    // Indiki sözlem täze bolmaly: şu ýazylan sözlem gaýtadan soralmaz.
    ref.read(recorderProvider.notifier).prepare(
          sentenceId: '',
          text: '',
          category: wasCustom ? 'custom' : ref.read(recorderProvider).category,
          packageId: wasCustom ? 'custom' : ref.read(recorderProvider).packageId,
        );
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

  void _showTextSourceInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tekstler nireden gelýär?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            _InfoLine('6 paket / 215 sözlem serweriň başlangyç bazasynda dur (backend/app/seed).'),
            _InfoLine('Programmanyň içinde şol bazanyň nusgasy bar — internet ýok bolsa-da ýazga alyp bilersiňiz.'),
            _InfoLine('Internet gelende sözlemler serwerden awtomatik täzelenýär.'),
            _InfoLine('"Öz sözlemim" düzgüninde teksti özüňiz ýazýarsyňyz — ol hem dataset üçin ulanylýar.'),
            _InfoLine('Bir sözlem (tekst) bir gezek ýazylýar: gaýtadan soralmaýar.'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Düşündim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recorderProvider);
    final packs = ref.watch(sentencePacksProvider);
    final selectedPack = ref.watch(selectedPackProvider);
    final nextSentence = ref.watch(nextSentenceProvider(selectedPack));
    final scheme = Theme.of(context).colorScheme;

    // Täze sözlem taýýar bolanda (ýazgy saklanandan soň) ony awtomatik goýýarys:
    // şeýlelikde şol bir sözlem ikinji gezek soralmaýar.
    ref.listen<AsyncValue<Sentence?>>(nextSentenceProvider(selectedPack), (previous, next) {
      final sentence = next.valueOrNull;
      if (sentence == null || _customMode) {
        return;
      }
      final current = ref.read(recorderProvider);
      if (current.text.isNotEmpty || current.isRecording || current.canSave) {
        return;
      }
      ref.read(recorderProvider.notifier).prepare(
            sentenceId: sentence.id,
            text: sentence.textValue,
            category: sentence.category,
            packageId: sentence.packageId,
          );
    });

    final progress = (state.elapsedMs / AppConfig.maxRecordingMs).clamp(0, 1).toDouble();
    final nearLimit = state.elapsedMs >= AppConfig.warningMs;
    final customText = normalizeText(_customController.text);
    final customProblem = customText.isEmpty ? null : _customTextProblem(customText);
    final customTooLong = customText.length > _customSoftLimit;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: GradientHeader(
              title: 'Ses ýazga al',
              subtitle: 'Sözlemi arassa we düşnükli okaň',
              trailing: IconButton(
                onPressed: _showTextSourceInfo,
                tooltip: 'Tekstler nireden gelýär?',
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            sliver: SliverList.list(
              children: <Widget>[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Paketden'),
                      icon: Icon(Icons.menu_book_rounded),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Öz sözlemim'),
                      icon: Icon(Icons.edit_note_rounded),
                    ),
                  ],
                  selected: <bool>{_customMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => _setCustomMode(selection.first),
                ),
                const SizedBox(height: 14),
                if (!_customMode)
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
                if (!_customMode) const SizedBox(height: 16),
                SurfaceCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: <Widget>[
                      Text(
                        _customMode ? 'ÖZ SÖZLEMIM' : 'OKALMALY SÖZLEM',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.6,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 14),
                      if (_customMode)
                        TextField(
                          controller: _customController,
                          maxLines: 3,
                          minLines: 2,
                          maxLength: _customHardLimit,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          enabled: !state.isRecording && !state.canSave,
                          decoration: InputDecoration(
                            hintText: 'Meselem: Men ertir ir bilen işe gidýärin.',
                            helperText: customProblem ?? 'Ýazgy gutarandan soň tekst goraghana goşular.',
                            helperStyle: TextStyle(
                              color: customProblem == null ? scheme.onSurfaceVariant : AppTheme.danger,
                            ),
                            errorText: customProblem,
                          ),
                        )
                      else
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: Text(
                            state.text.isEmpty ? _emptySentenceLabel(nextSentence) : state.text,
                            key: ValueKey<String>(state.text),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_customMode && customTooLong) ...<Widget>[
                        Text(
                          'Tekst uzyn — 15 sekuntda okap ýetişmegiňiz kyn bolup biler.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _sourceChip(state, packs.valueOrNull ?? const <SentencePack>[]),
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
                      _tip('Her tekst diňe bir gezek ýazylýar — sanaw awtomatik täzelenýär.'),
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

  String _emptySentenceLabel(AsyncValue<Sentence?> next) {
    if (next.isLoading) {
      return 'Sözlem taýýarlanýar...';
    }
    if (next.hasValue && next.value == null) {
      return 'Bu bölümde ýazylmadyk sözlem galmady — "Öz sözlemim" düzgünini saýlaň.';
    }
    return 'Sözlem taýýarlanýar...';
  }

  /// Sözlemiň çeşmesi: paket ady ýa-da "öz sözlemim".
  Widget _sourceChip(RecorderState state, List<SentencePack> packs) {
    final scheme = Theme.of(context).colorScheme;
    final isCustom = _customMode || state.packageId == 'custom' || state.category == 'custom';
    String label;
    if (isCustom) {
      label = 'Çeşme: ${SentenceOrigin.custom.label}';
    } else if (state.text.isEmpty) {
      label = 'Çeşme: paket sözlemleri';
    } else {
      final match = packs.where((pack) => pack.id == state.packageId).toList();
      final packName = match.isNotEmpty
          ? match.first.name
          : (kCategoryLabels[state.category] ?? 'Sözlem goraghanasy');
      label = 'Çeşme: $packName';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          isCustom ? Icons.edit_note_rounded : Icons.library_books_rounded,
          size: 15,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _packChip(String value, String label, String selected) {
    final isSelected = value == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => _selectPack(value),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.circle, size: 7),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
