import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WalletCardData {
  const WalletCardData({
    required this.id,
    required this.holderName,
    required this.number,
  });

  final String id;
  final String holderName;
  final String number;

  String get lastFour => number.length >= 4 ? number.substring(number.length - 4) : number;

  String get maskedNumber => '•••• $lastFour';

  Map<String, dynamic> toJson() => {
    'id': id,
    'holderName': holderName,
    'number': number,
  };

  factory WalletCardData.fromJson(Map<String, dynamic> json) {
    return WalletCardData(
      id: json['id'] as String? ?? '',
      holderName: json['holderName'] as String? ?? 'Моя карта',
      number: json['number'] as String? ?? '',
    );
  }
}

class WalletState {
  const WalletState({
    required this.balance,
    required this.cards,
    this.activeCardId,
  });

  final double balance;
  final List<WalletCardData> cards;
  final String? activeCardId;

  factory WalletState.empty() => const WalletState(balance: 0, cards: []);

  WalletCardData? get activeCard {
    if (cards.isEmpty) {
      return null;
    }

    for (final card in cards) {
      if (card.id == activeCardId) {
        return card;
      }
    }

    return cards.first;
  }

  WalletState copyWith({
    double? balance,
    List<WalletCardData>? cards,
    String? activeCardId,
    bool clearActiveCard = false,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      cards: cards ?? this.cards,
      activeCardId: clearActiveCard ? null : (activeCardId ?? this.activeCardId),
    );
  }

  Map<String, dynamic> toJson() => {
    'balance': balance,
    'activeCardId': activeCardId,
    'cards': cards.map((card) => card.toJson()).toList(),
  };

  factory WalletState.fromJson(Map<String, dynamic> json) {
    final cards = ((json['cards'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>())
        .map(WalletCardData.fromJson)
        .toList();

    return WalletState(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      activeCardId: json['activeCardId'] as String?,
      cards: cards,
    );
  }
}

class WalletStore {
  static String _keyForPhone(String phoneNumber) {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return 'wallet_state_$normalized';
  }

  static Future<WalletState> load(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      return WalletState.empty();
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_keyForPhone(phoneNumber));

    if (raw == null || raw.isEmpty) {
      return WalletState.empty();
    }

    try {
      return WalletState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return WalletState.empty();
    }
  }

  static Future<void> save(String phoneNumber, WalletState state) async {
    if (phoneNumber.isEmpty) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_keyForPhone(phoneNumber), jsonEncode(state.toJson()));
  }
}

String normalizeCardNumber(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String formatBalance(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}
