class WalletCardData {
  const WalletCardData({
    required this.id,
    required this.holderName,
    required this.number,
    required this.cardType,
    this.balance = 0,
    this.addedAt,
  });

  final String id;
  final String holderName;
  final String number;
  final String cardType;
  final double balance;
  final DateTime? addedAt;

  bool get isTransport => cardType == 'transport';

  String get lastFour =>
      number.length >= 4 ? number.substring(number.length - 4) : number;

  String get maskedNumber => '•••• $lastFour';

  factory WalletCardData.fromJson(Map<String, dynamic> json) {
    return WalletCardData(
      id: json['id'] as String? ?? '',
      holderName: json['holderName'] as String? ?? 'Моя карта',
      number: json['number'] as String? ?? '',
      cardType: json['cardType'] as String? ?? 'bank',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'holderName': holderName,
        'number': number,
        'cardType': cardType,
        'balance': balance,
        'addedAt': addedAt?.toIso8601String(),
      };
}

class WalletTransactionData {
  const WalletTransactionData({
    required this.id,
    required this.type,
    required this.source,
    required this.description,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String source;
  final String description;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime createdAt;

  factory WalletTransactionData.fromJson(Map<String, dynamic> json) {
    return WalletTransactionData(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      source: json['source'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class WalletState {
  const WalletState({
    required this.balance,
    required this.cards,
    required this.transactions,
    this.activeCardId,
  });

  final double balance;
  final List<WalletCardData> cards;
  final List<WalletTransactionData> transactions;
  final String? activeCardId;

  const WalletState.empty()
      : balance = 0,
        cards = const [],
        transactions = const [],
        activeCardId = null;

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
    List<WalletTransactionData>? transactions,
    String? activeCardId,
    bool clearActiveCard = false,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      cards: cards ?? this.cards,
      transactions: transactions ?? this.transactions,
      activeCardId: clearActiveCard ? null : (activeCardId ?? this.activeCardId),
    );
  }

  factory WalletState.fromJson(Map<String, dynamic> json) {
    final cards = ((json['cards'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>())
        .map(WalletCardData.fromJson)
        .toList();
    final transactions =
        ((json['transactions'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>())
            .map(WalletTransactionData.fromJson)
            .toList();

    return WalletState(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      cards: cards,
      transactions: transactions,
      activeCardId: json['activeCardId'] as String?,
    );
  }
}

String normalizeCardNumber(String value) {
  return value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
}

String formatBalance(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}
