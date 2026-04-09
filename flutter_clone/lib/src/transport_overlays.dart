import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'activity_history.dart';
import 'bluetooth_web_pick.dart';
import 'l10n/app_strings.dart';
import 'theme.dart';
import 'transport_api.dart';
import 'wallet_store.dart';

enum TransportSearchMode { bluetooth, plate, qr }

typedef RefreshSessionCallback = Future<void> Function();

class TicketsOverlay extends StatefulWidget {
  const TicketsOverlay({
    super.key,
    required this.onBack,
    this.uiStrings,
  });

  final VoidCallback onBack;
  final AppStrings? uiStrings;

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
      builder: (context) => _TicketDialog(
        ticket: ticket,
        strings: widget.uiStrings ?? const AppStrings(AppLanguage.ru),
      ),
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
              if (TransportApi.lastTicketsFromOfflineCache) ...[
                const SizedBox(height: 12),
                _InfoBox(
                  message: widget.uiStrings?.offlineDataBanner ??
                      'Офлайн: показаны сохранённые билеты',
                  background: const Color(0xFFFFF8E6),
                  color: const Color(0xFF6B4D00),
                ),
              ],
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
                                            '- ${formatBalance(ticket.amount)} ₸',
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
    this.initialQrToken,
    this.uiStrings,
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

  /// When set (QR flow after camera scan), skips manual token field and searches immediately.
  final String? initialQrToken;

  final AppStrings? uiStrings;

  @override
  State<TransportPaymentOverlay> createState() =>
      _TransportPaymentOverlayState();
}

