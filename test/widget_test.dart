import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trading_website/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TradingApp()),
    );

    // Verify app renders without errors.
    expect(find.byType(TradingApp), findsOneWidget);
  });
}
