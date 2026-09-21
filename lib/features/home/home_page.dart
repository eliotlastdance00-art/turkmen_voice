import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/app_database.dart';
import '../recordings/recording_service.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Türkmen Ses'),
            actions: [
              IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(
              children: [
                const _StatusCard(),
                const SizedBox(height: 20),
                Text('Ses ýazga al', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Türkmençe sözlemleri okaň we diliň geljegine goşant goşuň.'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _showRecorder(context),
                  icon: const Icon(Icons.mic),
                  label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Täze ýazgy başlat')),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => context.go('/recordings'), icon: const Icon(Icons.library_music), label: const Text('Ýazgylarymy gör')),
                const SizedBox(height: 28),
                const _InfoCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRecorder(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RecorderSheet(),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(children: [Icon(Icons.cloud_off), SizedBox(width: 14), Expanded(child: Text('Offline režim taýýar. Ýazgylaryňyz ilki telefonda saklanar.'))]),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nähili işleýär?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('1. Sözlemi okaň\n2. Ýazgyny barlaň\n3. Internet gelende serwere iberiň'),
          ]),
        ),
      );
}

class _RecorderSheet extends ConsumerStatefulWidget {
  const _RecorderSheet();
  @override
  ConsumerState<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends ConsumerState<_RecorderSheet> {
  final _recordingService = RecordingService();
  final _player = AudioPlayer();
  Timer? _timer;
  DateTime? _startedAt;
  String? _recordingId;
  String? _audioPath;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _saving = false;
  bool _playing = false;

  @override
  void dispose() {
    _timer?.cancel();
    _recordingService.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    try {
      _recordingId = await _recordingService.start();
      _startedAt = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_startedAt != null && mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
      setState(() => _recording = true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mikrofon elýeterli däl: $error')));
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recordingService.stop();
    if (path == null || _recordingId == null) return;
    setState(() {
      _recording = false;
      _audioPath = path;
    });
  }

  Future<void> _playPreview() async {
    if (_audioPath == null) return;
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    await _player.setFilePath(_audioPath!);
    setState(() => _playing = true);
    await _player.play();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _saveRecording() async {
    if (_audioPath == null || _recordingId == null) return;
    setState(() => _saving = true);
    final database = ref.read(databaseProvider);
    await database.saveRecording(RecordingsCompanion.insert(
      id: _recordingId!,
      sentenceId: 'sentence_demo_001',
      textValue: 'Men şu gün täze kitap okadym.',
      audioPath: _audioPath!,
      durationMs: _elapsed.inMilliseconds,
      status: const drift.Value('pending'),
      consentType: 'dataset',
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ýazgy telefonda saklandy')));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Sözlemi okaň', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 22),
          const Text('Men şu gün täze kitap okadym.', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 22),
          Text(_formatDuration(_elapsed), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Icon(_recording ? Icons.stop_circle : Icons.mic, size: 76, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _saving ? null : _toggleRecording, icon: Icon(_recording ? Icons.stop : Icons.mic), label: Text(_recording ? 'Duruz' : 'Ýazga al')),
          if (_audioPath != null && !_recording) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton.icon(onPressed: _playPreview, icon: Icon(_playing ? Icons.stop : Icons.play_arrow), label: Text(_playing ? 'Duruz' : 'Diňle')),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: _saving ? null : _saveRecording, icon: const Icon(Icons.check), label: const Text('Kabul et')),
            ]),
          ],
        ]),
      );

  String _formatDuration(Duration value) => '${value.inSeconds.toString().padLeft(2, '0')} sek';
}
