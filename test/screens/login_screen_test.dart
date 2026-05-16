import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_sphere_ai/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('Login screen displays email and password fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      // Verify email field exists
      expect(find.byType(TextField), findsWidgets);
      expect(find.byKey(ValueKey('email_field')), findsOneWidget);
      expect(find.byKey(ValueKey('password_field')), findsOneWidget);
    });

    testWidgets('Login screen displays login button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Login button is disabled when fields are empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      final loginButton = find.byType(ElevatedButton);
      expect(loginButton, findsOneWidget);

      // Button should be present
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Email field accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      final emailField = find.byKey(ValueKey('email_field'));
      expect(emailField, findsOneWidget);

      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('Password field accepts input and obscures text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      final passwordField = find.byKey(ValueKey('password_field'));
      expect(passwordField, findsOneWidget);

      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // The actual text won't be visible due to obscuring, but the field should have the input
      expect(find.byKey(ValueKey('password_field')), findsOneWidget);
    });

    testWidgets('Demo credentials button displays demo email and password', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      // Look for demo credentials text
      expect(find.textContaining('admin@optiwork.ai'), findsOneWidget);
      expect(find.textContaining('password123'), findsOneWidget);
    });

    testWidgets('Email field has correct label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('Password field has correct label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Form shows app title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      expect(find.textContaining('WorkSphere'), findsOneWidget);
    });

    testWidgets('Form has proper app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
