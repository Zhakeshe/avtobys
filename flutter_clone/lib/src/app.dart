import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_overlay_screens.dart';
import 'app_prefs.dart';
import 'pwa_context.dart';
import 'pwa_install.dart';
import 'data.dart';
import 'l10n/app_strings.dart';
import 'qr_scan_payment_screen.dart';
import 'theme.dart';
import 'transport_api.dart';
import 'transport_overlays.dart';
import 'wallet_components.dart';
import 'wallet_overlays.dart';
import 'wallet_store.dart';

enum RootTab { home, routes, qr, notifications, menu }

class AvtobysCloneApp extends StatefulWidget {
  const AvtobysCloneApp({super.key});

  @override
  State<AvtobysCloneApp> createState() => _AvtobysCloneAppState();
}

class _AvtobysCloneAppState extends State<AvtobysCloneApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final AppPrefsController _prefs = AppPrefsController();
  RootTab _selectedTab = RootTab.home;
  RootTab _lastContentTab = RootTab.home;
  bool _isLoading = true;
  String? _sessionToken;
  UserDto? _user;
  String? _selectedCity;
  AppOverlay? _overlay;
  WalletState _walletState = WalletState.empty();
  List<CityDto> _cities = const [];
  PublicConfigDto _config = const PublicConfigDto(
    appName: 'Avtobys',
    supportPhone: '',
    supportTelegram: '@aqxrx',
    accessRequestTelegram: '@aqxrx',
    telegramBotUsername: '',
    loginDeliveryMode: 'telegram',
    defaultLanguage: 'Русский',
    shareUrl: '',
    currencySymbol: '₸',
    newUserBonusBalance: 0,
    minimumTopUpAmount: 500,
    maintenanceMode: false,
    trialRideCount: 2,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  String get _phoneNumber => _user?.phoneNumber ?? '';

  String get _currentCity {
    final fallback = _cities.isNotEmpty
        ? _cities.first.name
        : (cityOptions.length > 2 ? cityOptions[2] : 'Актау');
    return _selectedCity ?? _user?.cityName ?? fallback;
  }

  Future<void> _bootstrap() async {
    await _prefs.load();
    final preferences = await SharedPreferences.getInstance();
    final storedToken = preferences.getString('session_token');
    final storedCity = preferences.getString('selected_city');

    PublicConfigDto config = _config;
    List<CityDto> cities = const [];
    try {
      config = await TransportApi.getPublicConfig();
    } catch (_) {}
    try {
      cities = await TransportApi.getCities();
    } catch (_) {}

    AuthSessionDto? session;
    if (storedToken != null && storedToken.isNotEmpty) {
      TransportApi.setSessionToken(storedToken);
      try {
        session = await TransportApi.getAuthSession();
      } catch (_) {
        await preferences.remove('session_token');
        TransportApi.setSessionToken(null);
      }
    }

    final nextCity = _resolveCity(
      storedCity: storedCity,
      sessionCity: session?.user.cityName,
      cities: cities,
    );
    if (nextCity != null && nextCity.isNotEmpty) {
      await preferences.setString('selected_city', nextCity);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _sessionToken = session?.token;
      _user = session?.user;
      _selectedCity = nextCity;
      _walletState = session?.wallet ?? WalletState.empty();
      _cities = cities;
      _config = session?.config ?? config;
      _overlay = session == null
          ? AppOverlay.login
          : (nextCity == null || nextCity.isEmpty
                ? AppOverlay.cityPicker
                : null);
      _isLoading = false;
    });
  }

  String? _resolveCity({
    required String? storedCity,
    required String? sessionCity,
    required List<CityDto> cities,
  }) {
    final names = cities.map((item) => item.name).toSet();
    if (storedCity != null && storedCity.isNotEmpty) {
      if (names.isEmpty || names.contains(storedCity)) {
        return storedCity;
      }
    }
    if (sessionCity != null && sessionCity.isNotEmpty) {
      return sessionCity;
    }
    return cities.isNotEmpty ? cities.first.name : null;
  }

  void _selectTab(RootTab tab) {
    setState(() {
      if (tab == RootTab.qr) {
        _lastContentTab = _selectedTab == RootTab.qr
            ? _lastContentTab
            : _selectedTab;
      } else {
        _lastContentTab = tab;
      }
      _selectedTab = tab;
    });
  }

  bool get _isSecureWebContext {
    if (!kIsWeb) {
      return true;
    }
    final host = Uri.base.host.toLowerCase();
    final isLocalhost = host == 'localhost' || host == '127.0.0.1';
    return Uri.base.scheme == 'https' || isLocalhost;
  }

  void _showRuntimeMessage(String message) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _requireSecureContextForPayment(String modeLabel) {
    if (_isSecureWebContext) {
      return true;
    }
    _showRuntimeMessage(
      'Для $modeLabel нужен HTTPS. Откройте сайт по https://subdomain.',
    );
    return false;
  }

  void _openQrPayment() {
    if (kIsWeb && !_isSecureWebContext) {
      _showRuntimeMessage(
        'Камера в браузере доступна по HTTPS. Ниже можно ввести QR token вручную.',
      );
    }
    _selectTab(RootTab.qr);
  }

  void _openBluetoothPayment() {
    if (!_requireSecureContextForPayment('Bluetooth оплаты')) {
      return;
    }
    _openOverlay(AppOverlay.bluetooth);
  }

  void _openOverlay(AppOverlay overlay) {
    setState(() {
      _overlay = overlay;
    });
  }

  void _closeOverlay() {
    setState(() {
      _overlay = null;
    });
  }

  Future<AuthCodeRequestDto> _requestCode(String phoneNumber) {
    return TransportApi.requestAuthCode(
      phoneNumber: phoneNumber,
      cityName: _selectedCity,
    );
  }

  Future<void> _verifyCode(String phoneNumber, String code) async {
    final session = await TransportApi.verifyAuthCode(
      phoneNumber: phoneNumber,
      code: code,
      cityName: _selectedCity,
    );
    await _applySession(session);
  }

  Future<void> _applySession(AuthSessionDto session) async {
    final preferences = await SharedPreferences.getInstance();
    final nextCity = _resolveCity(
      storedCity: _selectedCity,
      sessionCity: session.user.cityName,
      cities: _cities,
    );
    TransportApi.setSessionToken(session.token);
    await preferences.setString('session_token', session.token);
    if (nextCity != null && nextCity.isNotEmpty) {
      await preferences.setString('selected_city', nextCity);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _sessionToken = session.token;
      _user = session.user;
      _selectedCity = nextCity;
      _walletState = session.wallet;
      _config = session.config;
      _overlay = nextCity == null || nextCity.isEmpty
          ? AppOverlay.cityPicker
          : null;
    });
  }

  Future<void> _saveCity(String city) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('selected_city', city);
    if (_user != null) {
      final updatedUser = await TransportApi.updateProfile(cityName: city);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCity = city;
        _user = updatedUser;
        _overlay = null;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCity = city;
      _overlay = null;
    });
  }

  Future<void> _logout() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      await TransportApi.logoutAuth();
    } catch (_) {}
    await preferences.remove('session_token');
    TransportApi.setSessionToken(null);

    if (!mounted) {
      return;
    }
    setState(() {
      _sessionToken = null;
      _user = null;
      _selectedCity = null;
      _walletState = WalletState.empty();
      _overlay = AppOverlay.login;
      _selectedTab = RootTab.home;
      _lastContentTab = RootTab.home;
    });
  }

  Future<void> _refreshSession() async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      return;
    }
    TransportApi.setSessionToken(token);
    final session = await TransportApi.getAuthSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _user = session.user;
      _walletState = session.wallet;
      _config = session.config;
      _selectedCity = _resolveCity(
        storedCity: _selectedCity,
        sessionCity: session.user.cityName,
        cities: _cities,
      );
    });
  }

  Future<void> _addCard(
    String holderName,
    String number,
    String cardType,
  ) async {
    await TransportApi.addWalletCard(
      holderName: holderName,
      number: number,
      cardType: cardType,
    );
    final wallet = await TransportApi.getWallet();
    if (!mounted) {
      return;
    }
    setState(() {
      _walletState = wallet;
    });
  }

  Future<void> _setActiveCard(String cardId) async {
    await TransportApi.activateWalletCard(cardId);
    final wallet = await TransportApi.getWallet();
    if (!mounted) {
      return;
    }
    setState(() {
      _walletState = wallet;
    });
  }

  Future<void> _topUpBalance(
    double amount, {
    String targetType = 'wallet',
    String? transportCardId,
  }) async {
    final wallet = await TransportApi.topUpWallet(
      amount: amount,
      cardId: _walletState.activeCard?.id,
      targetType: targetType,
      transportCardId: transportCardId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _walletState = wallet;
      _overlay = null;
    });
  }

  Future<String> _requestRideAccess() async {
    final response = await TransportApi.requestRideAccess(
      phoneNumber: _phoneNumber,
      cityName: _currentCity,
    );
    await _refreshSession();
    return response.message;
  }

  Future<TelegramBindDto> _requestTelegramBind() {
    return TransportApi.createTelegramBindToken(cityName: _currentCity);
  }

  Future<TelegramBindStatusDto> _checkTelegramBind(String phoneNumber) {
    return TransportApi.getTelegramBindStatus(phoneNumber: phoneNumber);
  }

  Locale get _materialLocale {
    return switch (_prefs.language) {
      AppLanguage.kk => const Locale('ru'),
      AppLanguage.ru => const Locale('ru'),
      AppLanguage.en => const Locale('en'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _prefs,
      builder: (context, _) {
        final baseTheme = ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
          dividerColor: AppColors.border,
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: _config.appName,
          scaffoldMessengerKey: _messengerKey,
          locale: _materialLocale,
          supportedLocales: const [
            Locale('en'),
            Locale('ru'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(
              fontSizeFactor: _prefs.textScale,
              fontSizeDelta: 0,
            ),
          ),
          home: _isLoading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryBlue),
                  ),
                )
              : _buildRootContent(),
        );
      },
    );
  }

  Widget _buildRootContent() {
    if (_overlay != null) {
      return _buildOverlayScreen();
    }

    if (_selectedTab == RootTab.qr) {
      final qrPhone = _phoneNumber.isNotEmpty
          ? _phoneNumber
          : '+7 700-255-56-19';
      return QrScanPaymentScreen(
        phoneNumber: qrPhone,
        cityName: _currentCity,
        walletState: _walletState,
        rideAccessEnabled: _user?.rideAccessEnabled ?? false,
        trialRidesRemaining:
            _user?.trialRidesRemaining ?? _config.trialRideCount,
        accessTelegram: _config.accessRequestTelegram,
        onBack: () => _selectTab(_lastContentTab),
        onSessionRefresh: _refreshSession,
        allowSecureCameraContext: _isSecureWebContext,
        uiStrings: _prefs.strings,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb && !isPwaStandaloneMode)
            Material(
              color: const Color(0xFFE8F2FC),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.install_mobile_rounded, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _prefs.strings.pwaTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF0B1F3A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _prefs.strings.pwaBody,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: Color(0xFF4A5C76),
                              ),
                            ),
                            if (defaultTargetPlatform != TargetPlatform.iOS)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () async {
                                    final ok = await triggerPwaInstallPrompt();
                                    if (!context.mounted) {
                                      return;
                                    }
                                    if (ok) {
                                      _showRuntimeMessage(
                                        _prefs.language == AppLanguage.en
                                            ? 'Installation accepted'
                                            : 'Орнату расталды',
                                      );
                                    }
                                  },
                                  child: Text(_prefs.strings.pwaInstallChromeButton),
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
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(bottom: false, child: _buildScreen()),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BottomTabBar(
                    selectedTab: _selectedTab,
                    onTabSelected: _selectTab,
                    onCenterTap: _openQrPayment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    final city = _currentCity;
    final phoneNumber = _phoneNumber.isNotEmpty
        ? _phoneNumber
        : '+7 700-255-56-19';
    final activeCard = _walletState.activeCard;
    final cardSubtitle = activeCard == null
        ? 'Добавить карту'
        : activeCard.isTransport
        ? 'Транспортная ${activeCard.maskedNumber}'
        : activeCard.maskedNumber;

    switch (_selectedTab) {
      case RootTab.home:
        return HomeScreen(
          phoneNumber: phoneNumber,
          walletState: _walletState,
          onOpenQr: _openQrPayment,
          onOpenBluetooth: _openBluetoothPayment,
          onOpenPlate: () => _openOverlay(AppOverlay.plate),
          onOpenPayments: () => _openOverlay(AppOverlay.payments),
          onOpenTransfers: () => _openOverlay(AppOverlay.transfers),
          onOpenTickets: () => _openOverlay(AppOverlay.tickets),
          onOpenCards: () => _openOverlay(AppOverlay.cards),
          onOpenTopUp: () => _openOverlay(AppOverlay.topUp),
        );
      case RootTab.routes:
        return RoutesTabScreen(
          city: city,
          onOpenCity: () => _openOverlay(AppOverlay.cityPicker),
          uiStrings: _prefs.strings,
        );
      case RootTab.notifications:
        return NotificationsScreen(onBack: () => _selectTab(RootTab.menu));
      case RootTab.menu:
        return MenuTabScreen(
          city: city,
          bankCardSubtitle: cardSubtitle,
          onOpenNotifications: () => _selectTab(RootTab.notifications),
          onOpenCity: () => _openOverlay(AppOverlay.cityPicker),
          onOpenSettings: () => _openOverlay(AppOverlay.settings),
          onOpenCards: () => _openOverlay(AppOverlay.cards),
        );
      case RootTab.qr:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverlayScreen() {
    final city = _currentCity;
    final phoneNumber = _phoneNumber.isNotEmpty
        ? _phoneNumber
        : '+7 700-255-56-19';

    switch (_overlay!) {
      case AppOverlay.login:
        return LoginEntryScreen(
          onRequestCode: _requestCode,
          onVerifyCode: _verifyCode,
          onCheckTelegramBind: _checkTelegramBind,
          supportTelegram: _config.accessRequestTelegram,
          initialPhoneNumber: _phoneNumber,
        );
      case AppOverlay.cityPicker:
        return CityPickerOverlay(
          selectedCity: city,
          cities: _cities.isNotEmpty
              ? _cities.map((item) => item.name).toList()
              : cityOptions,
          onSelected: _saveCity,
          onBack: _closeOverlay,
          showBack: _user != null,
        );
      case AppOverlay.payments:
        return PaymentsOverlay(
          onBack: _closeOverlay,
          onOpenTransfers: () => _openOverlay(AppOverlay.transfers),
        );
      case AppOverlay.transfers:
        return TransfersOverlay(onBack: _closeOverlay);
      case AppOverlay.bluetooth:
        return TransportPaymentOverlay(
          mode: TransportSearchMode.bluetooth,
          phoneNumber: phoneNumber,
          cityName: city,
          walletState: _walletState,
          rideAccessEnabled: _user?.rideAccessEnabled ?? false,
          trialRidesRemaining:
              _user?.trialRidesRemaining ?? _config.trialRideCount,
          accessTelegram: _config.accessRequestTelegram,
          onBack: _closeOverlay,
          onSessionRefresh: _refreshSession,
          uiStrings: _prefs.strings,
        );
      case AppOverlay.plate:
        return TransportPaymentOverlay(
          mode: TransportSearchMode.plate,
          phoneNumber: phoneNumber,
          cityName: city,
          walletState: _walletState,
          rideAccessEnabled: _user?.rideAccessEnabled ?? false,
          trialRidesRemaining:
              _user?.trialRidesRemaining ?? _config.trialRideCount,
          accessTelegram: _config.accessRequestTelegram,
          onBack: _closeOverlay,
          onSessionRefresh: _refreshSession,
          uiStrings: _prefs.strings,
        );
      case AppOverlay.tickets:
        return TicketsOverlay(
          onBack: _closeOverlay,
          uiStrings: _prefs.strings,
        );
      case AppOverlay.settings:
        return SettingsOverlay(
          appPrefs: _prefs,
          phoneNumber: phoneNumber,
          city: city,
          walletState: _walletState,
          rideAccessEnabled: _user?.rideAccessEnabled ?? false,
          trialRidesRemaining:
              _user?.trialRidesRemaining ?? _config.trialRideCount,
          accessTelegram: _config.accessRequestTelegram,
          telegramChatId: _user?.telegramChatId ?? '',
          telegramBotUsername: _config.telegramBotUsername,
          onBack: _closeOverlay,
          onLogout: _logout,
          onOpenCards: () => _openOverlay(AppOverlay.cards),
          onOpenCity: () => _openOverlay(AppOverlay.cityPicker),
          onRequestAccess: _requestRideAccess,
          onRequestTelegramBind: _requestTelegramBind,
        );
      case AppOverlay.cards:
        return CardsOverlay(
          walletState: _walletState,
          onBack: _closeOverlay,
          onAddCard: _addCard,
          onSetActiveCard: _setActiveCard,
        );
      case AppOverlay.topUp:
        return TopUpOverlay(
          walletState: _walletState,
          minimumAmount: _config.minimumTopUpAmount,
          onBack: _closeOverlay,
          onTopUp: _topUpBalance,
        );
    }
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.phoneNumber,
    required this.walletState,
    required this.onOpenQr,
    required this.onOpenBluetooth,
    required this.onOpenPlate,
    required this.onOpenPayments,
    required this.onOpenTransfers,
    required this.onOpenTickets,
    required this.onOpenCards,
    required this.onOpenTopUp,
  });

  final String phoneNumber;
  final WalletState walletState;
  final VoidCallback onOpenQr;
  final VoidCallback onOpenBluetooth;
  final VoidCallback onOpenPlate;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenTransfers;
  final VoidCallback onOpenTickets;
  final VoidCallback onOpenCards;
  final VoidCallback onOpenTopUp;

  @override
  Widget build(BuildContext context) {
    final contentWidth = MediaQuery.sizeOf(context).width - 40;
    final promoCardWidth = (contentWidth * 0.74).clamp(250.0, 320.0).toDouble();
    final offerCardWidth = ((contentWidth - 12) / 2)
        .clamp(170.0, 240.0)
        .toDouble();
    const offerImageAspectRatio = 400 / 240;
    final offerCardHeight = offerCardWidth / offerImageAspectRatio;

    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TopOfferCard(
              title: 'Оформить льготный тариф',
              icon: Icons.discount_outlined,
            ),
            const SizedBox(height: 18),
            _WalletSection(
              phoneNumber: phoneNumber,
              walletState: walletState,
              onOpenQr: onOpenQr,
              onOpenBluetooth: onOpenBluetooth,
              onOpenPlate: onOpenPlate,
              onOpenCards: onOpenCards,
              onOpenTopUp: onOpenTopUp,
            ),
            const SizedBox(height: 24),
            _ServiceGrid(
              onOpenPayments: onOpenPayments,
              onOpenTransfers: onOpenTransfers,
              onOpenTickets: onOpenTickets,
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: promoCards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: promoCardWidth,
                    child: _PromoCard(data: promoCards[index]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Предложения',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: offerCardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: offerCards.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: offerCardWidth,
                        child: _OfferCard(data: offerCards[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSection extends StatelessWidget {
  const _WalletSection({
    this.phoneNumber = '',
    this.walletState = const WalletState(
      balance: 0,
      cards: [],
      transactions: [],
    ),
    this.onOpenQr,
    this.onOpenBluetooth,
    this.onOpenPlate,
    this.onOpenCards,
    this.onOpenTopUp,
  });

  final String phoneNumber;
  final WalletState walletState;
  final VoidCallback? onOpenQr;
  final VoidCallback? onOpenBluetooth;
  final VoidCallback? onOpenPlate;
  final VoidCallback? onOpenCards;
  final VoidCallback? onOpenTopUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 62,
                child: WalletOverviewCard(
                  walletState: walletState,
                  onTap: onOpenTopUp,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 38,
                child: WalletCardsTile(
                  walletState: walletState,
                  onTap: onOpenCards,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: quickActions
              .map(
                (action) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: action == quickActions.last ? 0 : 12,
                    ),
                    child: _ActionTile(
                      data: action,
                      onTap: switch (action.id) {
                        'qr' => onOpenQr,
                        'bluetooth' => onOpenBluetooth,
                        'plate' => onOpenPlate,
                        _ => null,
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 140),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 28,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Уведомления',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...notificationItems.map(
            (item) => _MenuRow(
              data: item,
              showDivider: item != notificationItems.last,
            ),
          ),
        ],
      ),
    );
  }
}

class BottomTabBar extends StatelessWidget {
  const BottomTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onCenterTap,
  });

  final RootTab selectedTab;
  final ValueChanged<RootTab> onTabSelected;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200.withValues(alpha: 0.65))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.home_filled,
                    label: 'Avtobys',
                    isSelected: selectedTab == RootTab.home,
                    onTap: () => onTabSelected(RootTab.home),
                  ),
                ),
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.route_rounded,
                    label: 'Маршруты',
                    isSelected: selectedTab == RootTab.routes,
                    onTap: () => onTabSelected(RootTab.routes),
                  ),
                ),
                const SizedBox(width: 80),
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Уведомления',
                    isSelected: selectedTab == RootTab.notifications,
                    onTap: () => onTabSelected(RootTab.notifications),
                  ),
                ),
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.menu_rounded,
                    label: 'Меню',
                    isSelected: selectedTab == RootTab.menu,
                    onTap: () => onTabSelected(RootTab.menu),
                  ),
                ),
              ],
            ),
            Positioned(
              top: -22,
              child: GestureDetector(
                onTap: onCenterTap,
                child: Container(
                  height: 68,
                  width: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({
    this.onOpenPayments,
    this.onOpenTransfers,
    this.onOpenTickets,
  });

  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenTransfers;
  final VoidCallback? onOpenTickets;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: serviceItems.map((item) {
            return SizedBox(
              width: itemWidth,
              child: _ServiceTile(
                data: item,
                onTap: switch (item.id) {
                  'payments' => onOpenPayments,
                  'tickets' => onOpenTickets,
                  'transfers' => onOpenTransfers,
                  _ => null,
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.data, this.onTap});

  final QuickActionData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0D1B2A),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F1FF),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: AppColors.primaryBlue, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              data.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.data, this.onTap});

  final ServiceItemData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080D1B2A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                data.icon,
                color: data.color,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopOfferCard extends StatelessWidget {
  const _TopOfferCard({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 80,
            width: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    height: 68,
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFE082), Color(0xFFFFD54F)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 4,
                          width: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          width: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Spacer(),
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            Icons.percent_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.rotate(
                    angle: 0.2,
                    child: Container(
                      height: 40,
                      width: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.data});

  final PromoCardData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            data.image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x45000000),
                  Color(0x18000000),
                  Color(0x00000000),
                ],
                stops: [0, 0.4, 0.8],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 88, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                data.title,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.data});

  final OfferCardData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            data.image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x55000000),
                  Color(0x18000000),
                  Color(0x00000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 56, 14),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                data.title,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.data, required this.showDivider});

  final MenuItemData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryBlue : const Color(0xFF9CA3B0);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isSelected ? 26 : 25),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