class _TransportPaymentOverlayState extends State<TransportPaymentOverlay> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();
  Timer? _searchDebounce;

  AppStrings get _strings => widget.uiStrings ?? const AppStrings(AppLanguage.ru);

  bool _allowQueryListener = false;
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

  bool get _hideQrManualInput =>
      _isQr && widget.initialQrToken != null && widget.initialQrToken!.trim().isNotEmpty;

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
    _queryController.addListener(_onQueryChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (!_allowQueryListener || _isBluetooth) {
      return;
    }
    _scheduleDebouncedSearch();
  }

  void _scheduleDebouncedSearch() {
    if (!_isPlate && !_isQr) {
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) {
        return;
      }
      final q = _queryController.text.trim();
      if (q.isEmpty) {
        setState(() {
          _buses = const [];
          _selectedBus = null;
          _error = '';
          _loading = false;
        });
        return;
      }
      _search();
    });
  }

  String _normalizeTransportToken(String value) {
    return value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  }

  Future<void> _pickWebBluetoothDevice() async {
    if (!kIsWeb || _cityId.isEmpty) {
      return;
    }
    setState(() {
      _error = '';
    });
    final label = await pickBluetoothDeviceLabelWeb();
    if (!mounted) {
      return;
    }
    if (label == null || label.isEmpty) {
      setState(() {
        _error =
            'Bluetooth құрылғысы таңдалмады немесе браузер Web Bluetooth қолдамайды (Chrome ұсынылады).';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _selectedBus = null;
    });

    try {
      final token = _normalizeTransportToken(label);
      if (token.isEmpty) {
        throw const ApiException('Құрылғы атауын тану мүмкін емес.');
      }
      final buses = await TransportApi.getBuses(_cityId, number: token);
      if (!mounted) {
        return;
      }
      final btFirst =
          buses.where((b) => b.bluetoothEnabled).toList(growable: false);
      final use = btFirst.isNotEmpty ? btFirst : buses;
      setState(() {
        _buses = use;
        _selectedBus = use.isNotEmpty ? use.first : null;
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
      if (_hideQrManualInput) {
        _queryController.text = widget.initialQrToken!.trim();
        await _search();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    } finally {
      _allowQueryListener = true;
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
      if (buses.isNotEmpty) {
        final first = buses.first;
        await ActivityHistory.add(
          kind: 'bus_search',
          title: '${_isQr ? 'QR' : _isPlate ? 'Нөмір' : 'BT'}: ${query.length > 32 ? '${query.substring(0, 32)}…' : query}',
          subtitle: '${first.number} • ${first.routeNumber} • ${widget.cityName}',
        );
      }
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
      await ActivityHistory.add(
        kind: 'ticket',
        title: 'Төлем: ${selectedBus.number}',
        subtitle: '${formatBalance(selectedBus.price)} ₸ • ${widget.cityName}',
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        builder: (context) => _TicketDialog(ticket: ticket, strings: _strings),
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
                if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                  const SizedBox(height: 14),
                  const _InfoBox(
                    message:
                        'iPhone сафарида Web Bluetooth жоқ. Нөмір бойынша төлем немесе QR қолданыңыз.',
                  ),
                ],
                if (kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickWebBluetoothDevice,
                      icon: const Icon(Icons.bluetooth_searching_rounded),
                      label: const Text(
                        'Bluetooth құрылғысын браузерден таңдау',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chrome Android / Windows / Mac: жүйе терезесінен құрылғыны таңдаңыз. Содан кейін тізімде автобус көрінеді.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ],
              if (_isBluetooth && _loading)
                const Expanded(
                  child: Center(
                    child: _BluetoothSearchIndicator(),
                  ),
                )
              else if (_isBluetooth) ...[
                const SizedBox(height: 18),
                const Text(
                  'Найденные валидаторы',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _paymentColumnChildren(walletActionLabel),
                    ),
                  ),
                ),
              ] else ...[
                if (!_hideQrManualInput) ...[
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
                            children: _paymentColumnChildren(walletActionLabel),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _paymentColumnChildren(String walletActionLabel) {
    return [
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
          onTransportPay:
              _saving || _transportCard == null ? null : () => _pay('transport-card'),
          demoFooter: _strings.demoPaymentNotice,
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
      if (_isBluetooth && _buses.isEmpty && _error.isEmpty && !_loading)
        _InfoBox(
          message:
              'Валидаторы для ${widget.cityName} пока не найдены. Добавьте автобусы в админке или выберите оплату по номеру.',
        ),
    ];
  }
}

class _BluetoothSearchIndicator extends StatefulWidget {
  const _BluetoothSearchIndicator();

  @override
  State<_BluetoothSearchIndicator> createState() => _BluetoothSearchIndicatorState();
}

class _BluetoothSearchIndicatorState extends State<_BluetoothSearchIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final phase = (_controller.value * 3 - i + 1) % 3;
                final scale = 0.55 + 0.45 * (1 - (phase / 2).clamp(0.0, 1.0));
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: AppColors.accentYellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 22),
        const Text(
          'Идет поиск доступного транспорта',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog({required this.ticket, required this.strings});

  final TicketDto ticket;
  final AppStrings strings;

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  Timer? _countdownTicker;

  TicketDto get ticket => widget.ticket;
  AppStrings get strings => widget.strings;

  @override
  void initState() {
    super.initState();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  String _countdownPrimary() {
    final until = ticket.validUntil.toLocal();
    final now = DateTime.now();
    if (!until.isAfter(now)) {
      return strings.validExpired;
    }
    final left = until.difference(now);
    if (left.inMinutes >= 1) {
      return strings.validInMinutes.replaceFirst('%s', '${left.inMinutes}');
    }
    final sec = left.inSeconds.clamp(0, 59);
    return strings.validInSeconds.replaceFirst('%s', '$sec');
  }

  String _validUntilReadable() {
    final v = ticket.validUntil.toLocal();
    final d =
        '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    return '$d ${_formatTime(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final paidLocal = ticket.paidAt.toLocal();
    final dateStr =
        '${paidLocal.day.toString().padLeft(2, '0')}.${paidLocal.month.toString().padLeft(2, '0')}.${paidLocal.year}';
    final routeStr = _formatTicketRoute(ticket.routeNumber);
    final sumStr = '${formatBalance(ticket.amount)} ₸';
    final countdown = _countdownPrimary();
    final validLine = _validUntilReadable();

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final qrSize = (constraints.maxWidth * 0.52).clamp(132.0, 272.0);
            return SingleChildScrollView(
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
                  Text(
                    strings.ticketVehicleNumberCaption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                    child: Semantics(
                      label: strings.ticketQrSemantics,
                      child: QrImageView(
                        data: ticket.qrValue,
                        size: qrSize,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${strings.validUntilLabel}: $validLine',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    liveRegion: true,
                    label: '${strings.validUntilLabel}, $countdown',
                    child: Text(
                      countdown,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: countdown == strings.validExpired
                            ? const Color(0xFFB32828)
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    strings.ticketPaymentTimeCaption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(ticket.paidAt),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    strings.ticketTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final gap = 12.0;
                      final cellW = (innerConstraints.maxWidth - gap) / 2;
                      Widget cell(String label, String value) {
                        return SizedBox(
                          width: cellW,
                          child: _TicketStat(label: label, value: value),
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cell(strings.ticketRouteStat, routeStr),
                              SizedBox(width: gap),
                              cell(strings.ticketPaymentDateStat, dateStr),
                            ],
                          ),
                          SizedBox(height: gap),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cell(strings.ticketTariffStat, ticket.tariffName),
                              SizedBox(width: gap),
                              cell(strings.ticketSumStat, sumStr),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
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
            '${formatPhoneForWalletBanner(phoneNumber)}  ${walletBannerTariffSubtitle(transportCard)}',
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
    this.demoFooter,
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
  final String? demoFooter;

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
        if (demoFooter != null && demoFooter!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            demoFooter!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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

String formatPhoneForWalletBanner(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('7')) {
    final r = digits.substring(1);
    return '+7 (${r.substring(0, 3)}) ${r.substring(3, 6)}-${r.substring(6, 8)}-${r.substring(8)}';
  }
  if (digits.length == 10) {
    return '+7 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }
  return phoneNumber.trim().isEmpty ? '+7 (700) 000-00-00' : phoneNumber;
}

String walletBannerTariffSubtitle(WalletCardData? transportCard) {
  if (transportCard?.isTransport == true) {
    return 'Транспортная';
  }
  return 'Стандарт';
}

String _formatTicketRoute(String routeNumber) {
  final t = routeNumber.trim();
  if (t.isEmpty) {
    return '—';
  }
  if (t.startsWith('№')) {
    return t;
  }
  return '№ $t';
}
