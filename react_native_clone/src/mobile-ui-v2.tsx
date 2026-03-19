import { useEffect, useState } from "react";
import { MaterialIcons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { StatusBar } from "expo-status-bar";
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { getBuses, getCities, type BusDto } from "./api";
import {
  notificationItems,
  offerCards,
  promoCards,
  quickActions,
  serviceItems,
  settingsMenuItems,
  type MenuItem,
} from "./mobile-data";
import { colors, shadow } from "./theme";
import { formatBalance, maskCardNumber, type WalletState } from "./wallet-store";

type TabKey = "home" | "routes" | "qr" | "notifications" | "menu";

export function HomeTab({
  walletState,
  onOpenQr,
  onOpenBluetooth,
  onOpenPlate,
  onOpenPayments,
  onOpenTransfers,
  onOpenTickets,
  onOpenCards,
  onOpenTopUp,
}: {
  walletState: WalletState;
  onOpenQr: () => void;
  onOpenBluetooth: () => void;
  onOpenPlate: () => void;
  onOpenPayments: () => void;
  onOpenTransfers: () => void;
  onOpenTickets: () => void;
  onOpenCards: () => void;
  onOpenTopUp: () => void;
}) {
  const activeCard =
    walletState.cards.find((card) => card.id === walletState.activeCardId) ?? walletState.cards[0];

  return (
    <ScrollView style={styles.flex} contentContainerStyle={styles.homeContent} showsVerticalScrollIndicator={false}>
      <View style={styles.topOfferCard}>
        <Text style={styles.topOfferTitle}>Оформить{"\n"}льготный тариф</Text>
        <View style={styles.topOfferIcon}>
          <MaterialIcons name="verified-user" size={40} color="#FFCA2B" />
        </View>
      </View>

      <View style={styles.walletPanel}>
        <View style={styles.walletTopRow}>
          <Pressable style={styles.walletPressable} onPress={onOpenTopUp}>
            <LinearGradient
              colors={["#2E74FF", "#1E54F5"]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.walletCard}
            >
              <View style={styles.walletAddBubble}>
                <MaterialIcons name="add" size={28} color="#FFFFFF" />
              </View>
              <Text style={styles.walletLabel}>Баланс</Text>
              <Text style={styles.walletAmount}>{formatBalance(walletState.balance)} ₸</Text>
              <Text style={styles.walletType}>
                {activeCard ? maskCardNumber(activeCard.number) : "Стандарт"}
              </Text>
            </LinearGradient>
          </Pressable>

          <Pressable style={styles.addCardTile} onPress={onOpenCards}>
            <View style={styles.addCardIconWrap}>
              <MaterialIcons name="add" size={26} color={colors.textSecondary} />
            </View>
            <Text style={styles.addCardText}>
              {walletState.cards.length === 0 ? "Добавить\nкарту" : `${walletState.cards.length}\nкарты`}
            </Text>
          </Pressable>
        </View>

        <View style={styles.quickActionRow}>
          {quickActions.map((item) => (
            <ActionCard
              key={item.id}
              icon={item.icon}
              title={item.title}
              onPress={
                item.id === "qr"
                  ? onOpenQr
                  : item.id === "bluetooth"
                    ? onOpenBluetooth
                    : onOpenPlate
              }
            />
          ))}
        </View>
      </View>

      <View style={styles.serviceGrid}>
        {serviceItems.map((item) => (
          <ServiceCard
            key={item.id}
            item={item}
            onPress={
              item.id === "payments"
                ? onOpenPayments
                : item.id === "tickets"
                  ? onOpenTickets
                  : item.id === "transfers"
                    ? onOpenTransfers
                    : undefined
            }
          />
        ))}
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.promoRow}>
        {promoCards.map((item, index) => (
          <View key={item.title} style={{ width: index === 0 ? 262 : 206 }}>
            <View style={[styles.promoCard, { backgroundColor: item.background }]}>
              <Text style={styles.promoText}>{item.title}</Text>
              <MaterialIcons name={item.icon as never} size={54} color="rgba(255,255,255,0.82)" />
            </View>
          </View>
        ))}
      </ScrollView>

      <Text style={styles.sectionTitle}>Предложения</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.offerRow}>
        {offerCards.map((item) => (
          <LinearGradient
            key={item.title}
            colors={item.colors}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.offerCard}
          >
            <Text style={styles.offerTitle}>{item.title}</Text>
            <Text style={styles.offerSubtitle}>{item.subtitle}</Text>
            <MaterialIcons name={item.icon as never} size={40} color="rgba(255,255,255,0.85)" />
          </LinearGradient>
        ))}
      </ScrollView>
    </ScrollView>
  );
}

