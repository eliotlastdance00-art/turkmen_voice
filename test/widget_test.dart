import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turkmen_ses/core/widgets/app_widgets.dart';

void main() {
  testWidgets('star rating reports the tapped value', (WidgetTester tester) async {
    var value = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => StarRating(
              value: value,
              onChanged: (int next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await tester.pump();
    expect(value, 4);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
  });

  testWidgets('status chip shows the Turkmen label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusChip(status: 'approved')),
      ),
    );
    expect(find.text('Kabul edildi'), findsOneWidget);
  });

  testWidgets('avatar circle falls back to initials', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AvatarCircle(name: 'Aýna Meret', seed: 2)),
      ),
    );
    expect(find.text('AM'), findsOneWidget);
  });
}
