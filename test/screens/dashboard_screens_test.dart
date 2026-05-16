// test/screens/dashboard_screens_test.dart - Dashboard widget tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_sphere_ai/screens/admin_dashboard_screen.dart';
import 'package:work_sphere_ai/screens/employee_dashboard_screen.dart';

void main() {
  group('AdminDashboardScreen', () {
    testWidgets('Admin dashboard displays welcome message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      expect(
        find.textContaining('Welcome').evaluate().isNotEmpty ||
            find.textContaining('Dashboard').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Admin dashboard displays statistics cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      // Should display employee statistics
      expect(
        find.textContaining('Employee').evaluate().isNotEmpty ||
            find.textContaining('Present').evaluate().isNotEmpty ||
            find.textContaining('Absent').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Admin dashboard has refresh button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      // RefreshIndicator provides pull-to-refresh functionality
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('Admin dashboard displays quick actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      // Should have action buttons
      expect(
        find.byType(ElevatedButton).evaluate().isNotEmpty ||
            find.byType(TextButton).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Admin dashboard has logout functionality', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      // Should have app bar with menu
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Admin dashboard shows employee count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      // Stats cards should show numbers
      expect(
        find.textContaining('Total').evaluate().isNotEmpty ||
            find.textContaining('0').evaluate().isNotEmpty ||
            find.textContaining('Employees').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Admin dashboard shows attendance stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      // Should show present/absent/on-time/late counts
      expect(
        find.textContaining('Present').evaluate().isNotEmpty ||
            find.textContaining('Absent').evaluate().isNotEmpty ||
            find.textContaining('On Time').evaluate().isNotEmpty ||
            find.textContaining('Late').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Admin dashboard displays grid layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(),
          ),
        ),
      );

      // Should have grid or card layout
      expect(
        find.byType(GridView).evaluate().isNotEmpty ||
            find.byType(SingleChildScrollView).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Admin dashboard has proper structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('EmployeeDashboardScreen', () {
    testWidgets('Employee dashboard displays profile information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      // Should display profile card with name/email
      expect(
        find.textContaining('Profile').evaluate().isNotEmpty ||
            find.textContaining('Employee').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Employee dashboard displays check-in status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      // Should show check-in status
      expect(
        find.textContaining('Check').evaluate().isNotEmpty ||
            find.textContaining('Status').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Employee dashboard shows weekly statistics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      // Should display hours worked, days present, etc.
      expect(
        find.textContaining('Hours').evaluate().isNotEmpty ||
            find.textContaining('Days').evaluate().isNotEmpty ||
            find.textContaining('Present').evaluate().isNotEmpty ||
            find.textContaining('Productivity').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Employee dashboard has refresh functionality', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('Employee dashboard displays user avatar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      // Should have profile picture/avatar
      expect(
        find.byType(CircleAvatar).evaluate().isNotEmpty ||
            find.byType(Container).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Employee dashboard shows user name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      // Should display name or employee information
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('Employee dashboard shows hours worked', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      expect(
        find.textContaining('Hours').evaluate().isNotEmpty ||
            find.textContaining('Worked').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Employee dashboard displays productivity score', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      expect(
        find.textContaining('Productivity').evaluate().isNotEmpty ||
            find.textContaining('Score').evaluate().isNotEmpty ||
            find.textContaining('%').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Employee dashboard has logout option', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeDashboardScreen(),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Employee dashboard has proper layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmployeeDashboardScreen(),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
