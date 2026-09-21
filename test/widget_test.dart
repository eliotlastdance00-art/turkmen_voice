import 'package:flutter_test/flutter_test.dart';
import 'package:turkmen_ses/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('home page renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TurkmenSesApp()));
    expect(find.text('Türkmen Ses'), findsOneWidget);
    expect(find.text('Täze ýazgy başlat'), findsOneWidget);
  });
}
