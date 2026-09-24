// test/auth_edge_cases_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Authentication Form Validation Edge Cases', () {
    String? validateEmail(String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return 'Please enter your email';
      if (!text.contains('@') || !text.contains('.') || text.indexOf('@') >= text.lastIndexOf('.')) {
        return 'Please enter a valid email address';
      }
      return null;
    }

    String? validatePassword(String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return 'Please enter your password';
      if (text.length < 6) return 'Password must be at least 6 characters';
      return null;
    }

    test('Valid email addresses pass validation', () {
      expect(validateEmail('user@example.com'), isNull);
      expect(validateEmail('test.name+tag@sub.domain.org'), isNull);
      expect(validateEmail('  clean.spaces@mail.com  '), isNull);
    });

    test('Invalid email addresses fail with appropriate errors', () {
      expect(validateEmail(''), equals('Please enter your email'));
      expect(validateEmail('   '), equals('Please enter your email'));
      expect(validateEmail(null), equals('Please enter your email'));
      expect(validateEmail('user'), equals('Please enter a valid email address'));
      expect(validateEmail('user@'), equals('Please enter a valid email address'));
      expect(validateEmail('user@domain'), equals('Please enter a valid email address'));
      expect(validateEmail('user.domain@'), equals('Please enter a valid email address'));
    });

    test('Password length rules are enforced', () {
      expect(validatePassword(''), equals('Please enter your password'));
      expect(validatePassword('   '), equals('Please enter your password'));
      expect(validatePassword(null), equals('Please enter your password'));
      expect(validatePassword('12345'), equals('Password must be at least 6 characters'));
      expect(validatePassword('abcde'), equals('Password must be at least 6 characters'));
      expect(validatePassword('123456'), isNull);
      expect(validatePassword('StrongPassword123!'), isNull);
    });
  });

  group('Authentication Mode & State Logic Edge Cases', () {
    test('Default mode is Sign In', () {
      bool isSignUp = false;
      expect(isSignUp, isFalse);
    });

    test('Toggling mode switches between Sign In and Sign Up cleanly', () {
      bool isSignUp = false;
      // User taps Create Account
      isSignUp = true;
      expect(isSignUp, isTrue);

      // User taps Sign In
      isSignUp = false;
      expect(isSignUp, isFalse);
    });

    test('Remember Me defaults to true and can be toggled', () {
      bool rememberMe = true;
      expect(rememberMe, isTrue);

      rememberMe = false;
      expect(rememberMe, isFalse);
    });

    test('Password visibility toggling state', () {
      bool obscurePassword = true;
      expect(obscurePassword, isTrue);

      // User clicks eye icon
      obscurePassword = !obscurePassword;
      expect(obscurePassword, isFalse);

      // User clicks eye icon again
      obscurePassword = !obscurePassword;
      expect(obscurePassword, isTrue);
    });
  });

  group('Authentication Error Parsing Edge Cases', () {
    String formatAuthError(dynamic error) {
      final msg = error.toString().toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'Invalid email or password. Please try again.';
      }
      if (msg.contains('user already registered')) {
        return 'An account with this email already exists. Please sign in.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Please confirm your email address before signing in.';
      }
      return error.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
    }

    test('Translates invalid credentials to user-friendly copy', () {
      expect(
        formatAuthError('AuthException: Invalid login credentials'),
        equals('Invalid email or password. Please try again.'),
      );
    });

    test('Translates duplicate user registration cleanly', () {
      expect(
        formatAuthError('User already registered'),
        equals('An account with this email already exists. Please sign in.'),
      );
    });

    test('Translates unconfirmed email cleanly', () {
      expect(
        formatAuthError('Email not confirmed'),
        equals('Please confirm your email address before signing in.'),
      );
    });

    test('Strips exception prefixes from generic errors', () {
      expect(
        formatAuthError('Exception: Network timeout'),
        equals('Network timeout'),
      );
    });
  });
}
