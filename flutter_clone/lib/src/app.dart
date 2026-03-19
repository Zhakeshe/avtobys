import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_overlay_screens.dart';
import 'data.dart';
import 'theme.dart';
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
  String? _phoneNumber;
  String? _selectedCity;
  AppOverlay? _overlay;
  WalletState _walletState = WalletState.empty();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final phoneNumber = preferences.getString('phone_number');
    final selectedCity = preferences.getString('selected_city');
    final walletState = phoneNumber == null || phoneNumber.isEmpty
        ? WalletState.empty()
        : await WalletStore.load(phoneNumber);

    if (!mounted) {
      return;
    }

    setState(() {
      _phoneNumber = phoneNumber;
      _selectedCity = selectedCity;
      _walletState = walletState;
      _overlay = phoneNumber == null || phoneNumber.isEmpty
          ? AppOverlay.login
          : (selectedCity == null || selectedCity.isEmpty
                ? AppOverlay.cityPicker
                : null);
      _isLoading = false;
    });
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

  Future<void> _savePhoneNumber(String phoneNumber) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('phone_number', phoneNumber);
    final walletState = await WalletStore.load(phoneNumber);

    if (!mounted) {
      return;
    }

    setState(() {
      _phoneNumber = phoneNumber;
      _walletState = walletState;
      _overlay = (_selectedCity == null || _selectedCity!.isEmpty)
          ? AppOverlay.cityPicker
          : null;
    });
  }

  Future<void> _saveCity(String city) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('selected_city', city);

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
    await preferences.remove('phone_number');

    if (!mounted) {
      return;
    }

    setState(() {
      _phoneNumber = null;
      _selectedCity = null;
      _walletState = WalletState.empty();
      _overlay = AppOverlay.login;
      _selectedTab = RootTab.home;
      _lastContentTab = RootTab.home;
    });
  }

  Future<void> _persistWallet(WalletState walletState) async {
    final phoneNumber = _phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return;
    }

    await WalletStore.save(phoneNumber, walletState);

    if (!mounted) {
      return;
    }

    setState(() {
      _walletState = walletState;
    });
  }

  Future<void> _addCard(String holderName, String number) async {
    final cards = [
      ..._walletState.cards,
      WalletCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        holderName: holderName,
        number: number,
      ),
    ];

    final walletState = _walletState.copyWith(
      cards: cards,
      activeCardId: cards.last.id,
    );
    await _persistWallet(walletState);
  }

  Future<void> _setActiveCard(String cardId) async {
    await _persistWallet(_walletState.copyWith(activeCardId: cardId));
  }

  Future<void> _topUpBalance(double amount) async {
    final walletState = _walletState.copyWith(
      balance: _walletState.balance + amount,
    );
    await _persistWallet(walletState);

    if (!mounted) {
      return;
    }

    setState(() {
      _overlay = null;
    });
  }

  Future<void> _chargeBalance(double amount) async {
    final nextBalance = math.max(0, _walletState.balance - amount).toDouble();
    await _persistWallet(_walletState.copyWith(balance: nextBalance));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Avtobys Clone',
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
      return QrScannerScreen(onClose: () => _selectTab(_lastContentTab));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(bottom: false, child: _buildScreen()),
          ),
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
    final city = _selectedCity ?? cityOptions[2];
    final phoneNumber = _phoneNumber ?? '+7 700-255-56-19';

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
          bankCardSubtitle:
              _walletState.activeCard?.maskedNumber ?? 'Добавить карту',
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
    final city = _selectedCity ?? cityOptions[2];
    final phoneNumber = _phoneNumber ?? '+7 700-255-56-19';

    switch (_overlay!) {
      case AppOverlay.login:
        return LoginEntryScreen(onContinue: _savePhoneNumber);
      case AppOverlay.cityPicker:
        return CityPickerOverlay(
          selectedCity: city,
          onSelected: _saveCity,
          onBack: _closeOverlay,
          showBack: _phoneNumber != null,
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
          walletBalance: _walletState.balance,
          onBack: _closeOverlay,
          onPaid: _chargeBalance,
        );
      case AppOverlay.plate:
        return TransportPaymentOverlay(
          mode: TransportSearchMode.plate,
          phoneNumber: phoneNumber,
          cityName: city,
          walletBalance: _walletState.balance,
          onBack: _closeOverlay,
          onPaid: _chargeBalance,
        );
      case AppOverlay.tickets:
        return TicketsOverlay(phoneNumber: phoneNumber, onBack: _closeOverlay);
      case AppOverlay.settings:
        return SettingsOverlay(
          phoneNumber: phoneNumber,
          city: city,
          walletState: _walletState,
          onBack: _closeOverlay,
          onLogout: _logout,
          onOpenCards: () => _openOverlay(AppOverlay.cards),
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
          currentBalance: _walletState.balance,
          onBack: _closeOverlay,
          onTopUp: _topUpBalance,
        );
    }
  }
}

