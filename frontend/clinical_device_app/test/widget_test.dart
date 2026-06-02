import 'package:clinical_device_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ClinicalDeviceApp()));
    await tester.pumpAndSettle();

    expect(find.text('Clinical Device Monitor'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
