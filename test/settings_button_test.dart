import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/main.dart';
import 'package:bloop_pop/data/player_state.dart';
import 'package:bloop_pop/game/game_screen.dart';

void main() {
  testWidgets('Settings button appears on HomeScreen and GameScreen with correct styling and functionality', (WidgetTester tester) async {
    // 1. Check HomeScreen
    await tester.pumpWidget(const BloopPopApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Settings button exists on HomeScreen
    final settingsIconFinder = find.byIcon(Icons.settings);
    expect(settingsIconFinder, findsAtLeastNWidgets(1));

    // Tap Settings button on HomeScreen
    await tester.tap(settingsIconFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Settings dialog opens
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Sound FX'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    // Close Settings dialog
    await tester.tap(find.text('CLOSE').first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 2. Check GameScreen
    final player = PlayerState();
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          levelId: 1,
          player: player,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Settings button and Home button both exist on GameScreen
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);

    // Tap Settings button on GameScreen
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Settings dialog opens properly from GameScreen
    expect(find.text('SETTINGS'), findsOneWidget);
  });
}

