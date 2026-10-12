import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:turkmen_ses/core/network/api_exception.dart';
import 'package:turkmen_ses/core/storage/app_database.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/core/widgets/app_widgets.dart';
import 'package:turkmen_ses/features/session/session.dart';
import 'package:turkmen_ses/features/sync/sync_service.dart';

class RecordingsPage extends ConsumerStatefulWidget {
  const RecordingsPage({super.key});

  @override
  ConsumerState<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends ConsumerState<RecordingsPage> {
  String _filter = 'all';
  String _query = '';

  static const Map<String, String> _filters = <String, String>{
    'all': 'Ählisi',
    'pending': 'Nobatda',
    'uploaded': 'Serwerde',
    'approved': 'Kabul edilen',
    'rejected': 'Ret edilen',
    'failed': 'Şowsuz',
  };

  @override
  Widget build(BuildContext context) {
    final recordings = ref.watch(recordingsProvider);
    final all = recordings.valueOrNull ?? const <Recording>[];
    final filtered = all.where((row) {
      final matchesFilter = _filter == 'all' || row.status == _filter;
      final matchesQuery = _query.isEmpty || row.textValue.toLowerCase().contains(_query.toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();

    final seconds = all.fold<int>(0, (sum, row) => sum + row.durationMs) ~/ 1000;
    final approved = all.where((row) => row.status == 'approved').length;
    final pending = all.where((row) => row.status == 'pending' || row.status == 'failed').length;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: GradientHeader(
            title: 'Ýazgylarym',
            subtitle: '${all.length} ýazgy · $seconds sekunt · $approved kabul edilen',
            trailing: IconButton(
              onPressed: () => ref.read(syncControllerProvider.notifier).run(),
              icon: const Icon(Icons.sync_rounded, color: Colors.white),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: <Widget>[
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tekst boýunça gözle...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters.entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: _filter == entry.key,
                              label: Text(entry.value),
                              onSelected: (_) => setState(() => _filter = entry.key),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        if (recordings.isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.library_music_outlined,
              title: all.isEmpty ? 'Häzir ýazgy ýok' : 'Bu süzgüje gabat gelýän ýazgy ýok',
              message: all.isEmpty
                  ? 'Ýazga bölüminden ilkinji sözlemiňizi ýazga alyň.'
                  : 'Başga süzgüji saýlap görüň.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            sliver: SliverList.separated(
              itemCount: filtered.length + (pending > 0 ? 1 : 0),
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (pending > 0 && index == 0) {
                  return SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.cloud_upload_rounded, color: AppTheme.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$pending ýazgy iberilmäge garaşýar.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.read(syncControllerProvider.notifier).run(),
                          child: const Text('Iber'),
                        ),
                      ],
                    ),
                  );
                }
                final row = filtered[index - (pending > 0 ? 1 : 0)];
                return _recordingTile(context, row);
              },
            ),
          ),
      ],
    );
  }

  Widget _recordingTile(BuildContext context, Recording row) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _showDetail(context, row),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.graphic_eq_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.textValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    StatusChip(status: row.status),
                    const SizedBox(width: 8),
                    Text(
                      '${(row.durationMs / 1000).toStringAsFixed(1)}s',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (row.ratingCount > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded, size: 14, color: AppTheme.accent),
                      Text(
                        ' ${row.qualityScore?.toStringAsFixed(1) ?? '-'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, Recording row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RecordingSheet(
        recording: row,
        onDeleted: () {
          ref.invalidate(recordingsProvider);
        },
      ),
    );
  }
}

class _RecordingSheet extends ConsumerStatefulWidget {
  const _RecordingSheet({required this.recording, required this.onDeleted});

  final Recording recording;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends ConsumerState<_RecordingSheet> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _busy = false;
  Map<String, dynamic>? _remote;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadRemote();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadRemote() async {
    try {
      final data = await ref.read(apiClientProvider).fetchRecording(widget.recording.id);
      if (mounted) {
        setState(() => _remote = data);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      await _player.setFilePath(widget.recording.audioPath);
      await _player.play();
    } catch (_) {
      setState(() => _message = 'Sesi çalyp bolmady.');
    }
    if (mounted) {
      setState(() => _playing = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final database = ref.read(databaseProvider);
    try {
      await ref.read(apiClientProvider).deleteRecording(widget.recording.id);
    } on ApiException {
      // keep going: local delete is what the user asked for
    }
    await database.deleteRecording(widget.recording.id);
    widget.onDeleted();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _retryUpload() async {
    setState(() => _busy = true);
    await ref.read(syncControllerProvider.notifier).run();
    if (mounted) {
      setState(() => _busy = false);
      widget.onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.recording;
    final scheme = Theme.of(context).colorScheme;
    final remoteScore = _remote?['community_score'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(row.textValue, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text('${(row.durationMs / 1000).toStringAsFixed(1)} sekunt')),
              Chip(label: Text(row.category)),
              Chip(label: Text(row.consentType == 'dataset' ? 'Açyk dataset' : 'Içerki')),
              Chip(label: Text('${row.syncAttempts} gezek iberildi')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              StatusChip(status: row.status),
              const Spacer(),
              if (remoteScore != null)
                QualityBadge(
                  score: (remoteScore as num).toDouble(),
                  ratingCount: (_remote?['rating_count'] as num?)?.toInt() ?? 0,
                  verified: _remote?['verified'] == true,
                ),
            ],
          ),
          if (row.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Iň soňky säwlik: ${row.errorMessage}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
            ),
          ],
          if (_message != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_message!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(_playing ? 'Duruz' : 'Diňle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _retryUpload,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Iber'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              label: const Text('Ýazgyny poz', style: TextStyle(color: AppTheme.danger)),
            ),
          ),
        ],
      ),
    );
  }
}
