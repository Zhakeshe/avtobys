import AsyncStorage from "@react-native-async-storage/async-storage";
import { MaterialIcons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { StatusBar } from "expo-status-bar";
import { useEffect, useState } from "react";
import {
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import {
  cityOptions,
  notificationItems,
  offerCards,
  paymentCategories,
  promoCards,
  quickActions,
  routeItems,
  serviceItems,
  settingsMenuItems,
  transferOptions,
  type MenuItem,
} from "./mobile-data";
import { colors, shadow } from "./theme";
import {
  emptyWalletState,
  formatBalance,
  getActiveCard,
  maskCardNumber,
  normalizeCardNumber,
  walletStorageKey,
  type WalletState,
} from "./wallet-store";

type TabKey = "home" | "routes" | "qr" | "notifications" | "menu";
type OverlayKey =
  | "login"
  | "city"
  | "payments"
  | "transfers"
  | "bluetooth"
  | "plate"
  | "settings"
  | "cards"
  | "topup"
  | null;

const PHONE_KEY = "phone_number";
const CITY_KEY = "selected_city";

export default function MobileShell() {
  const [activeTab, setActiveTab] = useState<TabKey>("home");
  const [lastContentTab, setLastContentTab] = useState<TabKey>("home");
  const [overlay, setOverlay] = useState<OverlayKey>(null);
  const [loading, setLoading] = useState(true);
  const [phoneNumber, setPhoneNumber] = useState("");
  const [selectedCity, setSelectedCity] = useState("");
  const [walletState, setWalletState] = useState<WalletState>(emptyWalletState);

  useEffect(() => {
    let mounted = true;

    async function restoreSession() {
      const storedPhone = (await AsyncStorage.getItem(PHONE_KEY)) ?? "";
      const storedCity = (await AsyncStorage.getItem(CITY_KEY)) ?? "";
      const storedWallet = storedPhone
        ? await AsyncStorage.getItem(walletStorageKey(storedPhone))
        : null;

      if (!mounted) {
        return;
      }

      setPhoneNumber(storedPhone);
      setSelectedCity(storedCity);
      setWalletState(storedWallet ? (JSON.parse(storedWallet) as WalletState) : emptyWalletState);
      setOverlay(storedPhone ? (storedCity ? null : "city") : "login");
      setLoading(false);
    }

    void restoreSession();

    return () => {
      mounted = false;
    };
  }, []);

  const openTab = (tab: TabKey) => {
    if (tab === "qr") {
      setLastContentTab(activeTab === "qr" ? lastContentTab : activeTab);
    } else {
      setLastContentTab(tab);
    }
    setActiveTab(tab);
  };

  const savePhone = async (value: string) => {
    await AsyncStorage.setItem(PHONE_KEY, value);
    const storedWallet = await AsyncStorage.getItem(walletStorageKey(value));
    setPhoneNumber(value);
    setWalletState(storedWallet ? (JSON.parse(storedWallet) as WalletState) : emptyWalletState);
    setOverlay(selectedCity ? null : "city");
  };

  const saveCity = async (value: string) => {
    await AsyncStorage.setItem(CITY_KEY, value);
    setSelectedCity(value);
    setOverlay(null);
  };

  const logout = async () => {
    await AsyncStorage.removeItem(PHONE_KEY);
    setPhoneNumber("");
    setWalletState(emptyWalletState);
    setActiveTab("home");
    setLastContentTab("home");
    setOverlay("login");
  };

  const persistWallet = async (nextWalletState: WalletState) => {
    if (!phoneNumber) {
      return;
    }

    await AsyncStorage.setItem(walletStorageKey(phoneNumber), JSON.stringify(nextWalletState));
    setWalletState(nextWalletState);
  };

  const addCard = async (
    holderName: string,
    number: string,
    cardType: "bank" | "transport" = "bank",
  ) => {
    const nextCard = {
      id: `${Date.now()}`,
      holderName,
      number,
      cardType,
    };
    const nextWalletState = {
      ...walletState,
      cards: [...walletState.cards, nextCard],
      activeCardId: nextCard.id,
    };
    await persistWallet(nextWalletState);
  };

  const setActiveCard = async (cardId: string) => {
    await persistWallet({ ...walletState, activeCardId: cardId });
  };

  const topUpBalance = async (amount: number) => {
    await persistWallet({ ...walletState, balance: walletState.balance + amount });
    setOverlay(null);
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.loadingScreen}>
        <StatusBar style="dark" />
        <View style={styles.loaderDot} />
      </SafeAreaView>
    );
  }

  if (overlay) {
    return (
      <SafeAreaView style={styles.overlayRoot}>
        <StatusBar style="dark" />
        {overlay === "login" && <LoginScreen onContinue={savePhone} />}
        {overlay === "city" && (
          <CityScreen
            selectedCity={selectedCity || "Актау"}
            showBack={Boolean(phoneNumber)}
            onBack={() => setOverlay(null)}
            onSelectCity={saveCity}
          />
        )}
        {overlay === "payments" && (
          <PaymentsScreen
            onBack={() => setOverlay(null)}
            onOpenTransfers={() => setOverlay("transfers")}
          />
        )}
        {overlay === "transfers" && (
          <TransfersScreen onBack={() => setOverlay(null)} />
        )}
        {overlay === "bluetooth" && (
          <BluetoothScreen
            phoneNumber={phoneNumber || "+7 700-255-56-19"}
            onBack={() => setOverlay(null)}
          />
        )}
        {overlay === "plate" && <PlateScreen onBack={() => setOverlay(null)} />}
        {overlay === "settings" && (
          <SettingsScreen
            phoneNumber={phoneNumber || "+7 700-255-56-19"}
            city={selectedCity || "Актау"}
            onBack={() => setOverlay(null)}
            onLogout={logout}
          />
        )}
      </SafeAreaView>
    );
  }

  if (activeTab === "qr") {
    return (
      <ScannerScreen
        phoneNumber={phoneNumber || "+7 700-255-56-19"}
        onClose={() => openTab(lastContentTab)}
      />
    );
  }

  return (
    <View style={styles.app}>
      <StatusBar style="dark" />
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.screenShell}>
          {activeTab === "home" && (
            <HomeTab
              onOpenQr={() => openTab("qr")}
              onOpenBluetooth={() => setOverlay("bluetooth")}
              onOpenPlate={() => setOverlay("plate")}
              onOpenPayments={() => setOverlay("payments")}
              onOpenTransfers={() => setOverlay("transfers")}
            />
          )}
          {activeTab === "routes" && (
            <RoutesTab city={selectedCity || "Актау"} onOpenCity={() => setOverlay("city")} />
          )}
          {activeTab === "notifications" && (
            <NotificationsTab onBack={() => openTab("menu")} />
          )}
          {activeTab === "menu" && (
            <MenuTab
              city={selectedCity || "Актау"}
              onOpenNotifications={() => openTab("notifications")}
              onOpenCity={() => setOverlay("city")}
              onOpenSettings={() => setOverlay("settings")}
            />
          )}
        </View>
      </SafeAreaView>
      <BottomBar
        activeTab={activeTab}
        onOpenTab={openTab}
        onOpenQr={() => openTab("qr")}
      />
    </View>
  );
}

