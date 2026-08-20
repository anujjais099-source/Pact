abstract final class Validators {
  static final RegExp _username = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? username(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Pick a username';
    if (!_username.hasMatch(s)) return '3-20 letters, numbers or underscores';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(s)) return 'That does not look like an email';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Enter a password';
    if (s.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
      return 'Mix letters and numbers';
    }
    return null;
  }

  static String? goal(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 2) return 'Name your goal';
    if (s.length > 40) return 'Keep it under 40 characters';
    return null;
  }
}
