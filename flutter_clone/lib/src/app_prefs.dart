import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_strings.dart';

/// Тіл, мәтін өлшемі және басқа қалпы.
class AppPrefsController extends ChangeNotifier {
  AppPrefsController();

  static const _langKey = 'app_language_code';
  static const _scaleKey = 'app_text_scale_bucket';

  AppLanguage _language = AppLanguage.kk;
  double _textScale = 1.0;

  AppLanguage get language => _language;
  AppStrings get strings => AppStrings(_language);
  double get textScale => _textScale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = AppLanguageCode.parse(prefs.getString(_langKey));
    if (lang != null) {
      _language = lang;
    }
    final bucket = prefs.getString(_scaleKey);
    _textScale = switch (bucket) {
      'large' => 1.15,
      'xlarge' => 1.3,
      _ => 1.0,
    };
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    _language = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, value.code);
  }

  Future<void> setTextScaleBucket(String bucket) async {
    _textScale = switch (bucket) {
      'large' => 1.15,
      'xlarge' => 1.3,
      _ => 1.0,
    };
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scaleKey, bucket);
  }

  String get textScaleBucket => switch (_textScale) {
        >= 1.29 => 'xlarge',
        >= 1.1 => 'large',
        _ => 'normal',
      };
}
