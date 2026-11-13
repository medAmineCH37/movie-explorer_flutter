import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movie_explorer/features/subscription_management/domain/models/subscription.dart';
import 'package:movie_explorer/features/subscription_management/presentation/widgets/payment_dialog.dart';

void main() {
  late String? result;
  late bool closed;

  Future<void> openDialog(WidgetTester tester) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: context,
                builder: (_) => const PaymentDialog(
                  plan: SubscriptionPlan.monthly,
                  processingTime: Duration(milliseconds: 10),
                ),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Olfa Habchi',
    String number = '4242424242424242',
    String expiry = '12/30',
    String cvv = '123',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name on card'),
      name,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Card number'),
      number,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expiry'),
      expiry,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'CVV'), cvv);
  }

  testWidgets('shows the plan and price', (tester) async {
    await openDialog(tester);

    expect(find.text('Premium Monthly'), findsOneWidget);
    expect(find.text('Pay 9.99 TND'), findsOneWidget);
  });

  testWidgets('rejects invalid card details', (tester) async {
    await openDialog(tester);
    await fill(tester, number: '1234', expiry: '13/20', cvv: '1');
    await tester.tap(find.text('Pay 9.99 TND'));
    await tester.pumpAndSettle();

    expect(find.text('Card number must have 16 digits'), findsOneWidget);
    expect(find.text('Invalid month'), findsOneWidget);
    expect(find.text('3 digits'), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('rejects an expired card', (tester) async {
    await openDialog(tester);
    await fill(tester, expiry: '01/20');
    await tester.tap(find.text('Pay 9.99 TND'));
    await tester.pumpAndSettle();

    expect(find.text('Card has expired'), findsOneWidget);
  });

  testWidgets('cancel closes without paying', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('valid details return the last four digits', (tester) async {
    await openDialog(tester);
    await fill(tester);
    await tester.tap(find.text('Pay 9.99 TND'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, '4242');
  });
}
