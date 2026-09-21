import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});
  @override State<ConsentPage> createState() => _ConsentPageState();
}
class _ConsentPageState extends State<ConsentPage> {
  bool accepted = false;
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Spacer(),
    const Icon(Icons.record_voice_over, size: 64),
    const SizedBox(height: 24),
    Text('Türkmen Ses-e hoş geldiňiz', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    const Text('Siziň ses ýazgylaryňyz Türkmençe speech-to-text modellerini ösdürmek üçin ulanylyp bilner. Ýazgylar ilki lokal saklanýar we siziň razylygyňyz bolmasa serwere iberilmeýär.'),
    const SizedBox(height: 24),
    CheckboxListTile(contentPadding: EdgeInsets.zero, value: accepted, onChanged: (v) => setState(() => accepted = v ?? false), title: const Text('Maglumat ulanyş şertlerine razy'), controlAffinity: ListTileControlAffinity.leading),
    const Spacer(),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: accepted ? () => context.go('/') : null, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Dowam et')))),
  ]))));
}
