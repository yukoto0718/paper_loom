// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:paper_loom/main.dart';

void main() {
  testWidgets('Paper Loom app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PaperLoomApp());

    // Verify that our app loads with the correct title.
    expect(find.text('Paper Loom'), findsOneWidget);
    expect(find.text('欢迎使用 Paper Loom'), findsOneWidget);

    // Verify that the main buttons are present.
    expect(find.text('打开PDF文件'), findsOneWidget);
    expect(find.textContaining('最近阅读'), findsOneWidget);
  });
}
