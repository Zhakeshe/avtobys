import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Соңғы сәтті JSON жауаптарды сақтайды; интернет жоқта қайта оқу.
class OfflineCache {
  OfflineCache._();

  static const _prefix = 'avtobys_cache_v1_';

  static String _busesKey(String cityId, String number, String qrToken) {
    final q = '${number.trim()}_${qrToken.trim()}';
    if (q == '_') {
      return '${_prefix}buses_${cityId}_all';
    }
    return '${_prefix}buses_${cityId}_${q.hashCode}';
  }

  static String _ticketsKey(String phoneKey) =>
      '${_prefix}tickets_${phoneKey.hashCode}';

  static String normalizePhoneKey(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  static Future<void> saveBusList(
    String cityId, {
    String number = '',
    String qrToken = '',
    required List<Map<String, dynamic>> raw,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_busesKey(cityId, number, qrToken), jsonEncode(raw));
    if (number.isEmpty && qrToken.isEmpty && raw.isNotEmpty) {
      await prefs.setString(_busesKey(cityId, '', ''), jsonEncode(raw));
    }
  }

  static Future<List<Map<String, dynamic>>?> loadBusList(
    String cityId, {
    String number = '',
    String qrToken = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _busesKey(cityId, number, qrToken),
      if (number.isNotEmpty || qrToken.isNotEmpty) _busesKey(cityId, '', ''),
    ]) {
      final s = prefs.getString(key);
      if (s == null || s.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(s);
        if (decoded is! List) {
          continue;
        }
        return decoded.whereType<Map<String, dynamic>>().toList();
      } catch (_) {}
    }
    return null;
  }

  static Future<void> saveTicketList(
    String phoneKey,
    List<Map<String, dynamic>> raw,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ticketsKey(phoneKey), jsonEncode(raw));
  }

  static Future<List<Map<String, dynamic>>?> loadTicketList(
    String phoneKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_ticketsKey(phoneKey));
    if (s == null || s.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(s);
      if (decoded is! List) {
        return null;
      }
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return null;
    }
  }
}
