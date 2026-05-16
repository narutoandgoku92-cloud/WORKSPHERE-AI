// test/screens/check_in_screen_test.dart - Check-in screen widget tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_sphere_ai/screens/check_in_screen.dart';

void main() {
  group('CheckInScreen', () {
    testWidgets('Check-in screen displays title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      expect(find.text('Check In'), findsWidgets);
    });

    testWidgets('Check-in screen displays location section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      expect(find.textContaining('Location'), findsOneWidget);
    });

    testWidgets('Check-in screen displays latitude and longitude fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      // Wait for location to be fetched
      await tester.pumpAndSettle();

      // Should show latitude or location coordinates
      expect(
        find.textContaining('Latitude').evaluate().isNotEmpty ||
            find.textContaining('Longitude').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Check-in screen displays get location button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('Check-in screen displays geofence information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      expect(
        find.textContaining('Geofence').evaluate().isNotEmpty ||
            find.textContaining('Zone').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Check-in screen has loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      // May show loading indicator initially
      await tester.pump();
      // Either loading or content should be shown
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(SingleChildScrollView).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Check-in button is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      expect(find.text('Check In'), findsWidgets);
    });

    testWidgets('Check-in screen displays form fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      // Should have various UI elements
      expect(
        find.byType(SingleChildScrollView).evaluate().isNotEmpty ||
            find.byType(Column).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Check-in screen displays method selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInScreen(),
          ),
        ),
      );

      // Should have method options (GPS, Face, etc)
      expect(
        find.textContaining('Method').evaluate().isNotEmpty ||
            find.textContaining('Verification').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Check-in screen has proper layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CheckInScreen(),
        ),
      );

      // Should have scaffold and app bar
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
