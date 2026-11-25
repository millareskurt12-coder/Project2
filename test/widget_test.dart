import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:findit/main.dart';

void main() {
  testWidgets('welcome screen opens the sign-in flow', (tester) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(home: WelcomePage(onStart: () => started = true)),
    );

    expect(find.text('Lost Something?\nFind It Here.'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    expect(started, isTrue);
  });
}
