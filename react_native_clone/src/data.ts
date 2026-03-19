export type MenuItem = {
  title: string;
  subtitle?: string;
  icon: string;
};

export type RouteItem = {
  title: string;
  subtitle: string;
};

export type QuickAction = {
  title: string;
  icon: string;
};

export type ServiceItem = {
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

export const menuItems: MenuItem[] = [
  { title: "Настройки", subtitle: "Параметры приложения", icon: "settings" },
  { title: "Мой город", subtitle: "Актау", icon: "navigation" },
  { title: "Язык", subtitle: "Русский", icon: "language" },
  { title: "Банковская карта", subtitle: ".... 5040", icon: "credit-card" },
  { title: "О приложении", icon: "info-outline" },
  { title: "Служба поддержки", icon: "support-agent" },
  { title: "Уведомления", icon: "chat-bubble-outline" },
];

export const notificationItems: MenuItem[] = [
  { title: "Пополнения", icon: "add-card" },
  { title: "Покупки", icon: "shopping-bag" },
  { title: "Сообщения", icon: "chat-bubble-outline" },
  { title: "Настройки уведомлений", icon: "settings" },
];

export const routeItems: RouteItem[] = [
  { title: "Маршрут 1", subtitle: "Воинская часть - Автоцон" },
  { title: "Маршрут 1M", subtitle: "Больница - Коз" },
  { title: "Маршрут 1ONDY", subtitle: "Автостанция - Онды" },
  { title: "Маршрут 2", subtitle: "15-й микрорайон д.35 - Сары базар" },
  { title: "Маршрут 2M", subtitle: "Больница - Косбулак" },
  { title: "Маршрут 2USHTAGAN", subtitle: "Шетпе - Уштаган" },
  { title: "Маршрут 3M", subtitle: "Больница - ЖД Вокзал" },
  { title: "Маршрут 3A", subtitle: "34-й микрорайон д. 15 - Воинская часть" },
];

export const quickActions: QuickAction[] = [
  { title: "QR", icon: "qr-code-2" },
  { title: "Bluetooth", icon: "bluetooth" },
  { title: "Номер", icon: "confirmation-number" },
];

export const serviceItems: ServiceItem[] = [
  { title: "Платежи", icon: "payments", color: "#F9DFC5" },
  { title: "Мои билеты", icon: "style", color: "#E5F7C8" },
  { title: "Переводы", icon: "swap-horiz", color: "#DDE5FF" },
  { title: "Межгород", icon: "location-city", color: "#ECE8FF" },
];

export const promoCards: PromoCard[] = [
  {
    title: "Виртуальный\nльготный тариф",
    icon: "verified-user",
    background: "#FABE0C",
  },
  {
    title: "История\nкошелька",
    icon: "history",
    background: "#87C63D",
  },
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
