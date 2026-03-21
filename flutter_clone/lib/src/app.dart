import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_overlay_screens.dart';
import 'data.dart';
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

  Future<void> _addCard(String holderName, String number, String cardType) async {
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _config.appName,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
        dividerColor: AppColors.border,
      ),
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
            )
          : _buildRootContent(),
    );
  }

  Widget _buildRootContent() {
    if (_overlay != null) {
      return _buildOverlayScreen();
    }

    if (_selectedTab == RootTab.qr) {
      return TransportPaymentOverlay(
        mode: TransportSearchMode.qr,
        phoneNumber: _phoneNumber,
        cityName: _currentCity,
        walletState: _walletState,
        rideAccessEnabled: _user?.rideAccessEnabled ?? false,
        trialRidesRemaining: _user?.trialRidesRemaining ?? _config.trialRideCount,
        accessTelegram: _config.accessRequestTelegram,
        onBack: () => _selectTab(_lastContentTab),
        onSessionRefresh: _refreshSession,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: SafeArea(bottom: false, child: _buildScreen())),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomTabBar(
              selectedTab: _selectedTab,
              onTabSelected: _selectTab,
              onCenterTap: () => _selectTab(RootTab.qr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    final city = _currentCity;
    final phoneNumber =
        _phoneNumber.isNotEmpty ? _phoneNumber : '+7 700-255-56-19';
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
          onOpenQr: () => _selectTab(RootTab.qr),
          onOpenBluetooth: () => _openOverlay(AppOverlay.bluetooth),
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
    final phoneNumber =
        _phoneNumber.isNotEmpty ? _phoneNumber : '+7 700-255-56-19';

    switch (_overlay!) {
      case AppOverlay.login:
        return LoginEntryScreen(
          onRequestCode: _requestCode,
          onVerifyCode: _verifyCode,
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
          trialRidesRemaining: _user?.trialRidesRemaining ?? _config.trialRideCount,
          accessTelegram: _config.accessRequestTelegram,
          onBack: _closeOverlay,
          onSessionRefresh: _refreshSession,
        );
      case AppOverlay.plate:
        return TransportPaymentOverlay(
          mode: TransportSearchMode.plate,
          phoneNumber: phoneNumber,
          cityName: city,
          walletState: _walletState,
          rideAccessEnabled: _user?.rideAccessEnabled ?? false,
          trialRidesRemaining: _user?.trialRidesRemaining ?? _config.trialRideCount,
          accessTelegram: _config.accessRequestTelegram,
          onBack: _closeOverlay,
          onSessionRefresh: _refreshSession,
        );
      case AppOverlay.tickets:
        return TicketsOverlay(onBack: _closeOverlay);
      case AppOverlay.settings:
        return SettingsOverlay(
          phoneNumber: phoneNumber,
          city: city,
          walletState: _walletState,
          rideAccessEnabled: _user?.rideAccessEnabled ?? false,
          trialRidesRemaining: _user?.trialRidesRemaining ?? _config.trialRideCount,
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
    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopOfferCard(
              title: 'Оформить\nльготный тариф',
              icon: Icons.discount_outlined,
            ),
            const SizedBox(height: 14),
            _WalletSection(
              phoneNumber: phoneNumber,
              walletState: walletState,
              onOpenQr: onOpenQr,
              onOpenBluetooth: onOpenBluetooth,
              onOpenPlate: onOpenPlate,
              onOpenCards: onOpenCards,
              onOpenTopUp: onOpenTopUp,
            ),
            const SizedBox(height: 16),
            _ServiceGrid(
              onOpenPayments: onOpenPayments,
              onOpenTransfers: onOpenTransfers,
              onOpenTickets: onOpenTickets,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: promoCards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: index == 0 ? 262 : 206,
                  child: _PromoCard(data: promoCards[index]),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Предложения',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: offerCards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _OfferCard(data: offerCards[index]),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: appCardShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: WalletOverviewCard(
                    walletState: walletState,
                    onTap: onOpenTopUp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: WalletCardsTile(
                    walletState: walletState,
                    onTap: onOpenCards,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
      ),
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
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 112,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 84,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: appCardShadow,
                ),
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomTabItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Avtobys',
                        isSelected: selectedTab == RootTab.home,
                        onTap: () => onTabSelected(RootTab.home),
                      ),
                    ),
                    Expanded(
                      child: _BottomTabItem(
                        icon: Icons.route_outlined,
                        label: 'Маршруты',
                        isSelected: selectedTab == RootTab.routes,
                        onTap: () => onTabSelected(RootTab.routes),
                      ),
                    ),
                    const SizedBox(width: 84),
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
              ),
            ),
            GestureDetector(
              onTap: onCenterTap,
              child: Container(
                height: 76,
                width: 76,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  boxShadow: appCardShadow,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 34,
                  color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: appCardShadow,
      ),
      child: Column(
        children: serviceItems
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(
                  bottom: item == serviceItems.last ? 0 : 12,
                ),
                child: _ServiceTile(
                  data: item,
                  onTap: switch (item.id) {
                    'payments' => onOpenPayments,
                    'tickets' => onOpenTickets,
                    'transfers' => onOpenTransfers,
                    _ => null,
                  },
                ),
              ),
            )
            .toList(),
      ),
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
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4E8F0)),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(data.icon, color: AppColors.primaryBlue, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              data.title,
              style: const TextStyle(
                fontSize: 15,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFDFF),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: data.color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                data.icon,
                color: AppColors.primaryBlueDark,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF0F2F8)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD36C), Color(0xFFFABE0C)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 12,
                  right: 14,
                  child: Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 38,
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    height: 16,
                    width: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: _PromoArtwork(data: data),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 132,
              child: Text(
                data.title,
                style: const TextStyle(
                  fontSize: 15,
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

class _PromoArtwork extends StatelessWidget {
  const _PromoArtwork({required this.data});

  final PromoCardData data;

  @override
  Widget build(BuildContext context) {
    final isYellow = data.background == const Color(0xFFFABE0C);
    return SizedBox(
      width: isYellow ? 118 : 90,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: isYellow
            ? [
                Positioned(
                  right: 36,
                  bottom: 4,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9A0B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 0,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD8A3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: 34,
                  child: Container(
                    width: 48,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  right: 32,
                  bottom: 12,
                  child: Icon(data.icon, color: Colors.white, size: 26),
                ),
              ]
            : [
                Positioned(
                  right: 0,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  child: Icon(data.icon, color: Colors.white, size: 34),
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
    return Container(
      width: 246,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.colors,
        ),
        boxShadow: appCardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -10,
            child: Container(
              width: 148,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(58),
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(data.icon, color: Colors.white, size: 27),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFF3EFFF),
                    ),
                  ),
                ],
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
    final color = isSelected ? AppColors.primaryBlue : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
