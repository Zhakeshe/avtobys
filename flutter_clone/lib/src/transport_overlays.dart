import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'theme.dart';
import 'transport_api.dart';
import 'wallet_store.dart';

enum TransportSearchMode { bluetooth, plate }

typedef ChargeBalanceCallback = Future<void> Function(double amount);

class TicketsOverlay extends StatefulWidget {
  const TicketsOverlay({
    super.key,
    required this.phoneNumber,
    required this.onBack,
  });

  final String phoneNumber;
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
      final tickets = await TransportApi.getTickets(widget.phoneNumber);
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
        _error = 'Не удалось загрузить билеты';
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
                'Последний билет',
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
                                  const _EmptyStateCard(
                                    message:
                                        'Билетов пока нет. Оплатите проезд по номеру автобуса или через Bluetooth.',
                                  ),
                                  if (_error.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _ErrorLabel(message: _error),
                                  ],
                                ],
                              )
                            : ListView.separated(
                                itemCount: _tickets.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Маршрут ${ticket.routeNumber}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${ticket.busNumber} • ${ticket.cityName}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        AppColors.textSecondary,
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
    required this.walletBalance,
    required this.onBack,
    required this.onPaid,
  });

  final TransportSearchMode mode;
  final String phoneNumber;
  final String cityName;
  final double walletBalance;
  final VoidCallback onBack;
  final ChargeBalanceCallback onPaid;

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
      final city = cities.firstWhere(
        (item) => item.name == widget.cityName,
        orElse: () => cities.first,
      );
      final tariffs = await TransportApi.getTariffs(city.id);
      final buses = _isPlate
          ? const <BusDto>[]
          : await TransportApi.getBuses(
              city.id,
              number: _queryController.text.trim(),
            );

      if (!mounted) {
        return;
      }

      final preparedBuses = _isPlate
          ? buses
          : buses.where((item) => item.bluetoothEnabled).toList();

      setState(() {
        _cityId = city.id;
        _tariffs = tariffs;
        _selectedTariffId = tariffs.isNotEmpty ? tariffs.first.id : null;
        _buses = preparedBuses;
        _selectedBus = preparedBuses.isNotEmpty ? preparedBuses.first : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить автобусы';
      });
    }
  }

  Future<void> _searchBuses(String value) async {
    if (_cityId.isEmpty || !_isPlate) {
      return;
    }

    if (value.trim().isEmpty) {
      setState(() {
        _buses = const [];
        _selectedBus = null;
        _loading = false;
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
      final buses = await TransportApi.getBuses(_cityId, number: value.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _buses = buses;
        _selectedBus = buses.isNotEmpty ? buses.first : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses = const [];
        _loading = false;
        _error = 'Не удалось выполнить поиск';
      });
    }
  }

  Future<void> _addBus() async {
    final number = _queryController.text.trim().toUpperCase();
    final routeNumber = _routeController.text.trim();
    final tariffId = _selectedTariffId;
    if (_cityId.isEmpty ||
        number.isEmpty ||
        routeNumber.isEmpty ||
        tariffId == null) {
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Не удалось добавить автобус';
      });
    }
  }

  Future<void> _pay() async {
    final selectedBus = _selectedBus;
    if (selectedBus == null || _saving) {
      return;
    }
    if (widget.walletBalance < selectedBus.price) {
      setState(() {
        _error = 'Недостаточно баланса в кошельке';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final ticket = await TransportApi.createTicket(
        phoneNumber: widget.phoneNumber,
        busId: selectedBus.id,
      );
      await widget.onPaid(selectedBus.price);
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Не удалось создать билет';
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
              _OverlayHeader(
                title: _isPlate
                    ? 'Оплата по номеру автобуса'
                    : 'Bluetooth оплата',
                onBack: widget.onBack,
              ),
              if (_isPlate) ...[
                const SizedBox(height: 24),
                _RoundedInput(
                  controller: _queryController,
                  hintText: 'Введите номер транспорта',
                  onChanged: _searchBuses,
                ),
              ] else ...[
                const SizedBox(height: 20),
                _WalletBanner(
                  phoneNumber: widget.phoneNumber,
                  balance: widget.walletBalance,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Доступные автобусы рядом',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryBlue,
                        ),
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
                            if (_isPlate &&
                                _queryController.text.trim().isNotEmpty &&
                                _buses.isEmpty)
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
                                onPay: _saving ? null : _pay,
                              ),
                            ],
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _ErrorLabel(message: _error),
                            ],
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
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
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
  const _WalletBanner({required this.phoneNumber, required this.balance});

  final String phoneNumber;
  final double balance;

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
            '$phoneNumber  Стандарт',
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
          border: selected
              ? Border.all(color: AppColors.primaryBlue, width: 2)
              : null,
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
            'Автобус с таким номером не найден',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _RoundedInput(
            controller: routeController,
            hintText: 'Маршрут, например № 12',
          ),
          const SizedBox(height: 12),
          const Text(
            'Тариф',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          ...tariffs.map(
            (tariff) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                onTap: () => onSelectTariff(tariff.id),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
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
  const _PaymentSummaryCard({required this.bus, required this.onPay});

  final BusDto bus;
  final VoidCallback? onPay;

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
              Text(
                bus.number,
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 14),
              const Text(
                'Маршрут',
                style: TextStyle(fontSize: 14, color: Color(0xFFD7DCEC)),
              ),
              const SizedBox(height: 6),
              Text(
                bus.routeNumber,
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 14),
              const Text(
                'Вид тарифа',
                style: TextStyle(fontSize: 14, color: Color(0xFFD7DCEC)),
              ),
              const SizedBox(height: 6),
              Text(
                bus.tariffName,
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ActionButton(
          label: 'Оплатить с помощью кошелька',
          enabled: onPay != null,
          onTap: onPay,
        ),
        const SizedBox(height: 14),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text(
              'Другие способы',
              style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
            ),
          ),
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
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: enabled
              ? AppColors.primaryBlue
              : const Color(0xFFC8C8C8),
          disabledBackgroundColor: const Color(0xFFC8C8C8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ErrorLabel extends StatelessWidget {
  const _ErrorLabel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(fontSize: 14, color: Color(0xFFC62828)),
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
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
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
