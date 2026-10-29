import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/main.dart';
import 'package:bloop_pop/ui/widgets/hud_pills.dart';

void main() {
  testWidgets('BloopPop smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BloopPopApp());
    expect(find.byType(GameButton3D), findsOneWidget);
    expect(find.text('START'), findsNWidgets(2)); // Stroke + Fill
    expect(find.text('LEVEL 1'), findsOneWidget);
  });
}