class HomeScreenLegacy extends StatelessWidget {
  const HomeScreenLegacy({super.key});

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
            const _WalletSection(),
            const SizedBox(height: 16),
            const _ServiceGrid(),
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
    this.walletState = const WalletState(balance: 0, cards: []),
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
                SizedBox(width: 12),
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

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 140),
      child: Column(
        children: [
          const _SelectorField(
            icon: Icons.location_on_outlined,
            value: 'Актау',
            accent: AppColors.primaryBlueDark,
            trailing: Icons.keyboard_arrow_down_rounded,
          ),
          const SizedBox(height: 16),
          const _SelectorField(
            icon: Icons.search_rounded,
            value: 'Поиск',
            trailing: null,
          ),
          const SizedBox(height: 20),
          Column(
            children: routeItems
                .map(
                  (route) => _RouteRow(
                    data: route,
                    showDivider: route != routeItems.last,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.onOpenNotifications});

  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 140),
      child: Column(
        children: [
          ...settingsMenuItems.map(
            (item) => _MenuRow(
              data: item,
              showDivider: item != settingsMenuItems.last,
              onTap: item.title == 'Уведомления' ? onOpenNotifications : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.banner,
                borderRadius: BorderRadius.circular(22),
                boxShadow: appCardShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Row(
                children: [
                  const Expanded(
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
                  Container(
                    height: 56,
                    width: 56,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.ios_share_rounded,
                      color: AppColors.banner,
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

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: ScannerBackdropPainter()),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: 0.30),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 34),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ScannerActionButton(
                          icon: Icons.flash_on_rounded,
                          onTap: () {},
                        ),
                        _ScannerActionButton(
                          icon: Icons.close_rounded,
                          onTap: onClose,
                        ),
                      ],
                    ),
                    const Spacer(flex: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: const ScannerFrame(),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.banner.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Наведите камеру на QR-код',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFFD7DCEC),
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.banner.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: appCardShadow,
                      ),
                      padding: const EdgeInsets.all(24),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Кошелек',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '0,00 ₸',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            '+7 (700) 255-56-19  Стандарт',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFD7DCEC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _TopOfferArt(icon: icon),
        ],
      ),
    );
  }
}

