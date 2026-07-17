import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_ai_chat/core/widgets/local_signal.dart';

void main() {
  testWidgets('LocalSignalDot renders without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: LocalSignalDot()),
        ),
      ),
    );

    expect(find.byType(LocalSignalDot), findsOneWidget);

    // Let the pulse animation run a frame to make sure the
    // AnimationController-driven build doesn't throw.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LocalSignalDot), findsOneWidget);
  });

  testWidgets('LocalSignalBadge renders its label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: LocalSignalBadge(label: 'on-device')),
        ),
      ),
    );

    expect(find.text('on-device'), findsOneWidget);
  });
}
