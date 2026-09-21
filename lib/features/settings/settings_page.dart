import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_database.dart';
import '../recordings/sync_queue.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordings = ref.watch(recordingsProvider).valueOrNull ?? const <Recording>[];
    final pending = recordings.where((item) => item.status == 'pending' || item.status == 'failed').length;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Sazlamalar', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Server sinhronizasiýasy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$pending ýazgy iberilmäge garaşýar.'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: pending == 0 ? null : () => _sync(context, ref),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Serwere iber'),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const ListTile(leading: Icon(Icons.wifi), title: Text('Diňe Wi-Fi arkaly iber'), trailing: Switch(value: true, onChanged: null)),
          const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Razylyk we gizlinlik'), trailing: Icon(Icons.chevron_right)),
          const ListTile(leading: Icon(Icons.delete_outline), title: Text('Ýerli ýazgylary poz'), trailing: Icon(Icons.chevron_right)),
          const SizedBox(height: 20),
          Text('Türkmen Ses v0.1.0', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Ýazgylar serwere iberilýär...')));
    final count = await ref.read(syncQueueProvider).flush();
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('$count ýazgy üstünlikli iberildi')));
  }
}
