import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'theme.dart';
import 'transport_api.dart';
import 'wallet_store.dart';

enum TransportSearchMode { bluetooth, plate, qr }

typedef RefreshSessionCallback = Future<void> Function();

class TicketsOverlay extends StatefulWidget {
  const TicketsOverlay({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  State<TicketsOverlay> createState() => _TicketsOverlayState();
}

class _TicketsOverlayState extends State<TicketsOverlay> {
  bool _loading = true;
  String _error = '';
  List<TicketDto> _tickets = const [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final tickets = await TransportApi.getTickets();
      if (!mounted) {
        return;
      }
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить билеты.';
      });
    }
  }

  Future<void> _openTicket(TicketDto ticket) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => _TicketDialog(ticket: ticket),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverlayHeader(title: 'Мои билеты', onBack: widget.onBack),
              const SizedBox(height: 18),
              const Text(
                'Последние билеты',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTickets,
                        child: _tickets.isEmpty
                            ? ListView(
                                children: [
                                  _InfoBox(
                                    message: _error.isNotEmpty
                                        ? _error
                                        : 'Билетов пока нет. Оплатите проезд по номеру автобуса, QR token или из списка валидаторов.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                itemCount: _tickets.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final ticket = _tickets[index];
                                  return InkWell(
                                    onTap: () => _openTicket(ticket),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: appCardShadow,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            height: 44,
                                            width: 44,
                                            decoration: const BoxDecoration(
                                              color: AppColors.accentYellow,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.directions_bus_rounded,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Маршрут ${ticket.routeNumber}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${ticket.busNumber} • ${ticket.cityName}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '- ${ticket.amount.toInt()} ₸',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransportPaymentOverlay extends StatefulWidget {
  const TransportPaymentOverlay({
    super.key,
    required this.mode,
    required this.phoneNumber,
    required this.cityName,
    required this.walletState,
    required this.rideAccessEnabled,
    required this.trialRidesRemaining,
    required this.accessTelegram,
    required this.onBack,
    required this.onSessionRefresh,
  });

  final TransportSearchMode mode;
  final String phoneNumber;
  final String cityName;
  final WalletState walletState;
  final bool rideAccessEnabled;
  final int trialRidesRemaining;
  final String accessTelegram;
  final VoidCallback onBack;
  final RefreshSessionCallback onSessionRefresh;

  @override
  State<TransportPaymentOverlay> createState() =>
      _TransportPaymentOverlayState();
}

class _TransportPaymentOverlayState extends State<TransportPaymentOverlay> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _error = '';
  String _cityId = '';
  String? _selectedTariffId;
  List<BusDto> _buses = const [];
  List<TariffDto> _tariffs = const [];
  BusDto? _selectedBus;

  bool get _isPlate => widget.mode == TransportSearchMode.plate;
  bool get _isQr => widget.mode == TransportSearchMode.qr;
  bool get _isBluetooth => widget.mode == TransportSearchMode.bluetooth;

  WalletCardData? get _transportCard {
    for (final card in widget.walletState.cards) {
      if (card.id == widget.walletState.activeCardId && card.isTransport) {
        return card;
      }
    }
    for (final card in widget.walletState.cards) {
      if (card.isTransport) {
        return card;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final cities = await TransportApi.getCities();
      if (cities.isEmpty) {
        throw const ApiException('Города пока не настроены.');
      }
      final city = cities.firstWhere(
        (item) => item.name == widget.cityName,
        orElse: () => cities.first,
      );
      final tariffs = await TransportApi.getTariffs(city.id);
      var buses = const <BusDto>[];
      if (_isBluetooth) {
        buses = (await TransportApi.getBuses(city.id))
            .where((item) => item.bluetoothEnabled)
            .toList();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _cityId = city.id;
        _tariffs = tariffs;
        _selectedTariffId = tariffs.isNotEmpty ? tariffs.first.id : null;
        _buses = buses;
        _selectedBus = buses.isNotEmpty ? buses.first : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _search() async {
    if (_cityId.isEmpty) {
      return;
    }
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _buses = _isBluetooth ? _buses : const [];
        _selectedBus = _isBluetooth && _buses.isNotEmpty ? _buses.first : null;
        _error = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _selectedBus = null;
    });

    try {
      final buses = await TransportApi.getBuses(
        _cityId,
        number: _isPlate ? query.toUpperCase() : '',
        qrToken: _isQr ? query : '',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buses = buses;
        _selectedBus = buses.isNotEmpty ? buses.first : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses = const [];
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _addBus() async {
    final number = _queryController.text.trim().toUpperCase();
    final routeNumber = _routeController.text.trim();
    final tariffId = _selectedTariffId;
    if (_cityId.isEmpty || number.isEmpty || routeNumber.isEmpty || tariffId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final bus = await TransportApi.addBus(
        cityId: _cityId,
        tariffId: tariffId,
        number: number,
        routeNumber: routeNumber,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buses = [bus];
        _selectedBus = bus;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _pay(String paymentMethod) async {
    final selectedBus = _selectedBus;
    if (selectedBus == null || _saving) {
      return;
    }

    if (!widget.rideAccessEnabled && widget.trialRidesRemaining <= 0) {
      setState(() {
        _error =
            'Доступ к поездкам закрыт. Напишите ${widget.accessTelegram} для активации.';
      });
      return;
    }

    if (paymentMethod == 'wallet' &&
        widget.rideAccessEnabled &&
        widget.walletState.balance < selectedBus.price) {
      setState(() {
        _error = 'Недостаточно средств в кошельке.';
      });
      return;
    }

    if (paymentMethod == 'transport-card') {
      final card = _transportCard;
      if (!widget.rideAccessEnabled) {
        setState(() {
          _error = 'Транспортная карта станет доступна после активации доступа.';
        });
        return;
      }
      if (card == null) {
        setState(() {
          _error = 'Не найдена транспортная карта.';
        });
        return;
      }
      if (card.balance < selectedBus.price) {
        setState(() {
          _error = 'Недостаточно средств на транспортной карте.';
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final ticket = await TransportApi.createTicket(
        phoneNumber: widget.phoneNumber,
        busId: selectedBus.id,
        paymentMethod: paymentMethod,
        cityId: _cityId,
        cityName: widget.cityName,
        cardId: paymentMethod == 'transport-card' ? _transportCard?.id : null,
      );
      await widget.onSessionRefresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        builder: (context) => _TicketDialog(ticket: ticket),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error.code == 'ACCESS_REQUIRED'
            ? 'Доступ к поездкам закрыт. Напишите ${error.supportTelegram ?? widget.accessTelegram}.'
            : error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  String get _title {
    switch (widget.mode) {
      case TransportSearchMode.bluetooth:
        return 'Bluetooth оплата';
      case TransportSearchMode.plate:
        return 'Оплата по номеру автобуса';
      case TransportSearchMode.qr:
        return 'QR оплата';
    }
  }

  String get _searchHint {
    switch (widget.mode) {
      case TransportSearchMode.bluetooth:
        return '';
      case TransportSearchMode.plate:
        return 'Введите номер транспорта';
      case TransportSearchMode.qr:
        return 'Введите QR token автобуса';
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletActionLabel = !widget.rideAccessEnabled &&
            widget.trialRidesRemaining > 0
        ? 'Использовать пробную поездку'
        : 'Оплатить кошельком';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverlayHeader(title: _title, onBack: widget.onBack),
              if (_isBluetooth) ...[
                const SizedBox(height: 20),
                _WalletBanner(
                  phoneNumber: widget.phoneNumber,
                  balance: widget.walletState.balance,
                  transportCard: _transportCard,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Найденные валидаторы',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                _RoundedInput(
                  controller: _queryController,
                  hintText: _searchHint,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _ActionButton(
                  label: _isQr ? 'Найти автобус по QR token' : 'Далее',
                  enabled: _queryController.text.trim().isNotEmpty && !_loading,
                  onTap: _search,
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryBlue),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._buses.map(
                              (bus) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _BusCard(
                                  bus: bus,
                                  selected: _selectedBus?.id == bus.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedBus = bus;
                                    });
                                  },
                                ),
                              ),
                            ),
                            if (!_isBluetooth &&
                                _queryController.text.trim().isNotEmpty &&
                                _buses.isEmpty &&
                                _tariffs.isNotEmpty)
                              _AddBusCard(
                                routeController: _routeController,
                                tariffs: _tariffs,
                                selectedTariffId: _selectedTariffId,
                                onSelectTariff: (value) {
                                  setState(() {
                                    _selectedTariffId = value;
                                  });
                                },
                                onAddBus: _saving ? null : _addBus,
                              ),
                            if (_selectedBus != null) ...[
                              const SizedBox(height: 10),
                              _PaymentSummaryCard(
                                bus: _selectedBus!,
                                rideAccessEnabled: widget.rideAccessEnabled,
                                trialRidesRemaining: widget.trialRidesRemaining,
                                walletActionLabel: walletActionLabel,
                                canUseWallet: widget.rideAccessEnabled
                                    ? widget.walletState.balance >= _selectedBus!.price
                                    : widget.trialRidesRemaining > 0,
                                canUseTransportCard: widget.rideAccessEnabled &&
                                    _transportCard != null &&
                                    _transportCard!.balance >= _selectedBus!.price,
                                transportCardLabel: _transportCard == null
                                    ? 'Транспортная карта не добавлена'
                                    : 'Транспортная карта • ${formatBalance(_transportCard!.balance)} ₸',
                                onWalletPay: _saving ? null : () => _pay('wallet'),
                                onTransportPay: _saving || _transportCard == null
                                    ? null
                                    : () => _pay('transport-card'),
                              ),
                            ],
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _InfoBox(
                                message: _error,
                                background: const Color(0xFFFFE4E4),
                                color: const Color(0xFFB32828),
                              ),
                            ],
                            if (_isBluetooth && _buses.isEmpty && _error.isEmpty)
                              _InfoBox(
                                message:
                                    'Валидаторы для ${widget.cityName} пока не найдены. Добавьте автобусы в админке или выберите оплату по номеру.',
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketDialog extends StatelessWidget {
  const _TicketDialog({required this.ticket});

  final TicketDto ticket;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: appCardShadow,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(18),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const Text(
                'Номер транспорта',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                ticket.busNumber,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: ticket.qrValue,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Время оплаты',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(ticket.paidAt),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Мой билет',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _TicketStat(label: 'Город', value: ticket.cityName),
                  const _TicketStat(label: 'Дата оплаты', value: 'Сегодня'),
                  _TicketStat(label: 'Маршрут', value: ticket.routeNumber),
                  _TicketStat(
                    label: 'Сумма проезда',
                    value: '${ticket.amount.toInt()} ₸',
                  ),
                  _TicketStat(label: 'Вид тарифа', value: ticket.tariffName),
                  _TicketStat(
                    label: 'Действует до',
                    value: _formatTime(ticket.validUntil),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({required this.title, required this.onBack});

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

class _WalletBanner extends StatelessWidget {
  const _WalletBanner({
    required this.phoneNumber,
    required this.balance,
    required this.transportCard,
  });

  final String phoneNumber;
  final double balance;
  final WalletCardData? transportCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.banner,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Кошелек',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '${formatBalance(balance)} ₸',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$phoneNumber  ${transportCard?.holderName ?? 'Стандарт'}',
            style: const TextStyle(fontSize: 15, color: Color(0xFFD7DCEC)),
          ),
        ],
      ),
    );
  }
}

class _RoundedInput extends StatelessWidget {
  const _RoundedInput({
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            hintStyle: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          style: const TextStyle(fontSize: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({
    required this.bus,
    required this.selected,
    required this.onTap,
  });

  final BusDto bus;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.banner,
          borderRadius: BorderRadius.circular(24),
          border: selected ? Border.all(color: AppColors.primaryBlue, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bus.number,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${bus.price.toInt()} ₸',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Маршрут ${bus.routeNumber}',
              style: const TextStyle(fontSize: 16, color: Color(0xFFD7DCEC)),
            ),
            const SizedBox(height: 6),
            Text(
              'Тариф ${bus.tariffName}',
              style: const TextStyle(fontSize: 16, color: Color(0xFFD7DCEC)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBusCard extends StatelessWidget {
  const _AddBusCard({
    required this.routeController,
    required this.tariffs,
    required this.selectedTariffId,
    required this.onSelectTariff,
    required this.onAddBus,
  });

  final TextEditingController routeController;
  final List<TariffDto> tariffs;
  final String? selectedTariffId;
  final ValueChanged<String> onSelectTariff;
  final VoidCallback? onAddBus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Автобус не найден. Можно сразу добавить его в базу.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _RoundedInput(
            controller: routeController,
            hintText: 'Маршрут, например №12',
          ),
          const SizedBox(height: 12),
          ...tariffs.map(
            (tariff) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                onTap: () => onSelectTariff(tariff.id),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: selectedTariffId == tariff.id
                        ? Border.all(color: AppColors.primaryBlue)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tariff.name,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${tariff.price.toInt()} ₸',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _ActionButton(
            label: 'Добавить автобус',
            enabled: onAddBus != null,
            onTap: onAddBus,
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.bus,
    required this.rideAccessEnabled,
    required this.trialRidesRemaining,
    required this.walletActionLabel,
    required this.canUseWallet,
    required this.canUseTransportCard,
    required this.transportCardLabel,
    required this.onWalletPay,
    required this.onTransportPay,
  });

  final BusDto bus;
  final bool rideAccessEnabled;
  final int trialRidesRemaining;
  final String walletActionLabel;
  final bool canUseWallet;
  final bool canUseTransportCard;
  final String transportCardLabel;
  final VoidCallback? onWalletPay;
  final VoidCallback? onTransportPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.banner,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Номер транспорта',
                style: TextStyle(fontSize: 14, color: Color(0xFFD7DCEC)),
              ),
              const SizedBox(height: 6),
              Text(bus.number, style: const TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 14),
              const Text(
                'Маршрут',
                style: TextStyle(fontSize: 14, color: Color(0xFFD7DCEC)),
              ),
              const SizedBox(height: 6),
              Text(bus.routeNumber, style: const TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 14),
              const Text(
                'Тариф',
                style: TextStyle(fontSize: 14, color: Color(0xFFD7DCEC)),
              ),
              const SizedBox(height: 6),
              Text(bus.tariffName, style: const TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 14),
              const Text(
                'Сумма',
                style: TextStyle(fontSize: 14, color: Color(0xFFD7DCEC)),
              ),
              const SizedBox(height: 6),
              Text(
                '${bus.price.toInt()} ₸',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (!rideAccessEnabled) ...[
                const SizedBox(height: 12),
                Text(
                  'Пробных поездок осталось: $trialRidesRemaining',
                  style: const TextStyle(fontSize: 14, color: Color(0xFFD7DCEC)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ActionButton(
          label: walletActionLabel,
          enabled: canUseWallet,
          onTap: onWalletPay,
        ),
        const SizedBox(height: 14),
        _ActionButton(
          label: transportCardLabel,
          enabled: canUseTransportCard,
          onTap: onTransportPay,
          backgroundColor: const Color(0xFFF1F1F1),
          foregroundColor: AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.backgroundColor = AppColors.primaryBlue,
    this.foregroundColor = Colors.white,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: enabled ? backgroundColor : const Color(0xFFC8C8C8),
          disabledBackgroundColor: const Color(0xFFC8C8C8),
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 15, height: 1.35, color: color),
      ),
    );
  }
}

class _TicketStat extends StatelessWidget {
  const _TicketStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hours = local.hour.toString().padLeft(2, '0');
  final minutes = local.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}
