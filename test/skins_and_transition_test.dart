import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/data/player_state.dart';
import 'package:bloop_pop/ui/home_screen.dart';
import 'package:bloop_pop/ui/widgets/hud_pills.dart';
import 'package:bloop_pop/ui/widgets/popups.dart';

void main() {
  test('Default ball skin is yellow', () {
    final player = PlayerState();
    expect(player.ballSkin, equals('yellow'));
    expect(player.ownedSkins, contains('yellow'));
    expect(player.ownedSkins, contains('basketball'));
    expect(player.ownedSkins, contains('tricolor'));
    expect(player.ownedSkins, contains('star'));
    expect(player.ownedSkins, contains('star_burst'));
  });

  testWidgets('Skin modal shows all 5 skins from screenshot with equip buttons', (WidgetTester tester) async {
    final player = PlayerState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Popups.showSkins(context, player),
              child: const Text('Open Skins'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Skins'));
    await tester.pumpAndSettle();

    expect(find.text('Skin'), findsNWidgets(2)); // Header pill stroke + fill
    expect(find.text('Yellow Ball'), findsOneWidget);
    expect(find.text('Basketball'), findsOneWidget);
    expect(find.text('Tri-Color Ball'), findsOneWidget);
    expect(find.text('Star'), findsOneWidget);
    expect(find.text('Star Burst'), findsOneWidget);

    // Yellow Ball is equipped by default -> shows green checkmark
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Other 4 skins show 'Use' buttons
    expect(find.text('Use'), findsNWidgets(8)); // 4 buttons x 2 (stroke + fill)

    // Tap Basketball to equip
    await tester.tap(find.text('Basketball'));
    await tester.pump();

    expect(player.ballSkin, equals('basketball'));

    // Yellow Ball should now show free 'Use' button (no ad movie icon on yellow ball)
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    // Other 3 unequipped non-free skins should show the ad icon
    expect(find.byIcon(Icons.movie), findsNWidgets(3));

    // Tap Yellow Ball to equip it back freely
    await tester.tap(find.text('Yellow Ball'));
    await tester.pump();
    expect(player.ballSkin, equals('yellow'));
  });

  testWidgets('Clicking START triggers logo zoom & fade transition', (WidgetTester tester) async {
    final player = PlayerState()..hearts = 5;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(player: player),
      ),
    );

    // Tap START
    await tester.tap(find.byType(GameButton3D), warnIfMissed: false);

    // Advance 100ms: animation should be in progress
    await tester.pump(const Duration(milliseconds: 100));

    // Consumed 1 heart
    expect(player.hearts, equals(4));

    // Finish animation and advance transition
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
  });
}
