import 'package:fl_clash/features/aloft/account.dart';
import 'package:fl_clash/features/aloft/provider.dart';
import 'package:fl_clash/features/aloft/views.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import 'account_test.dart' show FakePanel, FakeProfiles, MemorySession;

void main() {
  testWidgets('login validates fields and displays errors without exposing password', (tester) async {
    final account = AloftAccount(api: FakePanel(), store: MemorySession(), profiles: FakeProfiles());
    await account.restore();
    await tester.pumpWidget(TestApp(
      locale: const Locale('en'),
      overrides: [aloftAccountProvider.overrideWithValue(account)],
      child: const AloftLoginGate(child: Text('account-home')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Welcome aboard'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'customer@example.invalid');
    await tester.enterText(find.byType(TextFormField).last, 'fixture');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('account-home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    account.dispose();
  });
}
