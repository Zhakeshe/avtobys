import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'wallet_store.dart';

class TopUpOverlay extends StatefulWidget {
  const TopUpOverlay({
    super.key,
    required this.currentBalance,
    required this.onBack,
    required this.onTopUp,
  });

  final double currentBalance;
  final VoidCallback onBack;
  final ValueChanged<double> onTopUp;

  @override
  State<TopUpOverlay> createState() => _TopUpOverlayState();
}

class _TopUpOverlayState extends State<TopUpOverlay> {
  static const amounts = [500, 1000, 2000, 5000];
  final TextEditingController _controller = TextEditingController(text: '1000');
  int _selectedAmount = 1000;

  double get _value => double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                      'Текущий баланс',
                      style: TextStyle(fontSize: 15, color: Color(0xFFD7DCEC)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatBalance(widget.currentBalance)} ₸',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: amounts
                    .map(
                      (amount) => ChoiceChip(
                        label: Text('$amount ₸'),
                        selected: _selectedAmount == amount,
                        onSelected: (_) {
                          _controller.text = '$amount';
                          setState(() {
                            _selectedAmount = amount;
                          });
                        },
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.14),
                        labelStyle: TextStyle(
                          color: _selectedAmount == amount
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
              const Spacer(),
              SizedBox(
                height: 64,
                child: ElevatedButton(
                  onPressed: _value > 0
                      ? () => widget.onTopUp(_value)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    disabledBackgroundColor: const Color(0xFFC8C8C8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Пополнить', style: TextStyle(fontSize: 18)),
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
  final void Function(String holderName, String number) onAddCard;
  final ValueChanged<String> onSetActiveCard;

  @override
  State<CardsOverlay> createState() => _CardsOverlayState();
}

class _CardsOverlayState extends State<CardsOverlay> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  bool get _canAdd =>
      _nameController.text.trim().isNotEmpty &&
      normalizeCardNumber(_numberController.text).length >= 16;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canAdd) {
      return;
    }

    widget.onAddCard(
      _nameController.text.trim(),
      normalizeCardNumber(_numberController.text),
    );
    _nameController.clear();
    _numberController.clear();
    setState(() {});
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
              _Header(title: 'Банковские карты', onBack: widget.onBack),
              Expanded(
                child: ListView(
                  children: [
                    ...widget.walletState.cards.map(
                      (card) => InkWell(
                        onTap: () => widget.onSetActiveCard(card.id),
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
                              const Icon(
                                Icons.credit_card_rounded,
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
                                      card.maskedNumber,
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Text(
                          'Пока нет добавленных карт. Добавьте первую карту ниже.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
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
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        labelText: 'Номер карты',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _canAdd ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          disabledBackgroundColor: const Color(0xFFC8C8C8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Добавить карту', style: TextStyle(fontSize: 17)),
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
