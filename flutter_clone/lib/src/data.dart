import 'package:flutter/material.dart';

class MenuItemData {
  const MenuItemData({
    required this.id,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
}

class RouteItemData {
  const RouteItemData({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class QuickActionData {
  const QuickActionData({
    required this.id,
    required this.title,
    required this.icon,
  });

  final String id;
  final String title;
  final IconData icon;
}

class ServiceItemData {
  const ServiceItemData({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;
}

class PromoCardData {
  const PromoCardData({required this.title, required this.image});

  final String title;
  final String image;
}

class OfferCardData {
  const OfferCardData({required this.title, required this.image});

  final String title;
  final String image;
}

class PaymentCategoryData {
  const PaymentCategoryData({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class TransferOptionData {
  const TransferOptionData({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}

const settingsMenuItems = [
  MenuItemData(
    id: 'settings',
    title: 'Настройки',
    subtitle: 'Параметры приложения',
    icon: Icons.settings_outlined,
  ),
  MenuItemData(
    id: 'city',
    title: 'Мой город',
    icon: Icons.location_on_outlined,
  ),
  MenuItemData(
    id: 'language',
    title: 'Язык',
    subtitle: 'Русский',
    icon: Icons.language_outlined,
  ),
  MenuItemData(
    id: 'bank-card',
    title: 'Банковская карта',
    subtitle: '.... 5040',
    icon: Icons.credit_card_outlined,
  ),
  MenuItemData(
    id: 'about',
    title: 'О приложении',
    icon: Icons.info_outline_rounded,
  ),
  MenuItemData(
    id: 'support',
    title: 'Служба поддержки',
    icon: Icons.support_agent_rounded,
  ),
  MenuItemData(
    id: 'notifications',
    title: 'Уведомления',
    icon: Icons.chat_bubble_outline_rounded,
  ),
];

const notificationItems = [
  MenuItemData(
    id: 'top-up',
    title: 'Пополнения',
    icon: Icons.add_card_outlined,
  ),
  MenuItemData(
    id: 'purchases',
    title: 'Покупки',
    icon: Icons.shopping_bag_outlined,
  ),
  MenuItemData(
    id: 'messages',
    title: 'Сообщения',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  MenuItemData(
    id: 'notification-settings',
    title: 'Настройки уведомлений',
    icon: Icons.settings_outlined,
  ),
];

const routeItems = [
  RouteItemData(title: 'Маршрут 1', subtitle: 'Воинская часть - Автоцон'),
  RouteItemData(title: 'Маршрут 1М', subtitle: 'Больница - Коз'),
  RouteItemData(title: 'Маршрут 1ONDY', subtitle: 'Автостанция - Онды'),
  RouteItemData(
    title: 'Маршрут 2',
    subtitle: '15-й микрорайон д.35 - Сары базар',
  ),
  RouteItemData(title: 'Маршрут 2М', subtitle: 'Больница - Косбулак'),
  RouteItemData(title: 'Маршрут 2USHTAGAN', subtitle: 'Шетпе - Уштаган'),
  RouteItemData(title: 'Маршрут 3М', subtitle: 'Больница - ЖД Вокзал'),
  RouteItemData(
    title: 'Маршрут 3А',
    subtitle: '34-й микрорайон д.15 - Воинская часть',
  ),
];

const quickActions = [
  QuickActionData(id: 'qr', title: 'QR', icon: Icons.qr_code_2_rounded),
  QuickActionData(
    id: 'bluetooth',
    title: 'Bluetooth',
    icon: Icons.bluetooth_rounded,
  ),
  QuickActionData(
    id: 'plate',
    title: 'Номер',
    icon: Icons.confirmation_number_outlined,
  ),
];

const serviceItems = [
  ServiceItemData(
    id: 'payments',
    title: 'Платежи',
    icon: Icons.payments_outlined,
    color: Color(0xFFF9DFC5),
  ),
  ServiceItemData(
    id: 'tickets',
    title: 'Мои билеты',
    icon: Icons.style_outlined,
    color: Color(0xFFE5F7C8),
  ),
  ServiceItemData(
    id: 'transfers',
    title: 'Переводы',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFFDDE5FF),
  ),
  ServiceItemData(
    id: 'intercity',
    title: 'Межгород',
    icon: Icons.location_city_outlined,
    color: Color(0xFFECE8FF),
  ),
];

const promoCards = [
  PromoCardData(
    title: 'Виртуальный\nльготный тариф',
    image: 'assets/banners/banner_yellow.png',
  ),
  PromoCardData(
    title: 'История\nкошелька',
    image: 'assets/banners/banner_green.png',
  ),
  PromoCardData(
    title: 'Следите за\nмаршрутом',
    image: 'assets/banners/banner_orange.png',
  ),
  PromoCardData(
    title: 'Оплачивайте сотни\nуслуг',
    image: 'assets/banners/banner_red.png',
  ),
  PromoCardData(
    title: 'Будьте в курсе\nновостей',
    image: 'assets/banners/banner_telegram.png',
  ),
];

const offerCards = [
  OfferCardData(
    title: 'Оплачивайте\nмобильную связь',
    image: 'assets/banners/banner_pink.png',
  ),
  OfferCardData(
    title: 'Пополняйте игровые\nаккаунты',
    image: 'assets/banners/banner_violet.png',
  ),
];

const paymentCategories = [
  PaymentCategoryData(
    title: 'Мобильная связь',
    icon: Icons.stay_primary_portrait_outlined,
  ),
  PaymentCategoryData(
    title: 'Финансовые услуги, кошельки',
    icon: Icons.account_balance_wallet_outlined,
  ),
  PaymentCategoryData(
    title: 'Игры, игровые платформы',
    icon: Icons.sports_esports_outlined,
  ),
  PaymentCategoryData(
    title: 'Подарочные карты, ваучеры',
    icon: Icons.card_giftcard_outlined,
  ),
  PaymentCategoryData(
    title: 'Зарубежные моб. операторы',
    icon: Icons.language_outlined,
  ),
  PaymentCategoryData(
    title: 'Переводы баланса',
    icon: Icons.swap_horiz_rounded,
  ),
  PaymentCategoryData(
    title: 'Реклама, маркеты, объявления',
    icon: Icons.campaign_outlined,
  ),
  PaymentCategoryData(title: 'Красота и здоровье', icon: Icons.spa_outlined),
  PaymentCategoryData(title: 'Прочие услуги', icon: Icons.more_horiz_rounded),
];

const transferOptions = [
  TransferOptionData(
    title: 'Пополнение кошелька Avtobys',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFFFFC322),
  ),
  TransferOptionData(
    title: 'Пополнение Транспортной карты',
    icon: Icons.contactless_outlined,
    color: Color(0xFF0F6D9A),
  ),
];

const cityOptions = [
  'Аксай',
  'Аксу',
  'Актау',
  'Актобе',
  'Алматы',
  'Арыс',
  'Астана',
  'Атырау',
  'Аягоз',
  'Бейнеу',
  'Жанаозен',
  'Жезказган',
  'Кентау',
  'Конаев',
  'Орал',
  'Павлодар',
  'Риддер',
  'Сатпаев',
  'Семей',
  'Узынагаш',
  'Хромтау',
  'Шымкент',
  'Экибастуз',
];
