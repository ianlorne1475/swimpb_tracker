import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/models/event.dart';
import 'package:swimpb_tracker/models/qualifying_time.dart';
import 'package:swimpb_tracker/widgets/pb_card.dart';

void main() {
  testWidgets('PBCard should render event distance and stroke', (WidgetTester tester) async {
    final event = SwimEvent(
      meetId: 1,
      swimmerId: 1,
      distance: 50,
      stroke: 'Butterfly',
      timeMs: 28450,
      meetTitle: 'Regional Gala',
      date: '2024-03-19',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PBCard(event: event),
      ),
    ));

    expect(find.text('50M BUTTERFLY'), findsOneWidget);
    expect(find.text('28.45'), findsOneWidget);
    expect(find.text('Regional Gala'), findsOneWidget);
  });

  testWidgets('PBCard should show QT badge when metStandards is not empty', (WidgetTester tester) async {
    final event = SwimEvent(
      meetId: 1,
      swimmerId: 1,
      distance: 50,
      stroke: 'Butterfly',
      timeMs: 28450,
    );

    final qt = QualifyingTime(
      standardName: 'SNAG',
      gender: 'Male',
      ageMin: 14,
      ageMax: 14,
      distance: 50,
      stroke: 'Butterfly',
      course: 'SCM',
      timeMs: 30000,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PBCard(event: event, metStandards: [qt]),
      ),
    ));

    expect(find.text('QT'), findsOneWidget);
  });

  testWidgets('PBCard should show delta tag when targetStandard is provided', (WidgetTester tester) async {
    final event = SwimEvent(
      meetId: 1,
      swimmerId: 1,
      distance: 50,
      stroke: 'Butterfly',
      timeMs: 28450,
    );

    final target = QualifyingTime(
      standardName: 'SNAG',
      gender: 'Male',
      ageMin: 14,
      ageMax: 14,
      distance: 50,
      stroke: 'Butterfly',
      course: 'SCM',
      timeMs: 28000, // Swimmer is slower by 0.45s
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PBCard(event: event, targetStandard: target),
      ),
    ));

    expect(find.text('+0.45s'), findsOneWidget);
  });
}
