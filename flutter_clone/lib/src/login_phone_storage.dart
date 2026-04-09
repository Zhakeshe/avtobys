import 'package:shared_preferences/shared_preferences.dart';

/// Соңғы логин телефонының 10 цифрасы (PWA / қайта ашқанда толтыру үшін).
class LoginPhoneStorage {
  LoginPhoneStorage._();

  static const _key = 'avtobys_last_login_phone_digits_v1';

  static Future<String?> load10Digits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.length != 10) {
      return null;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(raw)) {
      return null;
    }
    return raw;
  }

  static Future<void> save10Digits(String digits) async {
    final only = digits.replaceAll(RegExp(r'\D'), '');
    if (only.length != 10) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, only);
  }
}
