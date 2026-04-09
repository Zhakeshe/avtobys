import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.atIso,
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final String atIso;
  final String kind;
  final String title;
  final String subtitle;

  Map<String, dynamic> toJson() => {
        'at': atIso,
        'kind': kind,
        'title': title,
        'subtitle': subtitle,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) {
    return HistoryEntry(
      atIso: j['at'] as String? ?? '',
      kind: j['kind'] as String? ?? '',
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String? ?? '',
    );
  }
}

/// Соңғы әрекеттер (іздеу / төлем құрметіне) — локалды.
class ActivityHistory {
  ActivityHistory._();

  static const _key = 'avtobys_activity_history_v1';
  static const _max = 18;

  static Future<void> add({
    required String kind,
    required String title,
    required String subtitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await listEntries();
    final next = [
      HistoryEntry(
        atIso: DateTime.now().toUtc().toIso8601String(),
        kind: kind,
        title: title,
        subtitle: subtitle,
      ),
      ...list,
    ].take(_max).toList();
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<HistoryEntry>> listEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(s);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(HistoryEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
