import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:turkmen_ses/core/config/app_config.dart';
import 'package:turkmen_ses/core/storage/app_preferences.dart';
import 'package:turkmen_ses/core/theme/app_theme.dart';
import 'package:turkmen_ses/features/session/session.dart';
import 'package:turkmen_ses/features/sentences/sentence_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _step = 0;
  String _consentType = 'dataset';
  bool _saving = false;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      icon: Icons.record_voice_over_rounded,
      title: 'Sesiňiz — dilimiziň geljegi',
      body: 'Türkmençe ses ýazgylaryňyz Whisper ýaly tanadyş modellerini '
          'öwretmek üçin ulanylýar. Her ýazgy dilimiziň sanly mirasyna goşulan goşantdyr.',
    ),
    _Slide(
      icon: Icons.offline_bolt_rounded,
      title: 'Offline işleýär',
      body: 'Internet ýok bolsa-da ýazga alup bilersiňiz. Ýazgylar ilki telefonda '
          'saklanýar, tor gelende öz-özünden serwere iberilýär.',
    ),
    _Slide(
      icon: Icons.workspace_premium_rounded,
      title: 'Ballary ýygnap, bäsleşiň',
      body: 'Gowy ýazgy üçin ball, ýyldyz we dereje alýarsyňyz. Beýleki '
          'ulanyjylaryň ýazgylaryny bahalap, jemgyýetçilik hil süzgüjine kömek ediň.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await ref.read(preferencesProvider.notifier).completeOnboarding(
          displayName: _nameController.text,
          consentType: _consentType,
        );
    // pull the sentence library while we are online
    try {
      await ref.read(sentenceRepositoryProvider).cacheRemoteSentences();
    } catch (_) {
      // offline: the backend seeds the cache on the first successful call
    }
    unawaited(ref.read(sessionProvider.notifier).refresh());
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppConfig.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Geçmek'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length + 1,
                onPageChanged: (index) => setState(() => _step = index),
                itemBuilder: (context, index) {
                  if (index == _slides.length) {
                    return _consentStep(scheme);
                  }
                  return _slideView(_slides[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int index = 0; index <= _slides.length; index++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _step ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _step ? scheme.primary : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (_step < _slides.length) {
                                await _controller.nextPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                                return;
                              }
                              await _finish();
                            },
                      icon: Icon(_step < _slides.length ? Icons.arrow_forward_rounded : Icons.mic_rounded),
                      label: Text(_step < _slides.length ? 'Dowam et' : 'Başlalyň'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideView(_Slide slide) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: AppTheme.brand.withValues(alpha: 0.3), blurRadius: 26, offset: const Offset(0, 12)),
              ],
            ),
            child: Icon(slide.icon, size: 52, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _consentStep(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Razylyk we at',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Sesiňiz nähili ulanylar? Saýlawyňyzy islendik wagt Sazlamalar bölüminden üýtgedip bilersiňiz.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _consentCard(
            value: 'dataset',
            title: 'Açyk dataset üçin',
            body: 'Ses türkmençe STT datasetinde we açyk modelleriň öwredişinde ulanylyp bilner.',
            icon: Icons.public_rounded,
          ),
          const SizedBox(height: 12),
          _consentCard(
            value: 'internal',
            title: 'Diňe içerki taýýarlyk',
            body: 'Ses diňe şu taslamanyň içerki model öwredişinde ulanylar, açyk paýlaşylmaz.',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'Görkeziljek adyňyz (islege görä)',
              hintText: 'Mysal: Meret A.',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          Text(
            'Bellik: hasap anonim — diňe şu enjamyň belgisi bilen baglydyr, '
            'telefon belgisiňiz soralmaýar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _consentCard({
    required String value,
    required String title,
    required String body,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _consentType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _consentType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}