function formatPhoneDigits(value: string) {
  const padded = value.padEnd(10, " ").slice(0, 10);
  const parts = [
    padded.slice(0, 3).trim(),
    padded.slice(3, 6).trim(),
    padded.slice(6, 8).trim(),
    padded.slice(8, 10).trim(),
  ].filter(Boolean);
  return parts.join("-");
}

function HomeTab({
  onOpenQr,
  onOpenBluetooth,
  onOpenPlate,
  onOpenPayments,
  onOpenTransfers,
}: {
  onOpenQr: () => void;
  onOpenBluetooth: () => void;
  onOpenPlate: () => void;
  onOpenPayments: () => void;
  onOpenTransfers: () => void;
}) {
  return (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={styles.homeContent}
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.topOfferCard}>
        <Text style={styles.topOfferTitle}>Оформить{"\n"}льготный тариф</Text>
        <View style={styles.topOfferIcon}>
          <MaterialIcons name="verified-user" size={40} color="#FFCA2B" />
        </View>
      </View>

      <View style={styles.walletPanel}>
        <View style={styles.walletTopRow}>
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
            <Text style={styles.walletAmount}>0,00 ₸</Text>
            <Text style={styles.walletType}>Стандарт</Text>
          </LinearGradient>

          <View style={styles.addCardTile}>
            <View style={styles.addCardIconWrap}>
              <MaterialIcons name="add" size={26} color={colors.textSecondary} />
            </View>
            <Text style={styles.addCardText}>Добавить{"\n"}карту</Text>
          </View>
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
              <MaterialIcons name={item.icon as any} size={54} color="rgba(255,255,255,0.82)" />
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
            <MaterialIcons name={item.icon as any} size={40} color="rgba(255,255,255,0.85)" />
          </LinearGradient>
        ))}
      </ScrollView>
    </ScrollView>
  );
}

