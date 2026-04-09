import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_history.dart';
import 'app_prefs.dart';
import 'data.dart';
import 'login_phone_storage.dart';
import 'l10n/app_strings.dart';
import 'theme.dart';
import 'transport_api.dart';
import 'wallet_store.dart';

enum AppOverlay {
  login,
  cityPicker,
  payments,
  transfers,
  bluetooth,
  plate,
  tickets,
  settings,
  cards,
  topUp,
}

typedef AuthCodeRequestCallback = Future<AuthCodeRequestDto> Function(
  String phoneNumber,
);
typedef AuthCodeVerifyCallback = Future<void> Function(
  String phoneNumber,
  String code,
);
typedef CheckTelegramBindCallback = Future<TelegramBindStatusDto> Function(
  String phoneNumber,
);
typedef RequestRideAccessCallback = Future<String> Function();
typedef RequestTelegramBindCallback = Future<TelegramBindDto> Function();

class RoutesTabScreen extends StatefulWidget {
  const RoutesTabScreen({
    super.key,
    required this.city,
    required this.onOpenCity,
    this.uiStrings,
  });

  final String city;
  final VoidCallback onOpenCity;
  final AppStrings? uiStrings;

  @override
  State<RoutesTabScreen> createState() => _RoutesTabScreenState();
}

