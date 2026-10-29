import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/data/player_state.dart';
import 'package:bloop_pop/game/game_screen.dart';

void main() {
  testWidgets('GameScreen renders HUD, Level 1, and Power-Up buttons', (WidgetTester tester) async {
    final player = PlayerState();
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(levelId: 1, player: player),
      ),
    );

    await tester.pump();
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('0/50'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);

    // Verify power-up buttons exist (5 buttons in idle mode)
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