function RoutesTab({ city, onOpenCity }: { city: string; onOpenCity: () => void }) {
  return (
    <ScrollView style={styles.flex} contentContainerStyle={styles.homeContent} showsVerticalScrollIndicator={false}>
      <Pressable style={styles.selectorField} onPress={onOpenCity}>
        <MaterialIcons name="location-on" size={28} color={colors.primaryBlueDark} />
        <Text style={styles.selectorAccentText}>{city}</Text>
        <MaterialIcons name="keyboard-arrow-down" size={28} color={colors.textSecondary} />
      </Pressable>

      <View style={styles.selectorField}>
        <MaterialIcons name="search" size={28} color={colors.textSecondary} />
        <Text style={styles.selectorText}>Поиск</Text>
      </View>

      <View style={styles.routesList}>
        {routeItems.map((item, index) => (
          <View
            key={item.title}
            style={[styles.routeRow, index !== routeItems.length - 1 && styles.routeDivider]}
          >
            <View style={styles.routeIcon}>
              <MaterialIcons name="directions-bus" size={28} color="#FFFFFF" />
            </View>
            <View style={styles.routeCopy}>
              <Text style={styles.routeTitle}>{item.title}</Text>
              <Text style={styles.routeSubtitle}>{item.subtitle}</Text>
            </View>
          </View>
        ))}
      </View>
    </ScrollView>
  );
}

function NotificationsTab({ onBack }: { onBack: () => void }) {
  return (
    <ScrollView style={styles.flex} contentContainerStyle={styles.menuContent} showsVerticalScrollIndicator={false}>
      <Header title="Уведомления" onBack={onBack} />
      {notificationItems.map((item, index) => (
        <MenuRow key={item.id} item={item} showDivider={index !== notificationItems.length - 1} />
      ))}
    </ScrollView>
  );
}

