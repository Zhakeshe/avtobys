export type MenuItem = {
  id: string;
  title: string;
  subtitle?: string;
  icon: string;
};

export type RouteItem = {
  title: string;
  subtitle: string;
};

export type QuickAction = {
  id: string;
  title: string;
  icon: string;
};

export type ServiceItem = {
  id: string;
  title: string;
  icon: string;
  color: string;
};

export type PromoCard = {
  title: string;
  icon: string;
  background: string;
};

export type OfferCard = {
  title: string;
  subtitle: string;
  icon: string;
  colors: [string, string];
};

export const settingsMenuItems: MenuItem[] = [
  { id: "settings", title: "Настройки", subtitle: "Параметры приложения", icon: "settings" },
  { id: "city", title: "Мой город", icon: "navigation" },
  { id: "language", title: "Язык", subtitle: "Русский", icon: "language" },
  { id: "bank-card", title: "Банковская карта", subtitle: ".... 5040", icon: "credit-card" },
  { id: "about", title: "О приложении", icon: "info-outline" },
  { id: "support", title: "Служба поддержки", icon: "support-agent" },
  { id: "notifications", title: "Уведомления", icon: "chat-bubble-outline" },
];

export const notificationItems: MenuItem[] = [
  { id: "top-up", title: "Пополнения", icon: "add-card" },
  { id: "purchases", title: "Покупки", icon: "shopping-bag" },
  { id: "messages", title: "Сообщения", icon: "chat-bubble-outline" },
  { id: "notification-settings", title: "Настройки уведомлений", icon: "settings" },
];

export const routeItems: RouteItem[] = [
  { title: "Маршрут 1", subtitle: "Воинская часть - Автоцон" },
  { title: "Маршрут 1M", subtitle: "Больница - Коз" },
  { title: "Маршрут 1ONDY", subtitle: "Автостанция - Онды" },
  { title: "Маршрут 2", subtitle: "15-й микрорайон д.35 - Сары базар" },
  { title: "Маршрут 2M", subtitle: "Больница - Козбулак" },
  { title: "Маршрут 2USHTAGAN", subtitle: "Шетпе - Уштаган" },
  { title: "Маршрут 3M", subtitle: "Больница - ЖД Вокзал" },
  { title: "Маршрут 3A", subtitle: "34-й микрорайон д.15 - Воинская часть" },
];

export const quickActions: QuickAction[] = [
  { id: "qr", title: "QR", icon: "qr-code-2" },
  { id: "bluetooth", title: "Bluetooth", icon: "bluetooth" },
  { id: "plate", title: "Номер", icon: "confirmation-number" },
];

export const serviceItems: ServiceItem[] = [
  { id: "payments", title: "Платежи", icon: "payments", color: "#F9DFC5" },
  { id: "tickets", title: "Мои билеты", icon: "style", color: "#E5F7C8" },
  { id: "transfers", title: "Переводы", icon: "swap-horiz", color: "#DDE5FF" },
  { id: "intercity", title: "Межгород", icon: "location-city", color: "#ECE8FF" },
];

export const promoCards: PromoCard[] = [
  { title: "Виртуальный\nльготный тариф", icon: "verified-user", background: "#FABE0C" },
  { title: "История\nкошелька", icon: "history", background: "#87C63D" },
];

export const offerCards: OfferCard[] = [
  {
    title: "Оплачивайте\nмобильную связь",
    subtitle: "Быстрые платежи без комиссии",
    icon: "phone-android",
    colors: ["#D91B73", "#9E1668"],
  },
  {
    title: "Пополняйте игровые\nаккаунты",
    subtitle: "Популярные сервисы в пару касаний",
    icon: "sports-esports",
    colors: ["#8A66FB", "#4B38D4"],
  },
  {
    title: "Оформляйте новые\nкарты и тарифы",
    subtitle: "Отдельный раздел для акций и льгот",
    icon: "discount",
    colors: ["#1B86FF", "#1956F3"],
  },
];

export const paymentCategories: MenuItem[] = [
  { id: "mobile", title: "Мобильная связь", icon: "smartphone" },
  { id: "finance", title: "Финансовые услуги, кошельки", icon: "account-balance-wallet" },
  { id: "games", title: "Игры, игровые платформы", icon: "sports-esports" },
  { id: "gift", title: "Подарочные карты, ваучеры", icon: "card-giftcard" },
  { id: "foreign", title: "Зарубежные моб. операторы", icon: "language" },
  { id: "transfers", title: "Переводы баланса", icon: "swap-horiz" },
  { id: "ads", title: "Реклама, маркеты, объявления", icon: "campaign" },
  { id: "health", title: "Красота и здоровье", icon: "spa" },
  { id: "other", title: "Прочие услуги", icon: "more-horiz" },
];

export const transferOptions: MenuItem[] = [
  { id: "wallet", title: "Пополнение кошелька Avtobys", icon: "account-balance-wallet" },
  { id: "card", title: "Пополнение Транспортной карты", icon: "contactless" },
];

export const cityOptions = [
  "Аксай",
  "Аксу",
  "Актау",
  "Актобе",
  "Алматы",
  "Арыс",
  "Астана",
  "Атырау",
  "Аягоз",
  "Бейнеу",
  "Жанаозен",
  "Жезказган",
  "Кентау",
  "Конаев",
  "Орал",
  "Павлодар",
  "Риддер",
  "Сатпаев",
  "Семей",
  "Узынагаш",
  "Хромтау",
  "Шымкент",
  "Экибастуз",
];