class _TopOfferArt extends StatelessWidget {
  const _TopOfferArt({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 98,
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFCF49), Color(0xFFFFB113)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 46,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: 20,
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: -2,
            bottom: 6,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFE7A8),
                border: Border.all(color: const Color(0xFFFFD257), width: 2),
              ),
              child: const Icon(
                Icons.percent_rounded,
                size: 16,
                color: Color(0xFFE29B00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletCardLegacy extends StatelessWidget {
  const WalletCardLegacy({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E74FF), Color(0xFF1E54F5)],
        ),
        boxShadow: appCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: const CustomPaint(painter: _WalletPatternPainter()),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Баланс',
                style: TextStyle(fontSize: 15, color: Color(0xFFE6EBFF)),
              ),
              SizedBox(height: 8),
              Text(
                '0,00 ₸',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Стандарт',
                style: TextStyle(fontSize: 16, color: Color(0xFFD7DEFF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddCardTileLegacy extends StatelessWidget {
  const AddCardTileLegacy({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E8F0), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFE2E6EF)),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppColors.textSecondary,
                size: 28,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Добавить\nкарту',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.walletState});

  final WalletState walletState;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E74FF), Color(0xFF1E54F5)],
        ),
        boxShadow: appCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: const CustomPaint(painter: _WalletPatternPainter()),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Баланс',
                style: TextStyle(fontSize: 15, color: Color(0xFFE6EBFF)),
              ),
              SizedBox(height: 6),
              Text(
                '0,00 ₸',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Стандарт',
                style: TextStyle(fontSize: 16, color: Color(0xFFD7DEFF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AddCardTile extends StatelessWidget {
  const _AddCardTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E8F0), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFE2E6EF)),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppColors.textSecondary,
                size: 28,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Добавить\nкарту',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EBF2)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7FF),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: AppColors.primaryBlue, size: 24),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: appCardShadow,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: serviceItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.06,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) => _ServiceTile(
          data: serviceItems[index],
          onTap: switch (serviceItems[index].id) {
            'payments' => onOpenPayments,
            'tickets' => onOpenTickets,
            'transfers' => onOpenTransfers,
            _ => null,
          },
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

class _WalletPatternPainter extends CustomPainter {
  const _WalletPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.07),
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    for (double y = 16; y < size.height; y += 18) {
      for (double x = size.width * 0.48; x < size.width + 24; x += 44) {
        textPainter.text = TextSpan(text: '0101', style: style);
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.icon,
    required this.value,
    this.trailing,
    this.accent = AppColors.textSecondary,
  });

  final IconData icon;
  final String value;
  final IconData? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: accent == AppColors.primaryBlueDark
                    ? AppColors.primaryBlueDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (trailing != null)
            Icon(trailing, color: AppColors.textSecondary, size: 28),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.data, required this.showDivider});

  final RouteItemData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
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
                  data.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.data, required this.showDivider, this.onTap});

  final MenuItemData data;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
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

class _ScannerActionButton extends StatelessWidget {
  const _ScannerActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black54, size: 24),
      ),
    );
  }
}

class ScannerFrame extends StatelessWidget {
  const ScannerFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          ..._buildCorners(),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const lineColor = AppColors.primaryBlue;
    const lineThickness = 6.0;
    const arm = 38.0;
    return [
      Positioned(
        left: 0,
        top: 0,
        child: Container(
          height: lineThickness,
          width: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        child: Container(
          width: lineThickness,
          height: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: Container(
          height: lineThickness,
          width: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: Container(
          width: lineThickness,
          height: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      Positioned(
        left: 0,
        bottom: 0,
        child: Container(
          height: lineThickness,
          width: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      Positioned(
        left: 0,
        bottom: 0,
        child: Container(
          width: lineThickness,
          height: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          height: lineThickness,
          width: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: lineThickness,
          height: arm,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ];
  }
}

class ScannerBackdropPainter extends CustomPainter {
  const ScannerBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7E7E7E), Color(0xFF3F3F3F)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final random = math.Random(27);
    final tileWidth = size.width / 4.8;
    final tileHeight = tileWidth * 1.15;

    for (
      double y = -tileHeight;
      y < size.height + tileHeight;
      y += tileHeight * 0.92
    ) {
      for (
        double x = -tileWidth;
        x < size.width + tileWidth;
        x += tileWidth * 0.94
      ) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + random.nextDouble() * 4,
            y + random.nextDouble() * 5,
            tileWidth - 5,
            tileHeight - 5,
          ),
          const Radius.circular(4),
        );
        final shade = Color.lerp(
          const Color(0xFF565656),
          const Color(0xFF8F8F8F),
          random.nextDouble(),
        )!;
        canvas.drawRRect(
          rect,
          Paint()
            ..color = shade.withValues(
              alpha: 0.38 + random.nextDouble() * 0.20,
            ),
        );

        if (random.nextDouble() > 0.85) {
          final highlight = Rect.fromLTWH(
            x + tileWidth * 0.32,
            y + tileHeight * 0.24,
            tileWidth * 0.26,
            tileHeight * 0.22,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(highlight, const Radius.circular(8)),
            Paint()..color = Colors.white.withValues(alpha: 0.20),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