export function RoutesTab({ city, onOpenCity }: { city: string; onOpenCity: () => void }) {
  const [query, setQuery] = useState("");
  const [routes, setRoutes] = useState<BusDto[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;

    async function loadRoutes() {
      setLoading(true);
      try {
        const cities = await getCities();
        const selectedCity = cities.find((item) => item.name === city) ?? cities[0];
        if (!selectedCity?.id) {
          if (active) {
            setRoutes([]);
          }
          return;
        }

        const buses = await getBuses(selectedCity.id);
        if (active) {
          setRoutes(buses);
        }
      } catch {
        if (active) {
          setRoutes([]);
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    void loadRoutes();
    return () => {
      active = false;
    };
  }, [city]);

  const filteredRoutes = routes.filter((item) => {
    const needle = query.trim().toLowerCase();
    if (!needle) {
      return true;
    }
    return (
      item.routeNumber.toLowerCase().includes(needle) ||
      item.number.toLowerCase().includes(needle) ||
      item.tariffName.toLowerCase().includes(needle)
    );
  });

  return (
    <ScrollView style={styles.flex} contentContainerStyle={styles.homeContent} showsVerticalScrollIndicator={false}>
      <Pressable style={styles.selectorField} onPress={onOpenCity}>
        <MaterialIcons name="location-on" size={28} color={colors.primaryBlueDark} />
        <Text style={styles.selectorAccentText}>{city}</Text>
        <MaterialIcons name="keyboard-arrow-down" size={28} color={colors.textSecondary} />
      </Pressable>

      <View style={styles.selectorField}>
        <MaterialIcons name="search" size={28} color={colors.textSecondary} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          placeholder="Поиск автобуса"
          placeholderTextColor={colors.textSecondary}
          style={styles.selectorInput}
        />
      </View>

      <View style={styles.routesSummaryCard}>
        <Text style={styles.routesSummaryTitle}>Список автобусов по городу</Text>
        <Text style={styles.routesSummaryMeta}>{loading ? "Загрузка..." : `${filteredRoutes.length} автобусов`}</Text>
      </View>

      <View style={styles.routesList}>
        {loading ? (
          <View style={styles.routesPlaceholder}>
            <Text style={styles.routesPlaceholderText}>Загрузка маршрутов...</Text>
          </View>
        ) : filteredRoutes.length === 0 ? (
          <View style={styles.routesPlaceholder}>
            <Text style={styles.routesPlaceholderText}>Для выбранного города автобусы не найдены.</Text>
          </View>
        ) : (
          filteredRoutes.map((item, index) => (
            <View key={item.id} style={[styles.routeRow, index !== filteredRoutes.length - 1 && styles.routeDivider]}>
              <View style={styles.routeIcon}>
                <MaterialIcons name="directions-bus" size={28} color="#FFFFFF" />
              </View>
              <View style={styles.routeCopy}>
                <Text style={styles.routeTitle}>Маршрут {item.routeNumber}</Text>
                <Text style={styles.routeSubtitle}>Көлік нөмірі: {item.number}</Text>
                <Text style={styles.routeMeta}>
                  {item.tariffName} • {item.price} ₸
                </Text>
              </View>
            </View>
          ))
        )}
      </View>
    </ScrollView>
  );
}

export function NotificationsTab({ onBack }: { onBack: () => void }) {
  return (
    <ScrollView style={styles.flex} contentContainerStyle={styles.menuContent} showsVerticalScrollIndicator={false}>
      <Header title="Уведомления" onBack={onBack} />
      {notificationItems.map((item, index) => (
        <MenuRow key={item.id} item={item} showDivider={index !== notificationItems.length - 1} />
      ))}
    </ScrollView>
  );
}

export function MenuTab({
  city,
  bankCardSubtitle,
  onOpenNotifications,
  onOpenCity,
  onOpenSettings,
  onOpenCards,
}: {
  city: string;
  bankCardSubtitle: string;
  onOpenNotifications: () => void;
  onOpenCity: () => void;
  onOpenSettings: () => void;
  onOpenCards: () => void;
}) {
  return (
    <ScrollView style={styles.flex} contentContainerStyle={styles.menuContent} showsVerticalScrollIndicator={false}>
      {settingsMenuItems.map((item, index) => (
        <MenuRow
          key={item.id}
          item={
            item.id === "city"
              ? { ...item, subtitle: city }
              : item.id === "bank-card"
                ? { ...item, subtitle: bankCardSubtitle }
                : item
          }
          showDivider={index !== settingsMenuItems.length - 1}
          onPress={
            item.id === "notifications"
              ? onOpenNotifications
              : item.id === "city"
                ? onOpenCity
                : item.id === "settings"
                  ? onOpenSettings
                  : item.id === "bank-card"
                    ? onOpenCards
                    : undefined
          }
        />
      ))}

      <View style={styles.shareCard}>
        <View style={styles.flex}>
          <Text style={styles.shareTitle}>Поделиться с друзьями</Text>
          <Text style={styles.shareSubtitle}>Отправить ссылку на приложение</Text>
        </View>
        <View style={styles.shareButton}>
          <MaterialIcons name="ios-share" size={26} color={colors.banner} />
        </View>
      </View>
    </ScrollView>
  );
}

export function ScannerScreen({ phoneNumber, onClose }: { phoneNumber: string; onClose: () => void }) {
  return (
    <View style={styles.scannerRoot}>
      <StatusBar style="dark" />
      <SafeAreaView style={styles.flex}>
        <View style={styles.scannerBackdrop} />
        <View style={styles.scannerTopButtons}>
          <ScannerIconButton icon="flash-on" />
          <ScannerIconButton icon="close" onPress={onClose} />
        </View>
        <View style={styles.scannerFrame} />
        <View style={styles.scannerHint}>
          <Text style={styles.scannerHintText}>Наведите камеру на QR-код</Text>
        </View>
        <View style={styles.scannerWalletWrap}>
          <WalletDarkCard phoneNumber={phoneNumber} />
        </View>
      </SafeAreaView>
    </View>
  );
}

export function BottomBar({
  activeTab,
  onOpenTab,
  onOpenQr,
}: {
  activeTab: TabKey;
  onOpenTab: (tab: TabKey) => void;
  onOpenQr: () => void;
}) {
  return (
    <View style={styles.bottomBarWrap}>
      <View style={styles.bottomBar}>
        <BottomBarItem label="Avtobys" icon="account-balance-wallet" selected={activeTab === "home"} onPress={() => onOpenTab("home")} />
        <BottomBarItem label="Маршруты" icon="route" selected={activeTab === "routes"} onPress={() => onOpenTab("routes")} />
        <View style={styles.bottomSpacer} />
        <BottomBarItem label="Уведомления" icon="notifications-none" selected={activeTab === "notifications"} onPress={() => onOpenTab("notifications")} />
        <BottomBarItem label="Меню" icon="menu" selected={activeTab === "menu"} onPress={() => onOpenTab("menu")} />
      </View>
      <Pressable style={styles.qrButton} onPress={onOpenQr}>
        <MaterialIcons name="qr-code-scanner" size={32} color="#FFFFFF" />
      </Pressable>
    </View>
  );
}

function Header({ title, onBack }: { title: string; onBack?: () => void }) {
  return (
    <View style={styles.header}>
      {onBack ? (
        <Pressable style={styles.headerBack} onPress={onBack}>
          <MaterialIcons name="arrow-back-ios-new" size={28} color={colors.textPrimary} />
        </Pressable>
      ) : (
        <View style={styles.headerBack} />
      )}
      <Text style={styles.headerTitle}>{title}</Text>
      <View style={styles.headerBack} />
    </View>
  );
}

function ActionCard({ icon, title, onPress }: { icon: string; title: string; onPress?: () => void }) {
  return (
    <Pressable style={styles.actionCard} onPress={onPress}>
      <View style={styles.actionIconWrap}>
        <MaterialIcons name={icon as never} size={24} color={colors.primaryBlue} />
      </View>
      <Text style={styles.actionTitle}>{title}</Text>
    </Pressable>
  );
}

function ServiceCard({
  item,
  onPress,
}: {
  item: { title: string; icon: string; color: string };
  onPress?: () => void;
}) {
  return (
    <Pressable style={styles.serviceCard} onPress={onPress}>
      <View style={[styles.serviceIconWrap, { backgroundColor: item.color }]}>
        <MaterialIcons name={item.icon as never} size={28} color={colors.primaryBlueDark} />
      </View>
      <Text style={styles.serviceTitle}>{item.title}</Text>
    </Pressable>
  );
}

function MenuRow({ item, showDivider, onPress }: { item: MenuItem; showDivider: boolean; onPress?: () => void }) {
  return (
    <Pressable style={[styles.menuRow, showDivider && styles.menuDivider]} onPress={onPress}>
      <View style={styles.menuIconCircle}>
        <MaterialIcons name={item.icon as never} size={32} color="#FFFFFF" />
      </View>
      <View style={styles.menuCopy}>
        <Text style={styles.menuTitle}>{item.title}</Text>
        {item.subtitle ? <Text style={styles.menuSubtitle}>{item.subtitle}</Text> : null}
      </View>
      <MaterialIcons name="chevron-right" size={34} color={colors.textPrimary} />
    </Pressable>
  );
}

function BottomBarItem({
  label,
  icon,
  selected,
  onPress,
}: {
  label: string;
  icon: string;
  selected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable style={styles.bottomItem} onPress={onPress}>
      <MaterialIcons name={icon as never} size={28} color={selected ? colors.primaryBlue : colors.textSecondary} />
      <Text style={[styles.bottomItemLabel, selected && styles.bottomItemLabelSelected]}>{label}</Text>
    </Pressable>
  );
}

function ScannerIconButton({ icon, onPress }: { icon: string; onPress?: () => void }) {
  return (
    <Pressable style={styles.scannerIconButton} onPress={onPress}>
      <MaterialIcons name={icon as never} size={24} color="#FFFFFF" />
    </Pressable>
  );
}

function WalletDarkCard({ phoneNumber }: { phoneNumber: string }) {
  return (
    <View style={styles.darkWalletCard}>
      <View style={styles.darkWalletRow}>
        <Text style={styles.darkWalletTitle}>Кошелек</Text>
        <Text style={styles.darkWalletAmount}>0,00 ₸</Text>
      </View>
      <Text style={styles.darkWalletSubtitle}>{phoneNumber}  Стандарт</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  homeContent: { paddingHorizontal: 24, paddingTop: 12, paddingBottom: 140, gap: 16 },
  menuContent: { paddingTop: 14, paddingBottom: 140 },
  topOfferCard: { height: 118, backgroundColor: "#EEF1F9", borderRadius: 28, paddingHorizontal: 22, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  topOfferTitle: { fontSize: 20, lineHeight: 28, fontWeight: "700", color: colors.textPrimary, maxWidth: 190 },
  topOfferIcon: { width: 88, height: 88, borderRadius: 22, backgroundColor: "#FFF7DB", alignItems: "center", justifyContent: "center" },
  walletPanel: { backgroundColor: "#FFFFFF", borderRadius: 30, padding: 10, ...shadow },
  walletTopRow: { flexDirection: "row", gap: 12, height: 168 },
  walletPressable: { flex: 7 },
  walletCard: { flex: 1, borderRadius: 28, paddingHorizontal: 20, paddingVertical: 18, overflow: "hidden" },
  walletAddBubble: { position: "absolute", right: 14, top: 14, width: 54, height: 54, borderRadius: 27, backgroundColor: "rgba(255,255,255,0.18)", alignItems: "center", justifyContent: "center" },
  walletLabel: { marginTop: 70, fontSize: 15, color: "#E6EBFF" },
  walletAmount: { marginTop: 8, fontSize: 24, fontWeight: "700", color: "#FFFFFF" },
  walletType: { marginTop: 10, fontSize: 16, color: "#D7DEFF" },
  addCardTile: { flex: 3, borderRadius: 22, borderWidth: 1.2, borderColor: "#E4E8F0", alignItems: "center", justifyContent: "center", backgroundColor: "#FFFFFF", paddingHorizontal: 12 },
  addCardIconWrap: { width: 44, height: 44, borderRadius: 14, borderWidth: 1, borderColor: "#E2E6EF", alignItems: "center", justifyContent: "center" },
  addCardText: { marginTop: 16, fontSize: 16, lineHeight: 20, textAlign: "center", color: colors.textSecondary },
  quickActionRow: { flexDirection: "row", gap: 12, marginTop: 12 },
  actionCard: { flex: 1, backgroundColor: "#FFFFFF", borderRadius: 18, borderWidth: 1, borderColor: "#E8EBF2", paddingVertical: 16, alignItems: "center" },
  actionIconWrap: { width: 46, height: 46, borderRadius: 23, backgroundColor: "#F4F7FF", alignItems: "center", justifyContent: "center" },
  actionTitle: { marginTop: 10, fontSize: 15, fontWeight: "500", color: colors.textPrimary },
  serviceGrid: { backgroundColor: "#FFFFFF", borderRadius: 28, padding: 12, ...shadow, flexDirection: "row", flexWrap: "wrap", gap: 10 },
  serviceCard: { width: "48.5%", minHeight: 90, borderRadius: 20, backgroundColor: "#FCFDFF", paddingHorizontal: 10, paddingVertical: 10, flexDirection: "row", alignItems: "center" },
  serviceIconWrap: { width: 54, height: 54, borderRadius: 16, alignItems: "center", justifyContent: "center" },
  serviceTitle: { marginLeft: 10, flex: 1, fontSize: 16, fontWeight: "500", color: colors.textPrimary },
  promoRow: { gap: 12 },
  promoCard: { height: 92, borderRadius: 22, paddingHorizontal: 18, paddingVertical: 14, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  promoText: { width: 132, fontSize: 15, lineHeight: 18, fontWeight: "700", color: "#FFFFFF" },
  sectionTitle: { marginTop: 8, fontSize: 18, fontWeight: "600", color: colors.textPrimary },
  offerRow: { gap: 12, paddingBottom: 8 },
  offerCard: { width: 236, minHeight: 184, borderRadius: 28, padding: 20, justifyContent: "space-between" },
  offerTitle: { fontSize: 22, lineHeight: 28, fontWeight: "700", color: "#FFFFFF" },
  offerSubtitle: { fontSize: 14, lineHeight: 18, color: "rgba(255,255,255,0.88)" },
  selectorField: { height: 70, backgroundColor: colors.surfaceMuted, borderRadius: 18, paddingHorizontal: 18, flexDirection: "row", alignItems: "center", gap: 14 },
  selectorAccentText: { flex: 1, fontSize: 18, color: colors.primaryBlueDark },
  selectorInput: { flex: 1, fontSize: 18, color: colors.textPrimary },
  routesSummaryCard: { marginTop: 4, paddingHorizontal: 18, paddingVertical: 16, borderRadius: 18, backgroundColor: "#FFFFFF", ...shadow },
  routesSummaryTitle: { fontSize: 17, fontWeight: "700", color: colors.textPrimary },
  routesSummaryMeta: { marginTop: 6, fontSize: 14, color: colors.textSecondary },
  routesList: { marginTop: 4 },
  routesPlaceholder: { paddingVertical: 24, paddingHorizontal: 18, borderRadius: 18, backgroundColor: "#FFFFFF", ...shadow },
  routesPlaceholderText: { fontSize: 16, color: colors.textSecondary },
  routeRow: { paddingVertical: 16, flexDirection: "row" },
  routeDivider: { borderBottomWidth: 1, borderBottomColor: colors.border },
  routeIcon: { marginTop: 2, width: 48, height: 48, borderRadius: 24, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center" },
  routeCopy: { marginLeft: 14, flex: 1 },
  routeTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  routeSubtitle: { marginTop: 4, fontSize: 16, color: colors.textPrimary },
  routeMeta: { marginTop: 4, fontSize: 14, color: colors.textSecondary },
  menuRow: { paddingHorizontal: 24, paddingVertical: 18, flexDirection: "row", alignItems: "center" },
  menuDivider: { borderBottomWidth: 1, borderBottomColor: colors.border },
  menuIconCircle: { width: 64, height: 64, borderRadius: 32, backgroundColor: colors.accentYellow, alignItems: "center", justifyContent: "center" },
  menuCopy: { flex: 1, marginLeft: 16 },
  menuTitle: { fontSize: 18, fontWeight: "500", color: colors.textPrimary },
  menuSubtitle: { marginTop: 4, fontSize: 15, color: colors.textSecondary },
  shareCard: { marginHorizontal: 24, marginTop: 22, backgroundColor: colors.banner, borderRadius: 22, paddingHorizontal: 22, paddingVertical: 20, flexDirection: "row", alignItems: "center", ...shadow },
  shareTitle: { fontSize: 18, fontWeight: "700", color: "#FFFFFF" },
  shareSubtitle: { marginTop: 6, fontSize: 14, color: "#D7DCEC" },
  shareButton: { width: 56, height: 56, borderRadius: 28, backgroundColor: "#FFFFFF", alignItems: "center", justifyContent: "center" },
  scannerRoot: { flex: 1, backgroundColor: "#BFC4CA" },
  scannerBackdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(39,43,49,0.18)" },
  scannerTopButtons: { flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 22, paddingTop: 8 },
  scannerIconButton: { width: 40, height: 40, borderRadius: 20, backgroundColor: "rgba(255,255,255,0.38)", alignItems: "center", justifyContent: "center" },
  scannerFrame: { alignSelf: "center", marginTop: 180, width: 276, height: 276, borderRadius: 24, borderWidth: 4, borderColor: "rgba(54,79,214,0.88)", backgroundColor: "rgba(255,255,255,0.10)" },
  scannerHint: { alignSelf: "center", marginTop: 20, borderRadius: 18, backgroundColor: "rgba(91,99,127,0.82)", paddingHorizontal: 20, paddingVertical: 14 },
  scannerHintText: { fontSize: 15, color: "#D7DCEC" },
  scannerWalletWrap: { marginTop: "auto", paddingHorizontal: 24, paddingBottom: 34 },
  darkWalletCard: { marginTop: 24, backgroundColor: colors.banner, borderRadius: 22, padding: 22 },
  darkWalletRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  darkWalletTitle: { fontSize: 18, fontWeight: "700", color: "#FFFFFF" },
  darkWalletAmount: { fontSize: 20, fontWeight: "700", color: "#FFFFFF" },
  darkWalletSubtitle: { marginTop: 10, fontSize: 15, color: "#D7DCEC" },
  header: { height: 56, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  headerBack: { width: 40, alignItems: "flex-start", justifyContent: "center" },
  headerTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  bottomBarWrap: { position: "absolute", left: 0, right: 0, bottom: 0, height: 112, alignItems: "center" },
  bottomBar: { position: "absolute", left: 0, right: 0, bottom: 0, height: 84, backgroundColor: "#FFFFFF", borderTopWidth: 1, borderTopColor: colors.border, flexDirection: "row", alignItems: "flex-start", paddingHorizontal: 14, paddingTop: 18, paddingBottom: 12, ...shadow },
  bottomSpacer: { width: 84 },
  qrButton: { position: "absolute", top: 0, width: 76, height: 76, borderRadius: 38, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center", ...shadow },
  bottomItem: { flex: 1, alignItems: "center", justifyContent: "flex-end" },
  bottomItemLabel: { marginTop: 4, fontSize: 12, color: colors.textSecondary },
  bottomItemLabelSelected: { fontWeight: "600", color: colors.primaryBlue },
});
