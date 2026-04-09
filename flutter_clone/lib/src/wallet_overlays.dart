import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'wallet_store.dart';

typedef TopUpCallback = Future<void> Function(
  double amount, {
  String targetType,
  String? transportCardId,
});
typedef AddCardCallback = Future<void> Function(
  String holderName,
  String number,
  String cardType,
);
typedef ActivateCardCallback = Future<void> Function(String cardId);

class TopUpOverlay extends StatefulWidget {
  const TopUpOverlay({
    super.key,
    required this.walletState,
    required this.minimumAmount,
    required this.onBack,
    required this.onTopUp,
  });

  final WalletState walletState;
  final double minimumAmount;
  final VoidCallback onBack;
  final TopUpCallback onTopUp;

  @override
  State<TopUpOverlay> createState() => _TopUpOverlayState();
}

class _TopUpOverlayState extends State<TopUpOverlay> {
  static const amounts = [500, 1000, 2000, 5000];

  final TextEditingController _controller = TextEditingController(text: '1000');
  bool _submitting = false;
  String _targetType = 'wallet';
  String? _transportCardId;
  String _error = '';

  List<WalletCardData> get _transportCards =>
      widget.walletState.cards.where((item) => item.isTransport).toList();

  double get _value => double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;

  @override
  void initState() {
    super.initState();
    if (_transportCards.isNotEmpty) {
      _transportCardId = _transportCards.first.id;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (_value < widget.minimumAmount) {
      setState(() {
        _error = 'Минимальное пополнение: ${widget.minimumAmount.toInt()} ₸';
      });
      return;
    }
    if (_targetType == 'transport' && _transportCardId == null) {
      setState(() {
        _error = 'Сначала добавьте транспортную карту.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.onTopUp(
        _value,
        targetType: _targetType,
        transportCardId: _transportCardId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: 'Пополнение баланса', onBack: widget.onBack),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.banner,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Кошелек',
                      style: TextStyle(fontSize: 15, color: Color(0xFFD7DCEC)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatBalance(widget.walletState.balance)} ₸',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Куда зачислить',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TargetChip(
                      label: 'Кошелек',
                      selected: _targetType == 'wallet',
                      onTap: () {
                        setState(() {
                          _targetType = 'wallet';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TargetChip(
                      label: 'Транспортная карта',
                      selected: _targetType == 'transport',
                      onTap: () {
                        setState(() {
                          _targetType = 'transport';
                          _transportCardId ??= _transportCards.isNotEmpty
                              ? _transportCards.first.id
                              : null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_targetType == 'transport') ...[
                const SizedBox(height: 14),
                if (_transportCards.isEmpty)
                  _InfoCard(message: 'У вас пока нет транспортных карт.')
                else
                  ..._transportCards.map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _transportCardId = card.id;
                          });
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _transportCardId == card.id
                                  ? AppColors.primaryBlue
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.contactless_outlined,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.holderName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${card.maskedNumber} • ${formatBalance(card.balance)} ₸',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: amounts
                    .map(
                      (amount) => ChoiceChip(
                        label: Text('$amount ₸'),
                        selected: _controller.text == '$amount',
                        onSelected: (_) {
                          _controller.text = '$amount';
                          setState(() {});
                        },
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.14),
                        labelStyle: TextStyle(
                          color: _controller.text == '$amount'
                              ? AppColors.primaryBlue
                              : AppColors.textPrimary,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  labelText: 'Сумма пополнения',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  message: _error,
                  background: const Color(0xFFFFE4E4),
                  color: const Color(0xFFB32828),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 64,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    disabledBackgroundColor: const Color(0xFFC8C8C8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Пополнить', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardsOverlay extends StatefulWidget {
  const CardsOverlay({
    super.key,
    required this.walletState,
    required this.onBack,
    required this.onAddCard,
    required this.onSetActiveCard,
  });

  final WalletState walletState;
  final VoidCallback onBack;
  final AddCardCallback onAddCard;
  final ActivateCardCallback onSetActiveCard;

  @override
  State<CardsOverlay> createState() => _CardsOverlayState();
}

class _CardsOverlayState extends State<CardsOverlay> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  String _cardType = 'bank';
  bool _submitting = false;
  String _error = '';

  bool get _canAdd {
    final minLength = _cardType == 'transport' ? 6 : 12;
    return _nameController.text.trim().isNotEmpty &&
        normalizeCardNumber(_numberController.text).length >= minLength;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canAdd || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.onAddCard(
        _nameController.text.trim(),
        normalizeCardNumber(_numberController.text),
        _cardType,
      );
      if (!mounted) {
        return;
      }
      _nameController.clear();
      _numberController.clear();
      setState(() {
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _activate(String cardId) async {
    try {
      await widget.onSetActiveCard(cardId);
      if (!mounted) {
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              _Header(title: 'Карты', onBack: widget.onBack),
              Expanded(
                child: ListView(
                  children: [
                    ...widget.walletState.cards.map(
                      (card) => InkWell(
                        onTap: () => _activate(card.id),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: card.id == widget.walletState.activeCard?.id
                                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: card.id == widget.walletState.activeCard?.id
                                  ? AppColors.primaryBlue
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                card.isTransport
                                    ? Icons.contactless_outlined
                                    : Icons.credit_card_rounded,
                                color: AppColors.primaryBlue,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.holderName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      card.isTransport
                                          ? '${card.maskedNumber} • ${formatBalance(card.balance)} ₸'
                                          : card.maskedNumber,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (card.id == widget.walletState.activeCard?.id)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryBlue,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (widget.walletState.cards.isEmpty)
                      const _InfoCard(message: 'Пока нет добавленных карт.'),
                    const SizedBox(height: 12),
                    const Text(
                      'Тип карты',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TargetChip(
                            label: 'Банковская',
                            selected: _cardType == 'bank',
                            onTap: () {
                              setState(() {
                                _cardType = 'bank';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TargetChip(
                            label: 'Транспортная',
                            selected: _cardType == 'transport',
                            onTap: () {
                              setState(() {
                                _cardType = 'transport';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        labelText: 'Название карты',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _numberController,
                      keyboardType: _cardType == 'bank'
                          ? TextInputType.number
                          : TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          _cardType == 'bank'
                              ? RegExp(r'[0-9 ]')
                              : RegExp(r'[0-9A-Za-z ]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        labelText: _cardType == 'bank'
                            ? 'Номер банковской карты'
                            : 'Номер транспортной карты',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InfoCard(
                        message: _error,
                        background: const Color(0xFFFFE4E4),
                        color: const Color(0xFFB32828),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _submitting || !_canAdd ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          disabledBackgroundColor: const Color(0xFFC8C8C8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Добавить карту',
                                style: TextStyle(fontSize: 17),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryBlue : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.message,
    this.background = AppColors.surfaceMuted,
    this.color = AppColors.textSecondary,
  });

  final String message;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 14, height: 1.35, color: color),
      ),
    );
  }
}
