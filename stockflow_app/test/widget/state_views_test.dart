import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/widgets/state_views.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('State Views Widget Tests', () {
    testWidgets('LoadingView displays CircularProgressIndicator and optional message', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView(message: 'Loading inventory...')));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading inventory...'), findsOneWidget);
    });

    testWidgets('LoadingView displays CircularProgressIndicator without message if omitted', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('ErrorStateView displays error icon, title, message, and fires onRetry', (tester) async {
      bool retryClicked = false;

      await tester.pumpWidget(_wrap(
        ErrorStateView(
          message: 'Failed to reach server. Please check your network.',
          retryText: 'Retry Request',
          onRetry: () {
            retryClicked = true;
          },
        ),
      ));

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Failed to reach server. Please check your network.'), findsOneWidget);
      expect(find.text('Retry Request'), findsOneWidget);

      await tester.tap(find.text('Retry Request'));
      await tester.pump();

      expect(retryClicked, true);
    });

    testWidgets('EmptyStateView displays custom icon, title, subtitle, and fires onAction', (tester) async {
      bool actionClicked = false;

      await tester.pumpWidget(_wrap(
        EmptyStateView(
          icon: Icons.shopping_bag_outlined,
          title: 'No items in cart',
          subtitle: 'Scan a barcode or browse products to add items',
          actionText: 'Browse Catalog',
          onAction: () {
            actionClicked = true;
          },
        ),
      ));

      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      expect(find.text('No items in cart'), findsOneWidget);
      expect(find.text('Scan a barcode or browse products to add items'), findsOneWidget);
      expect(find.text('Browse Catalog'), findsOneWidget);

      await tester.tap(find.text('Browse Catalog'));
      await tester.pump();

      expect(actionClicked, true);
    });
  });
}