class _RoutesTabScreenState extends State<RoutesTabScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = true;
  String _error = '';
  String? _cityId;
  List<BusDto> _buses = const [];
  List<BusDto> _serverHits = const [];
  bool _serverSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRoutes();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final q = _searchController.text.trim();
    if (_cityId == null || _cityId!.isEmpty) {
      setState(() {});
      return;
    }
    if (q.length < 2) {
      setState(() {
        _serverHits = const [];
        _serverSearchLoading = false;
      });
      return;
    }
    setState(() {
      _serverSearchLoading = true;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 340), () async {
      final cityId = _cityId;
      if (cityId == null || !mounted) {
        return;
      }
      try {
        final hits = await TransportApi.getBuses(cityId, number: q.toUpperCase());
        if (!mounted) {
          return;
        }
        if (_searchController.text.trim() != q) {
          return;
        }
        setState(() {
          _serverHits = hits;
          _serverSearchLoading = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _serverHits = const [];
          _serverSearchLoading = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant RoutesTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city) {
      _loadRoutes();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final cities = await TransportApi.getCities();
      if (cities.isEmpty) {
        throw const ApiException('Города пока не добавлены.');
      }
      final city = cities.firstWhere(
        (item) => item.name == widget.city,
        orElse: () => cities.first,
      );
      final buses = await TransportApi.getBuses(city.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _cityId = city.id;
        _buses = buses;
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

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final queryLower = query.toLowerCase();
    final List<BusDto> filtered;
    if (query.length >= 2 && _serverHits.isNotEmpty) {
      filtered = _serverHits;
    } else if (query.isEmpty) {
      filtered = _buses;
    } else {
      filtered = _buses
          .where(
            (bus) =>
                bus.number.toLowerCase().contains(queryLower) ||
                bus.routeNumber.toLowerCase().contains(queryLower) ||
                bus.tariffName.toLowerCase().contains(queryLower),
          )
          .toList();
    }

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 140),
        child: Column(
          children: [
            _CitySelector(city: widget.city, onTap: widget.onOpenCity),
            if (TransportApi.lastBusesFromOfflineCache &&
                !_loading &&
                _error.isEmpty &&
                _buses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  widget.uiStrings?.offlineDataBanner ??
                      const AppStrings(AppLanguage.ru).offlineDataBanner,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SearchField(
              controller: _searchController,
              hintText: 'Поиск маршрута или номера',
              onChanged: (_) => setState(() {}),
            ),
            if (_serverSearchLoading && query.length >= 2) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              )
            else if (filtered.isEmpty)
              _InfoCard(
                message: _error.isNotEmpty
                    ? _error
                    : 'В выбранном городе автобусы пока не добавлены.',
              )
            else
              ...filtered.map(
                (bus) => _RouteItemRow(
                  title: 'Маршрут ${bus.routeNumber}',
                  subtitle: '${bus.number} • ${bus.tariffName}',
                  showDivider: bus != filtered.last,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MenuTabScreen extends StatelessWidget {
  const MenuTabScreen({
    super.key,
    required this.city,
    required this.bankCardSubtitle,
    required this.onOpenNotifications,
    required this.onOpenCity,
    required this.onOpenSettings,
    required this.onOpenCards,
  });

  final String city;
  final String bankCardSubtitle;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenCity;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenCards;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 140),
      child: Column(
        children: [
          ...settingsMenuItems.map((item) {
            final rowItem = item.id == 'city'
                ? MenuItemData(
                    id: item.id,
                    title: item.title,
                    subtitle: city,
                    icon: item.icon,
                  )
                : (item.id == 'bank-card'
                      ? MenuItemData(
                          id: item.id,
                          title: item.title,
                          subtitle: bankCardSubtitle,
                          icon: item.icon,
                        )
                      : item);
            return _MenuListTile(
              data: rowItem,
              showDivider: item != settingsMenuItems.last,
              onTap: switch (item.id) {
                'notifications' => onOpenNotifications,
                'city' => onOpenCity,
                'settings' => onOpenSettings,
                'bank-card' => onOpenCards,
                _ => null,
              },
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.banner,
                borderRadius: BorderRadius.circular(22),
                boxShadow: appCardShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Поделиться с друзьями',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Отправить ссылку на приложение',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFD7DCEC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ShareBubble(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginEntryScreen extends StatefulWidget {
  const LoginEntryScreen({
    super.key,
    required this.onRequestCode,
    required this.onVerifyCode,
    required this.onCheckTelegramBind,
    required this.supportTelegram,
    this.initialPhoneNumber,
  });

  final AuthCodeRequestCallback onRequestCode;
  final AuthCodeVerifyCallback onVerifyCode;
  final CheckTelegramBindCallback onCheckTelegramBind;
  final String supportTelegram;
  final String? initialPhoneNumber;

  @override
  State<LoginEntryScreen> createState() => _LoginEntryScreenState();
}

class _LoginEntryScreenState extends State<LoginEntryScreen> {
  late final TextEditingController _phoneController;
  final TextEditingController _codeController = TextEditingController();
  bool _requesting = false;
  bool _verifying = false;
  bool _awaitingCode = false;
  bool _checkingBind = false;
  String _error = '';
  String? _debugCode;
  TelegramBindDto? _telegramBind;
  Timer? _bindTimer;

  String get _digits => _phoneController.text.replaceAll(RegExp(r'\D'), '');
  bool get _canRequestCode => _digits.length >= 10;
  bool get _canVerifyCode => _codeController.text.trim().length >= 4;

  String get _phoneNumber {
    final raw = _digits.padRight(10, ' ');
    final parts = <String>[
      raw.substring(0, 3).trim(),
      raw.substring(3, 6).trim(),
      raw.substring(6, 8).trim(),
      raw.substring(8, 10).trim(),
    ].where((part) => part.isNotEmpty).toList();
    return '+7 ${parts.join('-')}';
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    _phoneController = TextEditingController(
      text: initial.startsWith('7') && initial.length > 10
          ? initial.substring(initial.length - 10)
          : initial,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateSavedPhone());
  }

  Future<void> _hydrateSavedPhone() async {
    if (_phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 10) {
      return;
    }
    final saved = await LoginPhoneStorage.load10Digits();
    if (!mounted || saved == null) {
      return;
    }
    _phoneController.value = TextEditingValue(
      text: saved,
      selection: TextSelection.collapsed(offset: saved.length),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _bindTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startBindPolling() {
    _bindTimer?.cancel();
    _bindTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkTelegramBind();
    });
    _checkTelegramBind();
  }

  void _stopBindPolling() {
    _bindTimer?.cancel();
    _bindTimer = null;
  }

  Future<void> _requestCode() async {
    if (!_canRequestCode || _requesting) {
      return;
    }
    setState(() {
      _requesting = true;
      _error = '';
      _debugCode = null;
      _telegramBind = null;
    });
    try {
      final response = await widget.onRequestCode(_phoneNumber);
      final canEnterCode =
          (response.debugCode?.isNotEmpty ?? false) ||
          response.deliveryStatus == 'sent';
      final deliveryError = _mapDeliveryError(response);
      if (!mounted) {
        return;
      }
      setState(() {
        _awaitingCode = canEnterCode;
        _requesting = false;
        _debugCode = response.debugCode;
        _telegramBind = response.telegramBind;
        _error = deliveryError;
        _codeController.clear();
      });
      if (canEnterCode) {
        unawaited(LoginPhoneStorage.save10Digits(_digits));
      }
      if (response.telegramBind != null) {
        _startBindPolling();
      } else {
        _stopBindPolling();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requesting = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _checkTelegramBind() async {
    if (_checkingBind || _telegramBind == null || _requesting || _digits.length < 10) {
      return;
    }
    _checkingBind = true;
    try {
      final status = await widget.onCheckTelegramBind(_phoneNumber);
      if (!mounted || !status.isBound) {
        return;
      }

      _stopBindPolling();
      setState(() {
        _telegramBind = null;
        _error = '';
      });
      await _requestCode();
    } catch (_) {
      // Keep polling silently while the user is on the bind screen.
    } finally {
      _checkingBind = false;
    }
  }

  Future<void> _verifyCode() async {
    if (!_canVerifyCode || _verifying) {
      return;
    }
    setState(() {
      _verifying = true;
      _error = '';
    });
    try {
      await widget.onVerifyCode(_phoneNumber, _codeController.text.trim());
      await LoginPhoneStorage.save10Digits(_digits);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _verifying = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openTelegramValue(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Invalid Telegram link.';
      });
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      setState(() {
        _error = 'Could not open Telegram. Please copy the link manually.';
      });
    }
  }

  String _mapDeliveryError(AuthCodeRequestDto response) {
    if ((response.debugCode?.isNotEmpty ?? false) || response.deliveryStatus == 'sent') {
      return '';
    }
    if (response.telegramBind != null) {
      return '';
    }
    final deliveryError = response.deliveryError?.trim() ?? '';
    if (deliveryError.isNotEmpty) {
      return deliveryError;
    }
    if (response.deliveryStatus == 'chat-not-configured') {
      return 'Bind Telegram chat for this phone number first.';
    }
    if (response.deliveryStatus == 'bot-not-configured') {
      return 'Telegram bot is not configured yet.';
    }
    final status = response.deliveryStatus?.trim() ?? '';
    return status.isNotEmpty ? 'Code was not delivered ($status).' : '';
  }

  Future<void> _copyTelegramValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано в буфер обмена')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 170,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _SkylinePainter()),
                          ),
                          Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: AppColors.accentYellow,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: appCardShadow,
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: appCardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: SizedBox(
                              width: 78,
                              child: Divider(
                                thickness: 5,
                                color: Color(0xFFD7D7D7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            _awaitingCode
                                ? 'Введите код входа'
                                : 'Введите номер телефона',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _awaitingCode
                                ? 'Код отправлен в Telegram. Для входа введите его ниже.'
                                : (_telegramBind != null
                                      ? 'Telegram-бот не может написать первым. Отправьте команду ниже, потом запросите код еще раз.'
                                      : 'Код подтверждения придет в Telegram.'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_awaitingCode)
                            _CodeEntryCard(
                              phoneNumber: _phoneNumber,
                              controller: _codeController,
                              onChanged: (_) => setState(() {}),
                              onChangePhone: () {
                                setState(() {
                                  _awaitingCode = false;
                                  _error = '';
                                  _codeController.clear();
                                  _telegramBind = null;
                                });
                              },
                            )
                          else
                            _PhoneEntryCard(
                              controller: _phoneController,
                              onChanged: (_) => setState(() {}),
                            ),
                          if (_debugCode != null) ...[
                            const SizedBox(height: 14),
                            _InfoCard(
                              message: 'Debug-код: $_debugCode',
                              background: const Color(0xFFFFF3D8),
                              color: const Color(0xFF6B4D00),
                            ),
                          ],
                          if (_telegramBind != null) ...[
                            const SizedBox(height: 14),
                            _TelegramBindInfoCard(
                              bind: _telegramBind!,
                              onCopy: _copyTelegramValue,
                              onOpen: _openTelegramValue,
                            ),
                          ],
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _InfoCard(
                              message: _error,
                              background: const Color(0xFFFFE4E4),
                              color: const Color(0xFFB32828),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            'Если код не пришел, напишите ${widget.supportTelegram}.',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PrimaryButton(
                      label: _awaitingCode
                          ? 'Войти'
                          : (_telegramBind != null
                                ? 'Запросить код снова'
                                : 'Далее'),
                      enabled: _awaitingCode ? _canVerifyCode : _canRequestCode,
                      busy: _awaitingCode ? _verifying : _requesting,
                      onTap: _awaitingCode ? _verifyCode : _requestCode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CityPickerOverlay extends StatefulWidget {
  const CityPickerOverlay({
    super.key,
    required this.selectedCity,
    required this.cities,
    required this.onSelected,
    required this.onBack,
    this.showBack = true,
  });

  final String selectedCity;
  final List<String> cities;
  final ValueChanged<String> onSelected;
  final VoidCallback onBack;
  final bool showBack;

  @override
  State<CityPickerOverlay> createState() => _CityPickerOverlayState();
}

class _CityPickerOverlayState extends State<CityPickerOverlay> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final cities = query.isEmpty
        ? widget.cities
        : widget.cities.where((city) => city.toLowerCase().contains(query)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(title: '', onBack: widget.showBack ? widget.onBack : null),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: _SearchField(
                controller: _controller,
                hintText: 'Выберите город',
                leading: Icons.location_on_outlined,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: cities.length,
                itemBuilder: (context, index) {
                  final city = cities[index];
                  final isSelected = city == widget.selectedCity;
                  return InkWell(
                    onTap: () => widget.onSelected(city),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              city,
                              style: const TextStyle(
                                fontSize: 20,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              height: 38,
                              width: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentsOverlay extends StatelessWidget {
  const PaymentsOverlay({
    super.key,
    required this.onBack,
    required this.onOpenTransfers,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenTransfers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(title: 'Платежи', onBack: onBack),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: _SearchField(hintText: 'Поиск'),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _TopTab(label: 'Платежи', selected: true),
                  SizedBox(width: 28),
                  _TopTab(label: 'Избранное'),
                  SizedBox(width: 28),
                  _TopTab(label: 'История'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: paymentCategories.length,
                itemBuilder: (context, index) {
                  final item = paymentCategories[index];
                  return _OverlayListRow(
                    title: item.title,
                    icon: item.icon,
                    color: const Color(0xFFFFC322),
                    onTap: item.title == 'Переводы баланса' ? onOpenTransfers : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransfersOverlay extends StatelessWidget {
  const TransfersOverlay({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(title: 'Переводы баланса', onBack: onBack),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
              child: _SearchField(hintText: 'Поиск'),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: transferOptions.length,
                itemBuilder: (context, index) {
                  final item = transferOptions[index];
                  return _OverlayListRow(
                    title: item.title,
                    icon: item.icon,
                    color: item.color,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsOverlay extends StatefulWidget {
  const SettingsOverlay({
    super.key,
    required this.appPrefs,
    required this.phoneNumber,
    required this.city,
    required this.walletState,
    required this.rideAccessEnabled,
    required this.trialRidesRemaining,
    required this.accessTelegram,
    required this.telegramChatId,
    required this.telegramBotUsername,
    required this.onBack,
    required this.onLogout,
    required this.onOpenCards,
    required this.onOpenCity,
    required this.onRequestAccess,
    required this.onRequestTelegramBind,
  });

  final AppPrefsController appPrefs;
  final String phoneNumber;
  final String city;
  final WalletState walletState;
  final bool rideAccessEnabled;
  final int trialRidesRemaining;
  final String accessTelegram;
  final String telegramChatId;
  final String telegramBotUsername;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final VoidCallback onOpenCards;
  final VoidCallback onOpenCity;
  final RequestRideAccessCallback onRequestAccess;
  final RequestTelegramBindCallback onRequestTelegramBind;

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  bool _requesting = false;
  bool _bindingTelegram = false;
  String _message = '';
  TelegramBindDto? _telegramBind;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _appVersion = '${info.version}+${info.buildNumber}';
        });
      }
    });
  }

  Future<void> _showHistory() async {
    final items = await ActivityHistory.listEntries();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final s = widget.appPrefs.strings;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.historyTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ActivityHistory.clear();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(s.historyClear),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(s.historyEmpty))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = items[i];
                          return ListTile(
                            title: Text(e.title),
                            subtitle: Text('${e.subtitle}\n${e.atIso}'),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestAccess() async {
    if (_requesting) {
      return;
    }
    setState(() {
      _requesting = true;
      _message = '';
    });
    try {
      final message = await widget.onRequestAccess();
      if (!mounted) {
        return;
      }
      setState(() {
        _requesting = false;
        _message = message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requesting = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _requestTelegramBind() async {
    if (_bindingTelegram) {
      return;
    }
    setState(() {
      _bindingTelegram = true;
      _message = '';
    });
    try {
      final bind = await widget.onRequestTelegramBind();
      if (!mounted) {
        return;
      }
      setState(() {
        _bindingTelegram = false;
        _telegramBind = bind;
        _message = 'Откройте Telegram и отправьте команду из карточки ниже.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bindingTelegram = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _openTelegramValue(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Invalid Telegram link.';
      });
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      setState(() {
        _message = 'Could not open Telegram. Please copy the link manually.';
      });
    }
  }

  Future<void> _copyTelegramValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано в буфер обмена')),
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
            children: [
              _PageHeader(title: 'Настройки', onBack: widget.onBack),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.phoneNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.city,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Баланс: ${formatBalance(widget.walletState.balance)} ₸',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.rideAccessEnabled
                            ? const Color(0xFFD8F5DE)
                            : const Color(0xFFFFF3D8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.rideAccessEnabled
                            ? 'Доступ к поездкам активен'
                            : 'Осталось пробных поездок: ${widget.trialRidesRemaining}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.rideAccessEnabled
                              ? const Color(0xFF1D6A2A)
                              : const Color(0xFF6B4D00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _OverlayListRow(
                title: 'Мой город',
                icon: Icons.location_on_outlined,
                color: const Color(0xFFE7EDFF),
                onTap: widget.onOpenCity,
              ),
              _OverlayListRow(
                title: 'Мои карты',
                icon: Icons.credit_card_rounded,
                color: const Color(0xFFE7EDFF),
                onTap: widget.onOpenCards,
              ),
              _OverlayListRow(
                title: _bindingTelegram
                    ? 'Готовим Telegram-ссылку...'
                    : (widget.telegramChatId.isNotEmpty
                          ? 'Перепривязать Telegram'
                          : 'Привязать Telegram'),
                icon: Icons.send_rounded,
                color: const Color(0xFFEAF3FF),
                iconColor: AppColors.primaryBlueDark,
                onTap: _bindingTelegram ? null : _requestTelegramBind,
              ),
              if (!widget.rideAccessEnabled)
                _OverlayListRow(
                  title: _requesting
                      ? 'Отправляем запрос...'
                      : 'Запросить доступ к поездкам',
                  icon: Icons.lock_open_rounded,
                  color: const Color(0xFFFFF3D8),
                  iconColor: const Color(0xFF6B4D00),
                  onTap: _requesting ? null : _requestAccess,
                ),
              const SizedBox(height: 10),
              _InfoCard(
                message: widget.telegramChatId.isNotEmpty
                    ? 'Telegram подключен. Коды входа придут в этот чат.'
                    : (widget.telegramBotUsername.isNotEmpty
                          ? 'Сначала откройте ${widget.telegramBotUsername} и свяжите чат.'
                          : 'Сначала свяжите Telegram-чат, чтобы бот мог присылать коды.'),
                background: Colors.white,
                color: AppColors.textSecondary,
                bordered: true,
              ),
              if (_telegramBind != null) ...[
                const SizedBox(height: 12),
                _TelegramBindInfoCard(
                  bind: _telegramBind!,
                  onCopy: _copyTelegramValue,
                  onOpen: _openTelegramValue,
                ),
              ],
              const SizedBox(height: 10),
              _InfoCard(
                message: 'Для активации поездок пишите ${widget.accessTelegram}.',
                background: Colors.white,
                color: AppColors.textSecondary,
                bordered: true,
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  message: _message,
                  background: const Color(0xFFE9F1FF),
                  color: AppColors.primaryBlueDark,
                ),
              ],
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: widget.appPrefs,
                builder: (context, _) {
                  final s = widget.appPrefs.strings;
                  final lang = widget.appPrefs.language;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.languageLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<AppLanguage>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: AppLanguage.kk,
                              label: Text('Қазақша', style: TextStyle(fontSize: 13 * widget.appPrefs.textScale)),
                            ),
                            ButtonSegment(
                              value: AppLanguage.ru,
                              label: Text('Русский', style: TextStyle(fontSize: 13 * widget.appPrefs.textScale)),
                            ),
                            ButtonSegment(
                              value: AppLanguage.en,
                              label: Text('English', style: TextStyle(fontSize: 13 * widget.appPrefs.textScale)),
                            ),
                          ],
                          selected: {lang},
                          onSelectionChanged: (next) {
                            if (next.isEmpty) {
                              return;
                            }
                            widget.appPrefs.setLanguage(next.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.textSizeLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(value: 'normal', label: Text(s.textSizeNormal)),
                            ButtonSegment(value: 'large', label: Text(s.textSizeLarge)),
                            ButtonSegment(value: 'xlarge', label: Text(s.textSizeExtraLarge)),
                          ],
                          selected: {widget.appPrefs.textScaleBucket},
                          onSelectionChanged: (next) {
                            if (next.isEmpty) {
                              return;
                            }
                            widget.appPrefs.setTextScaleBucket(next.first);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _OverlayListRow(
                title: widget.appPrefs.strings.historyTitle,
                icon: Icons.history_rounded,
                color: const Color(0xFFF0F4FF),
                onTap: _showHistory,
              ),
              if (_appVersion.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.appPrefs.strings.appVersionLine(_appVersion),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: widget.onLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE0E0),
                    foregroundColor: const Color(0xFFB32828),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Выйти',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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

class _CitySelector extends StatelessWidget {
  const _CitySelector({required this.city, required this.onTap});

  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.primaryBlueDark,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                city,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.primaryBlueDark,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneEntryCard extends StatefulWidget {
  const _PhoneEntryCard({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_PhoneEntryCard> createState() => _PhoneEntryCardState();
}

class _PhoneEntryCardState extends State<_PhoneEntryCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    super.dispose();
  }

  void _onControllerTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Страна и номер телефона',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('🇰🇿', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                const Text(
                  '+7',
                  style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
                ),
                Container(
                  width: 1,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: const Color(0xFF3C3C3C),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: false,
                    ),
                    textInputAction: TextInputAction.done,
                    minLines: 1,
                    maxLines: 1,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    cursorColor: AppColors.primaryBlue,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: widget.onChanged,
                    decoration: const InputDecoration(
                      hintText: 'Введите номер телефона',
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 20),
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.text.isEmpty
                      ? null
                      : () {
                          controller.clear();
                          widget.onChanged('');
                        },
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFF494949),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeEntryCard extends StatelessWidget {
  const _CodeEntryCard({
    required this.phoneNumber,
    required this.controller,
    required this.onChanged,
    required this.onChangePhone,
  });

  final String phoneNumber;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onChangePhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Код подтверждения',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            phoneNumber,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.password_rounded,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: onChanged,
                    decoration: const InputDecoration(
                      hintText: 'Введите код',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onChangePhone,
                  child: const Text('Изменить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
            ),
          if (title.isNotEmpty)
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    this.controller,
    required this.hintText,
    this.leading = Icons.search_rounded,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String hintText;
  final IconData leading;
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
      child: Row(
        children: [
          Icon(leading, color: AppColors.textSecondary, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayListRow extends StatelessWidget {
  const _OverlayListRow({
    required this.title,
    required this.icon,
    required this.color,
    this.iconColor = AppColors.primaryBlueDark,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 30),
          ],
        ),
      ),
    );
  }
}

class _RouteItemRow extends StatelessWidget {
  const _RouteItemRow({
    required this.title,
    required this.subtitle,
    required this.showDivider,
  });

  final String title;
  final String subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuListTile extends StatelessWidget {
  const _MenuListTile({
    required this.data,
    required this.showDivider,
    this.onTap,
  });

  final MenuItemData data;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: const BoxDecoration(
                color: AppColors.accentYellow,
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (data.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 34,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareBubble extends StatelessWidget {
  const _ShareBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.ios_share_rounded, color: AppColors.banner),
    );
  }
}

class _TelegramBindInfoCard extends StatelessWidget {
  const _TelegramBindInfoCard({
    required this.bind,
    required this.onCopy,
    required this.onOpen,
  });

  final TelegramBindDto bind;
  final Future<void> Function(String value) onCopy;
  final Future<void> Function(String value) onOpen;

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if (bind.botUsername.isNotEmpty) 'Бот: ${bind.botUsername}',
      'Команда: ${bind.command}',
      if (bind.deepLink.isNotEmpty) 'Ссылка: ${bind.deepLink}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F1FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bind.instructions,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.primaryBlueDark,
            ),
          ),
          const SizedBox(height: 12),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (bind.deepLink.isNotEmpty)
                OutlinedButton(
                  onPressed: () {
                    onOpen(bind.deepLink);
                  },
                  child: const Text('Open Telegram'),
                ),
              OutlinedButton(
                onPressed: () {
                  onCopy(bind.command);
                },
                child: const Text('Копировать команду'),
              ),
              if (bind.deepLink.isNotEmpty)
                OutlinedButton(
                  onPressed: () {
                    onCopy(bind.deepLink);
                  },
                  child: const Text('Копировать ссылку'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.message,
    this.background = AppColors.surfaceMuted,
    this.color = AppColors.textSecondary,
    this.bordered = false,
  });

  final String message;
  final Color background;
  final Color color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: bordered ? Border.all(color: AppColors.border) : null,
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 14, height: 1.35, color: color),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: enabled && !busy ? onTap : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              enabled ? AppColors.primaryBlue : const Color(0xFFC8C8C8),
          disabledBackgroundColor: const Color(0xFFC8C8C8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 4,
          width: 82,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFEFF2FC);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.42)
      ..lineTo(size.width * 0.12, size.height * 0.42)
      ..lineTo(size.width * 0.12, size.height * 0.18)
      ..lineTo(size.width * 0.22, size.height * 0.18)
      ..lineTo(size.width * 0.22, size.height * 0.34)
      ..lineTo(size.width * 0.34, size.height * 0.34)
      ..lineTo(size.width * 0.34, size.height * 0.58)
      ..lineTo(size.width * 0.46, size.height * 0.58)
      ..lineTo(size.width * 0.46, size.height * 0.24)
      ..lineTo(size.width * 0.58, size.height * 0.24)
      ..lineTo(size.width * 0.58, size.height * 0.64)
      ..lineTo(size.width * 0.68, size.height * 0.64)
      ..lineTo(size.width * 0.68, size.height * 0.12)
      ..lineTo(size.width * 0.84, size.height * 0.12)
      ..lineTo(size.width * 0.84, size.height * 0.44)
      ..lineTo(size.width * 0.94, size.height * 0.44)
      ..lineTo(size.width * 0.94, size.height * 0.30)
      ..lineTo(size.width, size.height * 0.30)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
