import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swimpb_tracker/models/swimmer.dart';
import 'package:swimpb_tracker/widgets/swimmer_header.dart';

void main() {
  testWidgets('SwimmerHeader should render swimmer name and stats', (WidgetTester tester) async {
    final swimmer = Swimmer(
      id: 1,
      firstName: 'Ian',
      surname: 'Hawkins',
      dob: DateTime(2010, 1, 1),
      nationality: 'GB',
      gender: 'Male',
      club: 'Wimbledon SC',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwimmerHeader(
          swimmer: swimmer,
          swimmers: [swimmer],
          meetCount: 5,
          scmCount: 3,
          lcmCount: 2,
          resultCount: 15,
          onSwimmerSelected: (_) {},
          onEdit: () {},
          onAddMeet: () {},
        ),
      ),
    ));

    expect(find.text('Ian Hawkins'), findsOneWidget);
    expect(find.text('15 RACES'), findsOneWidget);
    expect(find.text('3 SCM'), findsOneWidget);
    expect(find.text('2 LCM'), findsOneWidget);
    expect(find.text('Wimbledon SC  •  MALE'), findsOneWidget);
  });

  testWidgets('SwimmerHeader should trigger onEdit when edit button is tapped', (WidgetTester tester) async {
    bool editTapped = false;
    final swimmer = Swimmer(
      firstName: 'Ian', surname: 'Hawkins', dob: DateTime(2010, 1, 1), nationality: 'GB', gender: 'Male'
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwimmerHeader(
          swimmer: swimmer,
          swimmers: [swimmer],
          meetCount: 1,
          scmCount: 1,
          lcmCount: 0,
          resultCount: 5,
          onSwimmerSelected: (_) {},
          onEdit: () => editTapped = true,
          onAddMeet: () {},
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.edit_rounded));
    expect(editTapped, isTrue);
  });
}
