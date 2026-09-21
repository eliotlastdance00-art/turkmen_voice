import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/app_database.dart';

class RecordingsPage extends ConsumerWidget {
  const RecordingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordings = ref.watch(recordingsProvider);
    return SafeArea(child: CustomScrollView(slivers: [
      const SliverAppBar.large(title: Text('Ýazgylarym')),
      recordings.when(
        data: (items) => items.isEmpty
            ? const SliverFillRemaining(child: Center(child: Text('Häzirlikçe ýazgy ýok.')))
            : SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => ListTile(leading: const CircleAvatar(child: Icon(Icons.mic)), title: Text(items[i].textValue), subtitle: Text(items[i].status), trailing: const Icon(Icons.chevron_right))),
        loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SliverFillRemaining(child: Center(child: Text('Ýalňyşlyk: $e'))),
      ),
    ]));
  }
}
