import AsyncStorage from "@react-native-async-storage/async-storage";
import { StatusBar } from "expo-status-bar";
import { useEffect, useState, type ReactNode } from "react";
import { SafeAreaView, StyleSheet, View } from "react-native";

import {
  activateWalletCard,
  addWalletCard,
  getAuthSession,
  logoutAuth,
  requestAuthCode,
  requestRideAccess,
  setApiSessionToken,
  topUpWallet,
  updateProfile,
  verifyAuthCode,
  type AuthSessionDto,
} from "./api";
import {
  CardsScreen,
  CityScreen,
  LoginScreen,
  PaymentsScreen,
  SettingsScreen,
  TopUpScreen,
  TransfersScreen,
} from "./mobile-overlays-v2";
import {
  BluetoothScannerScreen,
  QrScannerPaymentScreen,
} from "./mobile-hardware-v2";
import { BusSearchScreen, TicketsScreen } from "./mobile-transport-v2";
import {
  BottomBar,
  HomeTab,
  MenuTab,
  NotificationsTab,
  RoutesTab,
} from "./mobile-ui-v2";
import { colors } from "./theme";
import { WebAppFrame } from "./web-app-frame";
import {
  emptyWalletState,
  getActiveCard,
  hydrateWalletState,
  maskCardNumber,
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
  | "tickets"
  | null;

const SESSION_TOKEN_KEY = "session_token";

export default function MobileRoot() {
  const [activeTab, setActiveTab] = useState<TabKey>("home");
  const [lastContentTab, setLastContentTab] = useState<TabKey>("home");
  const [overlay, setOverlay] = useState<OverlayKey>(null);
  const [loading, setLoading] = useState(true);
  const [sessionToken, setSessionTokenState] = useState("");
  const [phoneNumber, setPhoneNumber] = useState("");
  const [selectedCity, setSelectedCity] = useState("");
  const [rideAccessEnabled, setRideAccessEnabled] = useState(false);
  const [trialRidesRemaining, setTrialRidesRemaining] = useState(0);
  const [accessRequestTelegram, setAccessRequestTelegram] = useState("@aqxrx");
  const [walletState, setWalletState] = useState<WalletState>(emptyWalletState);

  useEffect(() => {
    let mounted = true;

    async function restoreSession() {
      const storedToken = (await AsyncStorage.getItem(SESSION_TOKEN_KEY)) ?? "";
      if (!storedToken) {
        if (mounted) {
          setOverlay("login");
          setLoading(false);
        }
        return;
      }

      try {
        setApiSessionToken(storedToken);
        const session = await getAuthSession();
        if (!mounted) {
          return;
        }
        applyAuthSession(storedToken, session);
      } catch {
        await AsyncStorage.removeItem(SESSION_TOKEN_KEY);
        setApiSessionToken(null);
        if (mounted) {
          setSessionTokenState("");
          setPhoneNumber("");
          setSelectedCity("");
          setRideAccessEnabled(false);
          setTrialRidesRemaining(0);
          setAccessRequestTelegram("@aqxrx");
          setWalletState(emptyWalletState);
          setOverlay("login");
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    }

    void restoreSession();

    return () => {
      mounted = false;
    };
  }, []);

  const applyAuthSession = (token: string, session: AuthSessionDto) => {
    setSessionTokenState(token);
    setPhoneNumber(session.user.phoneNumber);
    setSelectedCity(session.user.cityName || "");
    setRideAccessEnabled(session.user.rideAccessEnabled);
    setTrialRidesRemaining(session.user.trialRidesRemaining);
    setAccessRequestTelegram(session.config.accessRequestTelegram || "@aqxrx");
    setWalletState(hydrateWalletState(session.wallet));
    setOverlay(session.user.cityName ? null : "city");
  };

  const refreshSession = async () => {
    const session = await getAuthSession();
    applyAuthSession(sessionToken, session);
  };

  const currentCity = selectedCity || "Актау";
  const currentPhone = phoneNumber || "+7 700-255-56-19";
  const activeCard = getActiveCard(walletState);
  const activeTransportCard = activeCard?.cardType === "transport" ? activeCard : null;

  const openTab = (tab: TabKey) => {
    if (tab === "qr") {
      setLastContentTab(activeTab === "qr" ? lastContentTab : activeTab);
    } else {
      setLastContentTab(tab);
    }
    setActiveTab(tab);
  };

  const handleRequestCode = async (value: string) => {
    const result = await requestAuthCode({
      phoneNumber: value,
      cityName: selectedCity || undefined,
    });
    setPhoneNumber(result.phoneNumber);
    return {
      phoneNumber: result.phoneNumber,
      debugCode: result.debugCode,
      deliveryStatus: result.delivery?.status ?? "",
      deliveryError: result.delivery?.error,
      supportTelegram: result.supportTelegram,
      telegramBind: result.telegramBind,
    };
  };

  const handleVerifyCode = async (value: string, code: string) => {
    const session = await verifyAuthCode({
      phoneNumber: value,
      code,
      cityName: selectedCity || undefined,
    });
    setApiSessionToken(session.token);
    await AsyncStorage.setItem(SESSION_TOKEN_KEY, session.token);
    applyAuthSession(session.token, session);
  };

  const saveCity = async (value: string) => {
    await updateProfile({ cityName: value });
    setSelectedCity(value);
    setOverlay(null);
  };

  const logout = async () => {
    try {
      await logoutAuth();
    } catch {
      // ignore logout transport errors during local development
    }
    await AsyncStorage.removeItem(SESSION_TOKEN_KEY);
    setApiSessionToken(null);
    setSessionTokenState("");
    setPhoneNumber("");
    setSelectedCity("");
    setRideAccessEnabled(false);
    setTrialRidesRemaining(0);
    setAccessRequestTelegram("@aqxrx");
    setWalletState(emptyWalletState);
    setActiveTab("home");
    setLastContentTab("home");
    setOverlay("login");
  };

  const addCard = async (
    holderName: string,
    number: string,
    cardType: "bank" | "transport",
  ) => {
    await addWalletCard({ holderName, number, cardType });
    await refreshSession();
  };

  const setActiveCard = async (cardId: string) => {
    await activateWalletCard(cardId);
    await refreshSession();
  };

  const topUpBalance = async (amount: number, targetType: "wallet" | "transport") => {
    const nextWallet = await topUpWallet({
      amount,
      cardId: walletState.activeCardId,
      targetType,
      transportCardId: targetType === "transport" ? walletState.activeCardId : null,
    });
    setWalletState(hydrateWalletState(nextWallet));
    setOverlay(null);
  };

  const requestAccess = async () => {
    const result = await requestRideAccess({
      phoneNumber: currentPhone,
      cityName: currentCity,
    });
    setAccessRequestTelegram(result.telegramUsername || "@aqxrx");
    await refreshSession();
  };

  const refreshWalletAfterPayment = async (_amount: number) => {
    await refreshSession();
  };

  let content: ReactNode;

  if (loading) {
    content = <SafeAreaView style={styles.loading} />;
  } else if (overlay === "login") {
    content = (
      <LoginScreen
        onRequestCode={handleRequestCode}
        onVerifyCode={handleVerifyCode}
      />
    );
  } else if (overlay === "city") {
    content = (
      <CityScreen
        selectedCity={currentCity}
        showBack={Boolean(selectedCity && sessionToken)}
        onBack={() => setOverlay(null)}
        onSelectCity={(value) => void saveCity(value)}
      />
    );
  } else if (overlay === "payments") {
    content = (
      <PaymentsScreen
        onBack={() => setOverlay(null)}
        onOpenTransfers={() => setOverlay("transfers")}
      />
    );
  } else if (overlay === "transfers") {
    content = <TransfersScreen onBack={() => setOverlay(null)} />;
  } else if (overlay === "bluetooth") {
    content = (
      <BluetoothScannerScreen
        phoneNumber={currentPhone}
        cityName={currentCity}
        walletBalance={walletState.balance}
        activeTransportCard={activeTransportCard}
        onBack={() => setOverlay(null)}
        onPaid={(amount) => void refreshWalletAfterPayment(amount)}
      />
    );
  } else if (overlay === "plate") {
    content = (
      <BusSearchScreen
        mode="plate"
        phoneNumber={currentPhone}
        cityName={currentCity}
        walletBalance={walletState.balance}
        activeTransportCard={activeTransportCard}
        onBack={() => setOverlay(null)}
        onPaid={(amount) => void refreshWalletAfterPayment(amount)}
      />
    );
  } else if (overlay === "settings") {
    content = (
      <SettingsScreen
        phoneNumber={currentPhone}
        city={currentCity}
        walletState={walletState}
        rideAccessEnabled={rideAccessEnabled}
        trialRidesRemaining={trialRidesRemaining}
        accessRequestTelegram={accessRequestTelegram}
        onBack={() => setOverlay(null)}
        onLogout={logout}
        onOpenCards={() => setOverlay("cards")}
        onRequestAccess={() => void requestAccess()}
      />
    );
  } else if (overlay === "cards") {
    content = (
      <CardsScreen
        walletState={walletState}
        onBack={() => setOverlay(null)}
        onAddCard={(holderName, number, cardType) =>
          void addCard(holderName, number, cardType)
        }
        onSetActiveCard={(cardId) => void setActiveCard(cardId)}
      />
    );
  } else if (overlay === "topup") {
    content = (
      <TopUpScreen
        balance={walletState.balance}
        activeCard={activeCard}
        onBack={() => setOverlay(null)}
        onTopUp={(amount, targetType) => void topUpBalance(amount, targetType)}
      />
    );
  } else if (overlay === "tickets") {
    content = <TicketsScreen phoneNumber={currentPhone} onBack={() => setOverlay(null)} />;
  } else if (activeTab === "qr") {
    content = (
      <QrScannerPaymentScreen
        phoneNumber={currentPhone}
        cityName={currentCity}
        walletBalance={walletState.balance}
        activeTransportCard={activeTransportCard}
        onBack={() => openTab(lastContentTab)}
        onPaid={(amount) => void refreshWalletAfterPayment(amount)}
      />
    );
  } else {
    content = (
      <View style={styles.app}>
        <StatusBar style="dark" />
        <SafeAreaView style={styles.safeArea}>
          <View style={styles.screenShell}>
            {activeTab === "home" && (
              <HomeTab
                walletState={walletState}
                onOpenQr={() => openTab("qr")}
                onOpenBluetooth={() => setOverlay("bluetooth")}
                onOpenPlate={() => setOverlay("plate")}
                onOpenPayments={() => setOverlay("payments")}
                onOpenTransfers={() => setOverlay("transfers")}
                onOpenTickets={() => setOverlay("tickets")}
                onOpenCards={() => setOverlay("cards")}
                onOpenTopUp={() => setOverlay("topup")}
              />
            )}
            {activeTab === "routes" && (
              <RoutesTab city={currentCity} onOpenCity={() => setOverlay("city")} />
            )}
            {activeTab === "notifications" && (
              <NotificationsTab onBack={() => openTab("menu")} />
            )}
            {activeTab === "menu" && (
              <MenuTab
                city={currentCity}
                bankCardSubtitle={activeCard ? maskCardNumber(activeCard.number) : "Добавить карту"}
                onOpenNotifications={() => openTab("notifications")}
                onOpenCity={() => setOverlay("city")}
                onOpenSettings={() => setOverlay("settings")}
                onOpenCards={() => setOverlay("cards")}
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

  return <WebAppFrame>{content}</WebAppFrame>;
}

const styles = StyleSheet.create({
  app: { flex: 1, backgroundColor: "#FFFFFF" },
  safeArea: { flex: 1, backgroundColor: "#FFFFFF" },
  screenShell: { flex: 1, backgroundColor: colors.background },
  loading: { flex: 1, backgroundColor: "#FFFFFF" },
});
