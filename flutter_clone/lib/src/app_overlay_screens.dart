import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'theme.dart';
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

class RoutesTabScreen extends StatelessWidget {
  const RoutesTabScreen({
    super.key,
    required this.city,
    required this.onOpenCity,
  });

  final String city;
  final VoidCallback onOpenCity;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 140),
      child: Column(
        children: [
          InkWell(
            onTap: onOpenCity,
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
          ),
          const SizedBox(height: 16),
          const _SearchField(hintText: 'Поиск'),
          const SizedBox(height: 20),
          ...routeItems.map(
            (item) => _RouteItemRow(
              title: item.title,
              subtitle: item.subtitle,
              showDivider: item != routeItems.last,
            ),
          ),
        ],
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

class LoginEntryScreen extends StatefulWidget {
  const LoginEntryScreen({super.key, required this.onContinue});

  final ValueChanged<String> onContinue;

  @override
  State<LoginEntryScreen> createState() => _LoginEntryScreenState();
}

class _LoginEntryScreenState extends State<LoginEntryScreen> {
  final TextEditingController _controller = TextEditingController();

  bool get _canContinue => _digits.length >= 10;

  String get _digits => _controller.text.replaceAll(RegExp(r'\D'), '');

  String get _maskedValue {
    final raw = _digits.padRight(10);
    final a = raw.substring(0, 3).trim();
    final b = raw.substring(3, 6).trim();
    final c = raw.substring(6, 8).trim();
    final d = raw.substring(8, 10).trim();
    final parts = <String>[a, b, c, d].where((part) => part.isNotEmpty).toList();
    return parts.join('-');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canContinue) {
      return;
    }
    widget.onContinue('+7 ${_maskedValue.trim()}');
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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
                      const Text(
                        'Введите номер телефона',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Вам придет код подтверждения',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
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
                                  const Text(
                                    '🇰🇿',
                                    style: TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    '+7',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    color: const Color(0xFF3C3C3C),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        hintText: 'Введите номер телефона',
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _controller.text.isEmpty
                                        ? null
                                        : () {
                                            _controller.clear();
                                            setState(() {});
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
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _PrimaryButton(
                  label: 'Далее',
                  enabled: _canContinue,
                  onTap: _submit,
                ),
              ],
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
    required this.onSelected,
    required this.onBack,
    this.showBack = true,
  });

  final String selectedCity;
  final ValueChanged<String> onSelected;
  final VoidCallback onBack;
  final bool showBack;

  @override
  State<CityPickerOverlay> createState() => _CityPickerOverlayState();
}

class _CityPickerOverlayState extends State<CityPickerOverlay> {
  final TextEditingController _controller = TextEditingController();

  List<String> get _filteredCities {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      return cityOptions;
    }
    return cityOptions
        .where((city) => city.toLowerCase().contains(query))
        .toList();
  }

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
        child: Column(
          children: [
            _PageHeader(
              title: '',
              onBack: widget.showBack ? widget.onBack : null,
            ),
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
                itemCount: _filteredCities.length,
                itemBuilder: (context, index) {
                  final city = _filteredCities[index];
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
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              ),
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
                  SizedBox(width: 26),
                  _TopTab(label: 'Избранное'),
                  SizedBox(width: 26),
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
                    color: AppColors.accentYellow,
                    onTap: item.title.contains('Переводы')
                        ? onOpenTransfers
                        : null,
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

class BluetoothPaymentOverlay extends StatelessWidget {
  const BluetoothPaymentOverlay({
    super.key,
    required this.phoneNumber,
    required this.onBack,
  });

  final String phoneNumber;
  final VoidCallback onBack;

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
              _PageHeader(title: 'Bluetooth оплата', onBack: onBack),
              const SizedBox(height: 24),
              _DarkWalletCard(phoneNumber: phoneNumber),
              const Spacer(),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LoadingDot(size: 8),
                  SizedBox(width: 8),
                  _LoadingDot(size: 20),
                  SizedBox(width: 8),
                  _LoadingDot(size: 18),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Идет поиск доступного\nтранспорта',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class PlatePaymentOverlay extends StatefulWidget {
  const PlatePaymentOverlay({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<PlatePaymentOverlay> createState() => _PlatePaymentOverlayState();
}

class _PlatePaymentOverlayState extends State<PlatePaymentOverlay> {
  final TextEditingController _controller = TextEditingController();

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
              _PageHeader(title: 'Оплата по гос. номеру', onBack: widget.onBack),
              const SizedBox(height: 30),
              _SearchField(
                controller: _controller,
                hintText: 'Введите гос. номер транспорта',
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              _PrimaryButton(
                label: 'Далее',
                enabled: _controller.text.trim().isNotEmpty,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({
    super.key,
    required this.phoneNumber,
    required this.city,
    required this.walletState,
    required this.onBack,
    required this.onLogout,
    required this.onOpenCards,
  });

  final String phoneNumber;
  final String city;
  final WalletState walletState;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final VoidCallback onOpenCards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              _PageHeader(title: 'Настройки', onBack: onBack),
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
                      phoneNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      city,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Баланс: ${formatBalance(walletState.balance)} ₸',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _OverlayListRow(
                title: 'Мои карты',
                icon: Icons.credit_card_rounded,
                color: const Color(0xFFE7EDFF),
                onTap: onOpenCards,
              ),
              const SizedBox(height: 8),
              _OverlayListRow(
                title: 'Выйти',
                icon: Icons.logout_rounded,
                color: const Color(0xFFFFE0E0),
                iconColor: const Color(0xFFB32828),
                onTap: onLogout,
              ),
            ],
          ),
        ),
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
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
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

class _DarkWalletCard extends StatelessWidget {
  const _DarkWalletCard({required this.phoneNumber});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.banner,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Row(
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$phoneNumber  Стандарт',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFFD7DCEC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
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
        child: Text(label, style: const TextStyle(fontSize: 18)),
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

class _LoadingDot extends StatelessWidget {
  const _LoadingDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        color: AppColors.accentYellow,
        shape: BoxShape.circle,
      ),
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