function MenuTab({
  city,
  onOpenNotifications,
  onOpenCity,
  onOpenSettings,
}: {
  city: string;
  onOpenNotifications: () => void;
  onOpenCity: () => void;
  onOpenSettings: () => void;
}) {
  return (
    <ScrollView style={styles.flex} contentContainerStyle={styles.menuContent} showsVerticalScrollIndicator={false}>
      {settingsMenuItems.map((item, index) => (
        <MenuRow
          key={item.id}
          item={item.id === "city" ? { ...item, subtitle: city } : item}
          showDivider={index !== settingsMenuItems.length - 1}
          onPress={
            item.id === "notifications"
              ? onOpenNotifications
              : item.id === "city"
                ? onOpenCity
                : item.id === "settings"
                  ? onOpenSettings
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

function LoginScreen({ onContinue }: { onContinue: (value: string) => void }) {
  const [digits, setDigits] = useState("");

  return (
    <ScrollView contentContainerStyle={styles.loginScreen} keyboardShouldPersistTaps="handled">
      <View style={styles.skylineWrap}>
        <View style={styles.skyline} />
        <View style={styles.busBadge}>
          <MaterialIcons name="directions-bus" size={30} color="#FFFFFF" />
        </View>
      </View>

      <View style={styles.loginCard}>
        <View style={styles.dragHandle} />
        <Text style={styles.loginTitle}>Введите номер телефона</Text>
        <Text style={styles.loginSubtitle}>Вам придет код подтверждения</Text>

        <View style={styles.phoneCard}>
          <Text style={styles.phoneCardTitle}>Страна и номер телефона</Text>
          <View style={styles.phoneInputWrap}>
            <Text style={styles.flag}>🇰🇿</Text>
            <Text style={styles.countryCode}>+7</Text>
            <View style={styles.inputDivider} />
            <TextInput
              value={digits}
              onChangeText={(value) => setDigits(value.replace(/\D/g, "").slice(0, 10))}
              keyboardType="phone-pad"
              placeholder="Введите номер телефона"
              placeholderTextColor={colors.textSecondary}
              style={styles.phoneInput}
            />
            <Pressable onPress={() => setDigits("")}>
              <MaterialIcons name="cancel" size={24} color="#484848" />
            </Pressable>
          </View>
          {digits.length > 0 && <Text style={styles.phonePreview}>+7 {formatPhoneDigits(digits)}</Text>}
        </View>
      </View>

      <View style={styles.bottomButtonWrap}>
        <PrimaryButton
          label="Далее"
          disabled={digits.length < 10}
          onPress={() => onContinue(`+7 ${formatPhoneDigits(digits)}`)}
        />
      </View>
    </ScrollView>
  );
}

function CityScreen({
  selectedCity,
  showBack,
  onBack,
  onSelectCity,
}: {
  selectedCity: string;
  showBack: boolean;
  onBack: () => void;
  onSelectCity: (city: string) => void;
}) {
  const [query, setQuery] = useState("");
  const filtered = cityOptions.filter((city) =>
    city.toLowerCase().includes(query.trim().toLowerCase()),
  );

  return (
    <View style={styles.overlayScreen}>
      <Header title="" onBack={showBack ? onBack : undefined} />
      <SearchField
        value={query}
        onChangeText={setQuery}
        placeholder="Выберите город"
        icon="location-on"
      />
      <ScrollView showsVerticalScrollIndicator={false}>
        {filtered.map((city) => (
          <Pressable key={city} style={styles.cityRow} onPress={() => onSelectCity(city)}>
            <Text style={styles.cityText}>{city}</Text>
            {selectedCity === city && (
              <View style={styles.cityCheck}>
                <MaterialIcons name="check" size={24} color="#FFFFFF" />
              </View>
            )}
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
}

function PaymentsScreen({
  onBack,
  onOpenTransfers,
}: {
  onBack: () => void;
  onOpenTransfers: () => void;
}) {
  return (
    <View style={styles.overlayScreen}>
      <Header title="Платежи" onBack={onBack} />
      <SearchField placeholder="Поиск" />
      <View style={styles.tabsRow}>
        <TopTab label="Платежи" selected />
        <TopTab label="Избранное" />
        <TopTab label="История" />
      </View>
      <ScrollView showsVerticalScrollIndicator={false}>
        {paymentCategories.map((item) => (
          <OverlayListRow
            key={item.id}
            item={item}
            color={colors.accentYellow}
            onPress={item.id === "transfers" ? onOpenTransfers : undefined}
          />
        ))}
      </ScrollView>
    </View>
  );
}

function TransfersScreen({ onBack }: { onBack: () => void }) {
  return (
    <View style={styles.overlayScreen}>
      <Header title="Переводы баланса" onBack={onBack} />
      <SearchField placeholder="Поиск" />
      <ScrollView showsVerticalScrollIndicator={false}>
        {transferOptions.map((item) => (
          <OverlayListRow
            key={item.id}
            item={item}
            color={item.id === "wallet" ? colors.accentYellow : "#0F6D9A"}
            iconColor={item.id === "wallet" ? colors.primaryBlueDark : "#FFFFFF"}
          />
        ))}
      </ScrollView>
    </View>
  );
}

function BluetoothScreen({
  phoneNumber,
  onBack,
}: {
  phoneNumber: string;
  onBack: () => void;
}) {
  return (
    <View style={styles.overlayScreen}>
      <Header title="Bluetooth оплата" onBack={onBack} />
      <WalletDarkCard phoneNumber={phoneNumber} />
      <View style={styles.bluetoothBody}>
        <View style={styles.bluetoothDots}>
          <View style={[styles.yellowDot, { width: 8, height: 8 }]} />
          <View style={[styles.yellowDot, { width: 20, height: 20 }]} />
          <View style={[styles.yellowDot, { width: 18, height: 18 }]} />
        </View>
        <Text style={styles.bluetoothText}>Идет поиск доступного{"\n"}транспорта</Text>
      </View>
    </View>
  );
}

function PlateScreen({ onBack }: { onBack: () => void }) {
  const [plate, setPlate] = useState("");

  return (
    <View style={styles.overlayScreen}>
      <Header title="Оплата по гос. номеру" onBack={onBack} />
      <SearchField
        placeholder="Введите гос. номер транспорта"
        value={plate}
        onChangeText={setPlate}
        icon="credit-card"
      />
      <View style={styles.bottomButtonWrap}>
        <PrimaryButton label="Далее" disabled={!plate.trim()} onPress={() => {}} />
      </View>
    </View>
  );
}

function SettingsScreen({
  phoneNumber,
  city,
  onBack,
  onLogout,
}: {
  phoneNumber: string;
  city: string;
  onBack: () => void;
  onLogout: () => void;
}) {
  return (
    <View style={styles.overlayScreen}>
      <Header title="Настройки" onBack={onBack} />
      <View style={styles.settingsCard}>
        <Text style={styles.settingsPhone}>{phoneNumber}</Text>
        <Text style={styles.settingsCity}>{city}</Text>
      </View>
      <OverlayListRow
        item={{ id: "logout", title: "Выйти", icon: "logout" }}
        color="#FFE3E3"
        iconColor="#B62424"
        onPress={onLogout}
      />
    </View>
  );
}

function ScannerScreen({
  phoneNumber,
  onClose,
}: {
  phoneNumber: string;
  onClose: () => void;
}) {
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

function BottomBar({
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
        <BottomBarItem
          label="Avtobys"
          icon="account-balance-wallet"
          selected={activeTab === "home"}
          onPress={() => onOpenTab("home")}
        />
        <BottomBarItem
          label="Маршруты"
          icon="route"
          selected={activeTab === "routes"}
          onPress={() => onOpenTab("routes")}
        />
        <View style={styles.bottomSpacer} />
        <BottomBarItem
          label="Уведомления"
          icon="notifications-none"
          selected={activeTab === "notifications"}
          onPress={() => onOpenTab("notifications")}
        />
        <BottomBarItem
          label="Меню"
          icon="menu"
          selected={activeTab === "menu"}
          onPress={() => onOpenTab("menu")}
        />
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

function SearchField({
  value,
  onChangeText,
  placeholder,
  icon = "search",
}: {
  value?: string;
  onChangeText?: (value: string) => void;
  placeholder: string;
  icon?: string;
}) {
  return (
    <View style={styles.searchField}>
      <MaterialIcons name={icon as any} size={28} color={colors.textSecondary} />
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={colors.textSecondary}
        style={styles.searchInput}
      />
    </View>
  );
}

function ActionCard({
  icon,
  title,
  onPress,
}: {
  icon: string;
  title: string;
  onPress?: () => void;
}) {
  return (
    <Pressable style={styles.actionCard} onPress={onPress}>
      <View style={styles.actionIconWrap}>
        <MaterialIcons name={icon as any} size={24} color={colors.primaryBlue} />
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
        <MaterialIcons name={item.icon as any} size={28} color={colors.primaryBlueDark} />
      </View>
      <Text style={styles.serviceTitle}>{item.title}</Text>
    </Pressable>
  );
}

function MenuRow({
  item,
  showDivider,
  onPress,
}: {
  item: MenuItem;
  showDivider: boolean;
  onPress?: () => void;
}) {
  return (
    <Pressable style={[styles.menuRow, showDivider && styles.menuDivider]} onPress={onPress}>
      <View style={styles.menuIconCircle}>
        <MaterialIcons name={item.icon as any} size={32} color="#FFFFFF" />
      </View>
      <View style={styles.menuCopy}>
        <Text style={styles.menuTitle}>{item.title}</Text>
        {item.subtitle ? <Text style={styles.menuSubtitle}>{item.subtitle}</Text> : null}
      </View>
      <MaterialIcons name="chevron-right" size={34} color={colors.textPrimary} />
    </Pressable>
  );
}

function OverlayListRow({
  item,
  color,
  iconColor = colors.primaryBlueDark,
  onPress,
}: {
  item: MenuItem;
  color: string;
  iconColor?: string;
  onPress?: () => void;
}) {
  return (
    <Pressable style={styles.overlayRow} onPress={onPress}>
      <View style={[styles.overlayIconCircle, { backgroundColor: color }]}>
        <MaterialIcons name={item.icon as any} size={28} color={iconColor} />
      </View>
      <Text style={styles.overlayRowTitle}>{item.title}</Text>
      <MaterialIcons name="chevron-right" size={30} color={colors.textPrimary} />
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
      <MaterialIcons
        name={icon as any}
        size={28}
        color={selected ? colors.primaryBlue : colors.textSecondary}
      />
      <Text style={[styles.bottomItemLabel, selected && styles.bottomItemLabelSelected]}>{label}</Text>
    </Pressable>
  );
}

function ScannerIconButton({
  icon,
  onPress,
}: {
  icon: string;
  onPress?: () => void;
}) {
  return (
    <Pressable style={styles.scannerIconButton} onPress={onPress}>
      <MaterialIcons name={icon as any} size={24} color="#FFFFFF" />
    </Pressable>
  );
}

function TopTab({ label, selected = false }: { label: string; selected?: boolean }) {
  return (
    <View style={styles.topTabWrap}>
      <Text style={[styles.topTabLabel, selected && styles.topTabLabelSelected]}>{label}</Text>
      <View style={[styles.topTabLine, selected && styles.topTabLineSelected]} />
    </View>
  );
}

function PrimaryButton({
  label,
  disabled,
  onPress,
}: {
  label: string;
  disabled?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      style={[styles.primaryButton, disabled && styles.primaryButtonDisabled]}
      onPress={disabled ? undefined : onPress}
    >
      <Text style={styles.primaryButtonLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  app: { flex: 1, backgroundColor: "#FFFFFF" },
  safeArea: { flex: 1, backgroundColor: "#FFFFFF" },
  screenShell: { flex: 1, backgroundColor: colors.background },
  flex: { flex: 1 },
  loadingScreen: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#FFFFFF",
  },
  loaderDot: {
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: colors.primaryBlue,
  },
  overlayRoot: { flex: 1, backgroundColor: "#FFFFFF" },
  overlayScreen: {
    flex: 1,
    backgroundColor: "#FFFFFF",
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
  homeContent: {
    paddingHorizontal: 24,
    paddingTop: 12,
    paddingBottom: 140,
    gap: 16,
  },
  menuContent: { paddingTop: 14, paddingBottom: 140 },
  topOfferCard: {
    height: 118,
    backgroundColor: "#EEF1F9",
    borderRadius: 28,
    paddingHorizontal: 22,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  topOfferTitle: {
    fontSize: 20,
    lineHeight: 28,
    fontWeight: "700",
    color: colors.textPrimary,
    maxWidth: 190,
  },
  topOfferIcon: {
    width: 88,
    height: 88,
    borderRadius: 22,
    backgroundColor: "#FFF7DB",
    alignItems: "center",
    justifyContent: "center",
  },
  walletPanel: {
    backgroundColor: "#FFFFFF",
    borderRadius: 30,
    padding: 10,
    ...shadow,
  },
  walletTopRow: { flexDirection: "row", gap: 12, height: 168 },
  walletCard: {
    flex: 7,
    borderRadius: 28,
    paddingHorizontal: 20,
    paddingVertical: 18,
    overflow: "hidden",
  },
  walletAddBubble: {
    position: "absolute",
    right: 14,
    top: 14,
    width: 54,
    height: 54,
    borderRadius: 27,
    backgroundColor: "rgba(255,255,255,0.18)",
    alignItems: "center",
    justifyContent: "center",
  },
  walletLabel: { marginTop: 70, fontSize: 15, color: "#E6EBFF" },
  walletAmount: { marginTop: 8, fontSize: 24, fontWeight: "700", color: "#FFFFFF" },
  walletType: { marginTop: 10, fontSize: 16, color: "#D7DEFF" },
  addCardTile: {
    flex: 3,
    borderRadius: 22,
    borderWidth: 1.2,
    borderColor: "#E4E8F0",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#FFFFFF",
    paddingHorizontal: 12,
  },
  addCardIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: "#E2E6EF",
    alignItems: "center",
    justifyContent: "center",
  },
  addCardText: {
    marginTop: 16,
    fontSize: 16,
    lineHeight: 20,
    textAlign: "center",
    color: colors.textSecondary,
  },
  quickActionRow: { flexDirection: "row", gap: 12, marginTop: 12 },
  actionCard: {
    flex: 1,
    backgroundColor: "#FFFFFF",
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "#E8EBF2",
    paddingVertical: 16,
    alignItems: "center",
  },
  actionIconWrap: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: "#F4F7FF",
    alignItems: "center",
    justifyContent: "center",
  },
  actionTitle: {
    marginTop: 10,
    fontSize: 15,
    fontWeight: "500",
    color: colors.textPrimary,
  },
  serviceGrid: {
    backgroundColor: "#FFFFFF",
    borderRadius: 28,
    padding: 12,
    ...shadow,
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
  },
  serviceCard: {
    width: "48.5%",
    minHeight: 90,
    borderRadius: 20,
    backgroundColor: "#FCFDFF",
    paddingHorizontal: 10,
    paddingVertical: 10,
    flexDirection: "row",
    alignItems: "center",
  },
  serviceIconWrap: {
    width: 54,
    height: 54,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
  },
  serviceTitle: {
    marginLeft: 10,
    flex: 1,
    fontSize: 16,
    fontWeight: "500",
    color: colors.textPrimary,
  },
  promoRow: { gap: 12 },
  promoCard: {
    height: 92,
    borderRadius: 22,
    paddingHorizontal: 18,
    paddingVertical: 14,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  promoText: {
    width: 132,
    fontSize: 15,
    lineHeight: 18,
    fontWeight: "700",
    color: "#FFFFFF",
  },
  sectionTitle: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: "600",
    color: colors.textPrimary,
  },
  offerRow: { gap: 12, paddingBottom: 8 },
  offerCard: {
    width: 236,
    minHeight: 184,
    borderRadius: 28,
    padding: 20,
    justifyContent: "space-between",
  },
  offerTitle: {
    fontSize: 22,
    lineHeight: 28,
    fontWeight: "700",
    color: "#FFFFFF",
  },
  offerSubtitle: {
    fontSize: 14,
    lineHeight: 18,
    color: "rgba(255,255,255,0.88)",
  },
  selectorField: {
    height: 70,
    backgroundColor: colors.surfaceMuted,
    borderRadius: 18,
    paddingHorizontal: 18,
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
  },
  selectorAccentText: { flex: 1, fontSize: 18, color: colors.primaryBlueDark },
  selectorText: { flex: 1, fontSize: 18, color: colors.textSecondary },
  routesList: { marginTop: 4 },
  routeRow: { paddingVertical: 16, flexDirection: "row" },
  routeDivider: { borderBottomWidth: 1, borderBottomColor: colors.border },
  routeIcon: {
    marginTop: 2,
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: colors.primaryBlue,
    alignItems: "center",
    justifyContent: "center",
  },
  routeCopy: { marginLeft: 14, flex: 1 },
  routeTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  routeSubtitle: { marginTop: 4, fontSize: 16, color: colors.textPrimary },
  menuRow: {
    paddingHorizontal: 24,
    paddingVertical: 18,
    flexDirection: "row",
    alignItems: "center",
  },
  menuDivider: { borderBottomWidth: 1, borderBottomColor: colors.border },
  menuIconCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: colors.accentYellow,
    alignItems: "center",
    justifyContent: "center",
  },
  menuCopy: { flex: 1, marginLeft: 16 },
  menuTitle: { fontSize: 18, fontWeight: "500", color: colors.textPrimary },
  menuSubtitle: { marginTop: 4, fontSize: 15, color: colors.textSecondary },
  shareCard: {
    marginHorizontal: 24,
    marginTop: 22,
    backgroundColor: colors.banner,
    borderRadius: 22,
    paddingHorizontal: 22,
    paddingVertical: 20,
    flexDirection: "row",
    alignItems: "center",
    ...shadow,
  },
  shareTitle: { fontSize: 18, fontWeight: "700", color: "#FFFFFF" },
  shareSubtitle: { marginTop: 6, fontSize: 14, color: "#D7DCEC" },
  shareButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: "#FFFFFF",
    alignItems: "center",
    justifyContent: "center",
  },
  loginScreen: {
    minHeight: "100%",
    backgroundColor: "#FFFFFF",
    paddingHorizontal: 24,
    paddingTop: 16,
    paddingBottom: 28,
  },
  skylineWrap: { height: 170, justifyContent: "flex-end", alignItems: "center" },
  skyline: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 10,
    bottom: 12,
    borderBottomLeftRadius: 32,
    borderBottomRightRadius: 32,
    backgroundColor: "#EFF2FC",
  },
  busBadge: {
    width: 52,
    height: 52,
    borderRadius: 14,
    backgroundColor: colors.accentYellow,
    alignItems: "center",
    justifyContent: "center",
    ...shadow,
  },
  loginCard: {
    backgroundColor: "#FFFFFF",
    borderRadius: 30,
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 18,
    ...shadow,
  },
  dragHandle: {
    alignSelf: "center",
    width: 78,
    height: 5,
    borderRadius: 999,
    backgroundColor: "#D7D7D7",
  },
  loginTitle: { marginTop: 22, fontSize: 22, fontWeight: "700", color: colors.textPrimary },
  loginSubtitle: { marginTop: 8, fontSize: 16, color: colors.textSecondary },
  phoneCard: {
    marginTop: 26,
    backgroundColor: "#FFFFFF",
    borderRadius: 24,
    paddingHorizontal: 16,
    paddingTop: 18,
    paddingBottom: 16,
    ...shadow,
  },
  phoneCardTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  phoneInputWrap: {
    marginTop: 16,
    height: 72,
    borderRadius: 20,
    backgroundColor: colors.surfaceMuted,
    paddingHorizontal: 16,
    flexDirection: "row",
    alignItems: "center",
  },
  flag: { fontSize: 22 },
  countryCode: { marginLeft: 10, fontSize: 18, color: colors.textPrimary },
  inputDivider: {
    width: 1,
    height: 30,
    backgroundColor: "#3C3C3C",
    marginHorizontal: 16,
  },
  phoneInput: { flex: 1, fontSize: 18, color: colors.textPrimary },
  phonePreview: { marginTop: 10, fontSize: 14, color: colors.primaryBlueDark },
  bottomButtonWrap: { marginTop: "auto", paddingTop: 24 },
  primaryButton: {
    height: 64,
    borderRadius: 18,
    backgroundColor: colors.primaryBlue,
    alignItems: "center",
    justifyContent: "center",
  },
  primaryButtonDisabled: { backgroundColor: "#C8C8C8" },
  primaryButtonLabel: { fontSize: 18, color: "#FFFFFF" },
  header: {
    height: 56,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  headerBack: { width: 40, alignItems: "flex-start", justifyContent: "center" },
  headerTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  searchField: {
    height: 72,
    marginTop: 6,
    marginBottom: 14,
    borderRadius: 18,
    backgroundColor: colors.surfaceMuted,
    paddingHorizontal: 18,
    flexDirection: "row",
    alignItems: "center",
  },
  searchInput: { flex: 1, marginLeft: 12, fontSize: 18, color: colors.textPrimary },
  cityRow: {
    minHeight: 72,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  cityText: { fontSize: 20, color: colors.textPrimary },
  cityCheck: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: colors.primaryBlue,
    alignItems: "center",
    justifyContent: "center",
  },
  tabsRow: { flexDirection: "row", gap: 26, marginTop: 10, marginBottom: 12 },
  topTabWrap: { alignItems: "flex-start" },
  topTabLabel: { fontSize: 16, fontWeight: "500", color: colors.textSecondary },
  topTabLabelSelected: { fontWeight: "700", color: colors.textPrimary },
  topTabLine: {
    width: 82,
    height: 4,
    marginTop: 10,
    borderRadius: 999,
    backgroundColor: "transparent",
  },
  topTabLineSelected: { backgroundColor: colors.primaryBlue },
  overlayRow: { flexDirection: "row", alignItems: "center", paddingVertical: 16 },
  overlayIconCircle: {
    width: 54,
    height: 54,
    borderRadius: 27,
    alignItems: "center",
    justifyContent: "center",
  },
  overlayRowTitle: { flex: 1, marginLeft: 14, fontSize: 17, color: colors.textPrimary },
  darkWalletCard: {
    marginTop: 24,
    backgroundColor: colors.banner,
    borderRadius: 22,
    padding: 22,
  },
  darkWalletRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  darkWalletTitle: { fontSize: 18, fontWeight: "700", color: "#FFFFFF" },
  darkWalletAmount: { fontSize: 20, fontWeight: "700", color: "#FFFFFF" },
  darkWalletSubtitle: { marginTop: 10, fontSize: 15, color: "#D7DCEC" },
  bluetoothBody: { flex: 1, alignItems: "center", justifyContent: "center" },
  bluetoothDots: { flexDirection: "row", gap: 8, alignItems: "center" },
  yellowDot: { borderRadius: 999, backgroundColor: colors.accentYellow },
  bluetoothText: {
    marginTop: 24,
    fontSize: 18,
    lineHeight: 26,
    fontWeight: "700",
    textAlign: "center",
    color: colors.textPrimary,
  },
  settingsCard: {
    marginTop: 20,
    borderRadius: 22,
    backgroundColor: colors.surfaceMuted,
    padding: 20,
  },
  settingsPhone: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  settingsCity: { marginTop: 6, fontSize: 16, color: colors.textSecondary },
  scannerRoot: { flex: 1, backgroundColor: "#BFC4CA" },
  scannerBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(39,43,49,0.18)",
  },
  scannerTopButtons: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 22,
    paddingTop: 8,
  },
  scannerIconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: "rgba(255,255,255,0.38)",
    alignItems: "center",
    justifyContent: "center",
  },
  scannerFrame: {
    alignSelf: "center",
    marginTop: 180,
    width: 276,
    height: 276,
    borderRadius: 24,
    borderWidth: 4,
    borderColor: "rgba(54,79,214,0.88)",
    backgroundColor: "rgba(255,255,255,0.10)",
  },
  scannerHint: {
    alignSelf: "center",
    marginTop: 20,
    borderRadius: 18,
    backgroundColor: "rgba(91,99,127,0.82)",
    paddingHorizontal: 20,
    paddingVertical: 14,
  },
  scannerHintText: { fontSize: 15, color: "#D7DCEC" },
  scannerWalletWrap: {
    marginTop: "auto",
    paddingHorizontal: 24,
    paddingBottom: 34,
  },
  bottomBarWrap: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    height: 112,
    alignItems: "center",
  },
  bottomBar: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    height: 84,
    backgroundColor: "#FFFFFF",
    borderTopWidth: 1,
    borderTopColor: colors.border,
    flexDirection: "row",
    alignItems: "flex-start",
    paddingHorizontal: 14,
    paddingTop: 18,
    paddingBottom: 12,
    ...shadow,
  },
  bottomSpacer: { width: 84 },
  qrButton: {
    position: "absolute",
    top: 0,
    width: 76,
    height: 76,
    borderRadius: 38,
    backgroundColor: colors.primaryBlue,
    alignItems: "center",
    justifyContent: "center",
    ...shadow,
  },
  bottomItem: { flex: 1, alignItems: "center", justifyContent: "flex-end" },
  bottomItemLabel: { marginTop: 4, fontSize: 12, color: colors.textSecondary },
  bottomItemLabelSelected: { fontWeight: "600", color: colors.primaryBlue },
});
