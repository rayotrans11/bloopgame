import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/data/player_state.dart';
import 'package:bloop_pop/ui/widgets/hud_pills.dart';
import 'package:bloop_pop/ui/widgets/popups.dart';

void main() {
  testWidgets('HudRow displays cash without plus, gems with plus, and big heart with number', (WidgetTester tester) async {
    final player = PlayerState()..cash = 1000..gems = 20..hearts = 10;
    bool gemsClicked = false;
    bool heartsClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HudRow(
            player: player,
            onAddGems: () => gemsClicked = true,
            onAddHearts: () => heartsClicked = true,
          ),
        ),
      ),
    );

    // Cash has text '$1k' but no plus icon next to it
    expect(find.text('\$1k'), findsOneWidget);
    expect(find.text('\$20'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);

    // Tap gems plus
    final plusIcons = find.byIcon(Icons.add);
    expect(plusIcons, findsNWidgets(2)); // Gems plus and Hearts plus (Cash has NO plus)

    await tester.tap(plusIcons.first);
    expect(gemsClicked, isTrue);

    await tester.tap(find.byType(BigHeartPill));
    expect(heartsClicked, isTrue);
  });

  testWidgets('Daily check-in popup adds 15 gems and renders white text with black stroke', (WidgetTester tester) async {
    final player = PlayerState()..gems = 10;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Popups.showDailyCheckIn(context, player),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('DAILY CHECK-IN'), findsOneWidget);
    expect(find.text('+15 GEMS'), findsOneWidget);

    // Verify button with OutlinedButtonText (White fill + Black stroke)
    expect(find.byType(OutlinedButtonText), findsOneWidget);
    expect(find.text('CLAIM (+15 💎)'), findsNWidgets(2)); // Stroke + Fill

    // Tap Claim
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(player.gems, equals(25)); // 10 + 15
  });
}
