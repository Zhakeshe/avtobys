/// Қолданба тілдері: KK / RU / EN (өз мәтіндері, Material ішкі виджеттері әдепкіде).
enum AppLanguage { kk, ru, en }

extension AppLanguageCode on AppLanguage {
  String get code => switch (this) {
        AppLanguage.kk => 'kk',
        AppLanguage.ru => 'ru',
        AppLanguage.en => 'en',
      };

  static AppLanguage? parse(String? raw) {
    switch (raw) {
      case 'kk':
        return AppLanguage.kk;
      case 'ru':
        return AppLanguage.ru;
      case 'en':
        return AppLanguage.en;
      default:
        return null;
    }
  }
}

class AppStrings {
  const AppStrings(this.lang);

  final AppLanguage lang;

  String t({required String kk, required String ru, required String en}) {
    return switch (lang) {
      AppLanguage.kk => kk,
      AppLanguage.ru => ru,
      AppLanguage.en => en,
    };
  }

  String get languageLabel => t(
        kk: 'Тіл',
        ru: 'Язык',
        en: 'Language',
      );

  String get textSizeLabel => t(
        kk: 'Мәтін өлшемі',
        ru: 'Размер текста',
        en: 'Text size',
      );

  String get textSizeNormal => t(kk: 'Қалыпты', ru: 'Обычный', en: 'Normal');
  String get textSizeLarge => t(kk: 'Ірі', ru: 'Крупный', en: 'Large');
  String get textSizeExtraLarge => t(
        kk: 'Өте ірі',
        ru: 'Очень крупный',
        en: 'Extra large',
      );

  String get pwaTitle => t(
        kk: 'Қолданба ретінде қосыңыз',
        ru: 'Добавьте как приложение',
        en: 'Install as an app',
      );

  String get pwaBody => t(
        kk:
            'Android Chrome: ⋮ мәзір → «Басты экранға қосу». iPhone Safari: бөлісу □ → «Негізгі экранға қосу». Камера мен төлем үшін PWA ыңғайлырақ.',
        ru:
            'Android Chrome: меню ⋮ → «Добавить на главный экран». iPhone Safari: Поделиться → «На экран Домой». Для камеры и оплаты удобнее PWA.',
        en:
            'Android Chrome: ⋮ → “Add to Home screen”. iPhone Safari: Share → “Add to Home Screen”. Better for camera and payments.',
      );

  String get pwaInstallChromeButton => t(
        kk: 'Chrome-та орнату',
        ru: 'Установить (Chrome)',
        en: 'Install (Chrome)',
      );

  String get offlineDataBanner => t(
        kk: 'Офлайн: соңғы сақталған дерек көрсетілуде',
        ru: 'Офлайн: показаны последние сохранённые данные',
        en: 'Offline: showing last saved data',
      );

  String get historyTitle => t(
        kk: 'Соңғы әрекеттер',
        ru: 'Последние действия',
        en: 'Recent activity',
      );

  String get historyEmpty => t(
        kk: 'Әрекеттер әлі жоқ',
        ru: 'Пока нет действий',
        en: 'No activity yet',
      );

  String get historyClear => t(
        kk: 'Тазалау',
        ru: 'Очистить',
        en: 'Clear',
      );

  String appVersionLine(String v) => t(
        kk: 'Қолданба нұсқасы $v',
        ru: 'Версия приложения $v',
        en: 'App version $v',
      );

  String get demoPaymentNotice => t(
        kk: 'Қазір: төлем әмиян және транспорт картасы арқылы. Kaspi және банк картасы — демо / жақында.',
        ru: 'Сейчас оплата кошельком и транспортной картой. Kaspi и банковская карта — демо / скоро.',
        en: 'Payments: wallet and transport card only. Kaspi and bank card — demo / coming soon.',
      );

  String get accessibilitySection => t(
        kk: 'Қолжетімділік',
        ru: 'Доступность',
        en: 'Accessibility',
      );

  String get validUntilLabel => t(
        kk: 'Жарамды дейін',
        ru: 'Действует до',
        en: 'Valid until',
      );

  String get validInMinutes => t(
        kk: '%s мин',
        ru: '%s мин',
        en: '%s min',
      );

  String get validInSeconds => t(
        kk: '%s сек',
        ru: '%s сек',
        en: '%s sec',
      );

  String get validExpired => t(
        kk: 'Мерзімі бітті',
        ru: 'Истекло',
        en: 'Expired',
      );

  String get ticketVehicleNumberCaption => t(
        kk: 'Көлік нөмірі',
        ru: 'Номер транспорта',
        en: 'Vehicle number',
      );

  String get ticketPaymentTimeCaption => t(
        kk: 'Төлем уақыты',
        ru: 'Время оплаты',
        en: 'Payment time',
      );

  String get ticketTitle => t(
        kk: 'Билетім',
        ru: 'Мой билет',
        en: 'My ticket',
      );

  String get ticketRouteStat => t(
        kk: 'Маршрут',
        ru: 'Маршрут',
        en: 'Route',
      );

  String get ticketPaymentDateStat => t(
        kk: 'Төлем күні',
        ru: 'Дата оплаты',
        en: 'Payment date',
      );

  String get ticketTariffStat => t(
        kk: 'Тариф түрі',
        ru: 'Вид тарифа',
        en: 'Fare type',
      );

  String get ticketSumStat => t(
        kk: 'Сома',
        ru: 'Сумма',
        en: 'Amount',
      );

  String get ticketQrSemantics => t(
        kk: 'Билеттің QR коды',
        ru: 'QR-код билета',
        en: 'Ticket QR code',
      );
}
