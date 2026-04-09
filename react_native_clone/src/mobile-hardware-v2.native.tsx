import React, { useEffect, useRef, useState } from "react";
import { MaterialIcons } from "@expo/vector-icons";
import { CameraView, useCameraPermissions } from "expo-camera";
import { BleManager, type Device, State } from "react-native-ble-plx";
import { NativeModules, PermissionsAndroid, Platform, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import {
  addBus,
  createTicket,
  getBuses,
  getCities,
  getTariffs,
  type ApiRequestError,
  type BusDto,
  type TariffDto,
  type TicketDto,
} from "./api";
import { TicketModal } from "./mobile-ticket-modal";
import { colors, shadow } from "./theme";
import { formatBalance, type WalletCardData } from "./wallet-store";

type HardwareProps = {
  phoneNumber: string;
  cityName: string;
  walletBalance: number;
  activeTransportCard: WalletCardData | null;
  onBack: () => void;
  onPaid: (amount: number) => void;
};

type ValidatorItem = { id: string; label: string; raw: Device; bus: BusDto | null };
type Stage = "scan" | "details" | "add";
type PayMethod = "wallet" | "transport-card" | "bank-card" | "kaspi";

const hasNativeBle = Boolean((NativeModules as Record<string, unknown>).BleClientManager);
const colorsList = ["#2F7DF6", "#FF6D7A", "#55C271", "#B4C94D", "#A57A37", "#D1B77A"];

export function BluetoothScannerScreen(props: HardwareProps) {
  const managerRef = useRef<BleManager | null>(null);
  const [cityId, setCityId] = useState("");
  const [tariffs, setTariffs] = useState<TariffDto[]>([]);
  const [tariffId, setTariffId] = useState("");
  const [routeNumber, setRouteNumber] = useState("");
  const [validators, setValidators] = useState<ValidatorItem[]>([]);
  const [selected, setSelected] = useState<ValidatorItem | null>(null);
  const [stage, setStage] = useState<Stage>("scan");
  const [ticket, setTicket] = useState<TicketDto | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const cities = await getCities();
        const city = cities.find((item) => item.name === props.cityName) ?? cities[0];
        const nextCityId = city?.id ?? "";
        const nextTariffs = nextCityId ? await getTariffs(nextCityId) : [];
        if (!active) {
          return;
        }
        setCityId(nextCityId);
        setTariffs(nextTariffs);
        setTariffId(nextTariffs[0]?.id ?? "");
      } catch (nextError) {
        if (active) {
          setError(formatApiError(nextError, "Не удалось загрузить тарифы"));
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [props.cityName]);

  useEffect(() => {
    if (!cityId) {
      return;
    }
    if (!hasNativeBle) {
      setLoading(false);
      setError("BLE работает только в dev build. В Expo Go недоступен.");
      return;
    }

    let mounted = true;
    void (async () => {
      const granted = await requestBlePermissions();
      if (!mounted) {
        return;
      }
      if (!granted) {
        setLoading(false);
        setError("Нет доступа к Bluetooth");
        return;
      }

      const manager = new BleManager();
      managerRef.current = manager;
      setLoading(false);

      const state = await manager.state();
      if (state !== State.PoweredOn) {
        const sub = manager.onStateChange((next) => {
          if (next === State.PoweredOn) {
            sub.remove();
            startScan(manager, cityId, setValidators, setError);
          }
        }, true);
        return;
      }

      startScan(manager, cityId, setValidators, setError);
    })();

    return () => {
      mounted = false;
      managerRef.current?.stopDeviceScan();
      managerRef.current?.destroy();
      managerRef.current = null;
    };
  }, [cityId]);

  async function handleSelect(item: ValidatorItem) {
    const bus = item.bus ?? (await findBus(cityId, item.label));
    const next = { ...item, bus };
    setSelected(next);
    setValidators((current) => current.map((candidate) => (candidate.id === item.id ? next : candidate)));
    setStage(bus ? "details" : "add");
  }

  async function handleAddBus() {
    if (!selected || !tariffId || !routeNumber.trim()) {
      return;
    }
    try {
      const bus = await addBus({
        cityId,
        tariffId,
        number: normalizeTransportValue(selected.label),
        routeNumber: routeNumber.trim(),
      });
      const next = { ...selected, bus };
      setSelected(next);
      setValidators((current) => current.map((candidate) => (candidate.id === selected.id ? next : candidate)));
      setStage("details");
      setError("");
    } catch (nextError) {
      setError(formatApiError(nextError, "Не удалось добавить автобус"));
    }
  }

  async function handlePay(method: PayMethod) {
    if (!selected?.bus) {
      return;
    }
    if (method === "wallet" && props.walletBalance < selected.bus.price) {
      setError("Недостаточно баланса");
      return;
    }
    if (method === "transport-card") {
      if (!props.activeTransportCard) {
        setError("Сначала выберите активную транспортную карту");
        return;
      }
      if ((props.activeTransportCard.balance || 0) < selected.bus.price) {
        setError("Недостаточно баланса на транспортной карте");
        return;
      }
    }

    try {
      const created = await createTicket({
        phoneNumber: props.phoneNumber,
        busId: selected.bus.id,
        paymentMethod: method,
        cityId,
        cityName: props.cityName,
      });
      props.onPaid(selected.bus.price);
      setTicket(created);
      setError("");
    } catch (nextError) {
      setError(formatApiError(nextError, "Не удалось провести оплату"));
    }
  }

  const goBack = () => {
    if (stage === "scan") {
      props.onBack();
    } else {
      setStage("scan");
    }
  };

  const transportSubtitle = props.activeTransportCard
    ? `${props.activeTransportCard.holderName} • ${formatBalance(props.activeTransportCard.balance || 0)} ₸`
    : "Сначала выберите активную транспортную карту";

  return (
    <View style={styles.screen}>
      <Header title="Bluetooth төлем" onBack={goBack} />
      {stage === "scan" ? (
        <>
          <WalletBanner phoneNumber={props.phoneNumber} balance={props.walletBalance} />
          <ScrollView showsVerticalScrollIndicator={false}>
            {loading ? <Empty text="Bluetooth құрылғылары ізделуде..." /> : null}
            {!loading && validators.length === 0 ? <Empty text="Қолжетімді валидатор табылмады." /> : null}
            {validators.map((item, index) => (
              <Pressable key={item.id} style={styles.listRow} onPress={() => void handleSelect(item)}>
                <View style={[styles.dot, { backgroundColor: colorsList[index % colorsList.length] }]}>
                  <MaterialIcons name="directions-bus" size={18} color="#FFF" />
                </View>
                <View style={styles.rowCopy}>
                  <Text style={styles.rowTitle}>{item.bus ? `Маршрут ${item.bus.routeNumber}` : "Автобус табылмады"}</Text>
                  <Text style={styles.rowSubtitle}>Көлік нөмірі: {item.label}</Text>
                </View>
              </Pressable>
            ))}
            <Text style={styles.helper}>Өзіңіздікін таппадыңыз ба?</Text>
            <Pressable
              style={styles.ghost}
              onPress={() => {
                setValidators([]);
                setSelected(null);
                setStage("scan");
                setError("");
                if (managerRef.current && cityId) {
                  managerRef.current.stopDeviceScan();
                  startScan(managerRef.current, cityId, setValidators, setError);
                }
              }}
            >
              <Text style={styles.ghostText}>Қайтадан іздеу</Text>
            </Pressable>
            {error ? <Text style={styles.error}>{error}</Text> : null}
          </ScrollView>
        </>
      ) : null}

      {stage === "add" && selected ? (
        <ScrollView showsVerticalScrollIndicator={false}>
          <Empty text="Бұл құрылғы базаға тіркелмеген. Жаңа автобус қосыңыз." />
          <View style={styles.form}>
            <Text style={styles.labelPlain}>Көлік нөмірі</Text>
            <Text style={styles.valuePlain}>{normalizeTransportValue(selected.label)}</Text>
            <TextInput value={routeNumber} onChangeText={setRouteNumber} placeholder="Маршрут, мысалы №12" placeholderTextColor={colors.textSecondary} style={styles.field} />
            {tariffs.map((item) => (
              <Pressable key={item.id} style={[styles.tariffRow, item.id === tariffId && styles.tariffRowActive]} onPress={() => setTariffId(item.id)}>
                <Text style={styles.tariffName}>{item.name}</Text>
                <Text style={styles.tariffPrice}>{item.price} ₸</Text>
              </Pressable>
            ))}
            <PrimaryButton label="Жаңа автобус қосу" disabled={!routeNumber.trim() || !tariffId} onPress={() => void handleAddBus()} />
          </View>
          {error ? <Text style={styles.error}>{error}</Text> : null}
        </ScrollView>
      ) : null}

      {stage === "details" && selected?.bus ? (
        <ScrollView showsVerticalScrollIndicator={false}>
          <SummaryCard bus={selected.bus} />
          <PaymentRow title="Әмиян" subtitle={`Баланс: ${formatBalance(props.walletBalance)} ₸`} icon="account-balance-wallet" iconColor={colors.primaryBlue} iconBg="#EEF3FF" onPress={() => void handlePay("wallet")} />
          <PaymentRow title="Транспорт картасы" subtitle={transportSubtitle} icon="directions-bus" iconColor="#1FA868" iconBg="#E8FFF2" onPress={() => void handlePay("transport-card")} disabled={!props.activeTransportCard} />
          <PaymentRow title="Kaspi.kz" subtitle="MVP төлем тәсілі" icon="payments" iconColor="#EA3F34" iconBg="#FFF0EE" onPress={() => void handlePay("kaspi")} />
          <PaymentRow title="Банк картасымен" subtitle="Қосылған картамен төлеу" icon="credit-card" iconColor="#FFB800" iconBg="#FFF6D9" onPress={() => void handlePay("bank-card")} />
          {error ? <Text style={styles.error}>{error}</Text> : null}
        </ScrollView>
      ) : null}

      <TicketModal
        ticket={ticket}
        onClose={() => setTicket(null)}
        labels={{ transportCaption: "Нөмір транспорта", ticketTitle: "Менің билетім" }}
      />
    </View>
  );
}

export function QrScannerPaymentScreen(props: HardwareProps) {
  const [permission, requestPermission] = useCameraPermissions();
  const [cityId, setCityId] = useState("");
  const [flash, setFlash] = useState(false);
  const [scanned, setScanned] = useState(false);
  const [bus, setBus] = useState<BusDto | null>(null);
  const [ticket, setTicket] = useState<TicketDto | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    void (async () => {
      const cities = await getCities();
      const city = cities.find((item) => item.name === props.cityName) ?? cities[0];
      if (active) {
        setCityId(city?.id ?? "");
      }
    })().catch((nextError) => setError(formatApiError(nextError, "Не удалось загрузить город")));
    return () => {
      active = false;
    };
  }, [props.cityName]);

  useEffect(() => {
    if (permission && !permission.granted) {
      void requestPermission();
    }
  }, [permission, requestPermission]);

  async function handlePay(method: PayMethod) {
    if (!bus) {
      return;
    }
    if (method === "wallet" && props.walletBalance < bus.price) {
      setError("Недостаточно баланса");
      return;
    }
    if (method === "transport-card") {
      if (!props.activeTransportCard) {
        setError("Сначала выберите активную транспортную карту");
        return;
      }
      if ((props.activeTransportCard.balance || 0) < bus.price) {
        setError("Недостаточно баланса на транспортной карте");
        return;
      }
    }

    try {
      const created = await createTicket({
        phoneNumber: props.phoneNumber,
        busId: bus.id,
        paymentMethod: method,
        cityId,
        cityName: props.cityName,
      });
      props.onPaid(bus.price);
      setTicket(created);
      setError("");
    } catch (nextError) {
      setError(formatApiError(nextError, "Не удалось провести оплату"));
    }
  }

  if (!permission) {
    return <View style={styles.screen} />;
  }

  if (!permission.granted) {
    return (
      <View style={styles.screen}>
        <Header title="QR төлем" onBack={props.onBack} />
        <Empty text="QR сканерлеу үшін камера рұқсаты керек." />
        <PrimaryButton label="Камераны қосу" disabled={false} onPress={() => void requestPermission()} />
      </View>
    );
  }

  const transportSubtitle = props.activeTransportCard
    ? `${props.activeTransportCard.holderName} • ${formatBalance(props.activeTransportCard.balance || 0)} ₸`
    : "Сначала выберите активную транспортную карту";

  return (
    <View style={styles.scanner}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        enableTorch={flash}
        videoStabilizationMode="standard"
        barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
        onBarcodeScanned={async ({ data }) => {
          if (scanned || !cityId) {
            return;
          }
          setScanned(true);
          try {
            const byQr = await getBuses(cityId, { qrToken: data.trim() });
            const nextBus = byQr[0] ?? (await getBuses(cityId, { number: normalizeTransportValue(data) }))[0] ?? null;
            setBus(nextBus);
            if (!nextBus) {
              setError("QR бойынша автобус табылмады");
            }
          } catch (nextError) {
            setError(formatApiError(nextError, "QR кодын оқу мүмкін болмады"));
          }
        }}
      />
      <View style={styles.shade} />
      <SafeAreaView style={styles.flex}>
        <View style={styles.scannerTop}>
          <RoundButton icon={flash ? "flash-off" : "flash-on"} onPress={() => setFlash((value) => !value)} />
          <RoundButton icon="close" onPress={props.onBack} />
        </View>
        <View style={styles.frame} />
        <View style={styles.hint}><Text style={styles.hintText}>{bus ? "Автобус табылды" : "Камераны QR-кодқа бағыттаңыз"}</Text></View>
        <View style={styles.bottom}>
          {bus ? (
            <View style={styles.sheet}>
              <SummaryCard bus={bus} compact />
              <PaymentRow title="Әмиян" subtitle={`Баланс: ${formatBalance(props.walletBalance)} ₸`} icon="account-balance-wallet" iconColor={colors.primaryBlue} iconBg="#EEF3FF" onPress={() => void handlePay("wallet")} />
              <PaymentRow title="Транспорт картасы" subtitle={transportSubtitle} icon="directions-bus" iconColor="#1FA868" iconBg="#E8FFF2" onPress={() => void handlePay("transport-card")} disabled={!props.activeTransportCard} />
              <PaymentRow title="Kaspi.kz" subtitle="MVP төлем тәсілі" icon="payments" iconColor="#EA3F34" iconBg="#FFF0EE" onPress={() => void handlePay("kaspi")} />
              <PaymentRow title="Банк картасымен" subtitle="Қосылған картамен төлеу" icon="credit-card" iconColor="#FFB800" iconBg="#FFF6D9" onPress={() => void handlePay("bank-card")} />
              <Pressable style={styles.ghost} onPress={() => { setBus(null); setScanned(false); setError(""); }}>
                <Text style={styles.ghostText}>Қайта сканерлеу</Text>
              </Pressable>
            </View>
          ) : (
            <WalletBanner phoneNumber={props.phoneNumber} balance={props.walletBalance} />
          )}
          {error ? <Text style={styles.errorOnDark}>{error}</Text> : null}
        </View>
      </SafeAreaView>
      <TicketModal
        ticket={ticket}
        onClose={() => setTicket(null)}
        labels={{ transportCaption: "Нөмір транспорта", ticketTitle: "Менің билетім" }}
      />
    </View>
  );
}

async function findBus(cityId: string, label: string) {
  const query = normalizeTransportValue(label);
  const buses = await getBuses(cityId, { number: query });
  return buses.find((item) => normalizeTransportValue(item.number) === query || normalizeTransportValue(item.validatorName || "") === query) ?? buses[0] ?? null;
}

function startScan(
  manager: BleManager,
  cityId: string,
  setValidators: React.Dispatch<React.SetStateAction<ValidatorItem[]>>,
  setError: React.Dispatch<React.SetStateAction<string>>,
) {
  manager.startDeviceScan(null, null, (scanError, device) => {
    if (scanError) {
      setError(scanError.message);
      return;
    }
    if (!device) {
      return;
    }

    const label = device.localName || device.name || device.id;
    if (!label) {
      return;
    }

    setValidators((current) => {
      if (current.some((item) => item.id === device.id)) {
        return current;
      }
      return [{ id: device.id, label, raw: device, bus: null }, ...current].slice(0, 20);
    });

    void findBus(cityId, label)
      .then((bus) => {
        setValidators((current) => current.map((item) => (item.id === device.id ? { ...item, bus } : item)));
      })
      .catch(() => {
        // keep unresolved item in list
      });
  });
}

async function requestBlePermissions() {
  if (Platform.OS !== "android") {
    return true;
  }
  if (Platform.Version >= 31) {
    const scan = (PermissionsAndroid.PERMISSIONS as Record<string, unknown>).BLUETOOTH_SCAN as string;
    const connect = (PermissionsAndroid.PERMISSIONS as Record<string, unknown>).BLUETOOTH_CONNECT as string;
    const permissions = [scan, connect, PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION].filter(Boolean) as string[];
    const result = await PermissionsAndroid.requestMultiple(permissions as never);
    return permissions.every((permission) => result[permission as keyof typeof result] === PermissionsAndroid.RESULTS.GRANTED);
  }
  const location = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION);
  return location === PermissionsAndroid.RESULTS.GRANTED;
}

function normalizeTransportValue(value: string) {
  return value.replace(/[^0-9A-Za-z]/g, "").toUpperCase();
}

function formatApiError(error: unknown, fallback: string) {
  const apiError = error as ApiRequestError | undefined;
  if (apiError?.code === "ACCESS_REQUIRED") {
    return `Доступ к оплате закрыт. Напишите ${apiError.supportTelegram || "@aqxrx"} для активации.`;
  }
  return error instanceof Error ? error.message : fallback;
}

function Header({ title, onBack }: { title: string; onBack: () => void }) {
  return <View style={styles.header}><Pressable style={styles.headerBack} onPress={onBack}><MaterialIcons name="arrow-back-ios-new" size={28} color={colors.textPrimary} /></Pressable><Text style={styles.headerTitle}>{title}</Text><View style={styles.headerBack} /></View>;
}
function WalletBanner({ phoneNumber, balance }: { phoneNumber: string; balance: number }) {
  return <View style={styles.wallet}><View style={styles.walletRow}><Text style={styles.walletTitle}>Әмиян</Text><Text style={styles.walletAmount}>{formatBalance(balance)} ₸</Text></View><Text style={styles.walletSubtitle}>{phoneNumber} • Стандарт</Text></View>;
}
function SummaryCard({ bus, compact = false }: { bus: BusDto; compact?: boolean }) {
  return <View style={[styles.summary, compact && styles.summaryCompact]}><View style={styles.summaryBadge}><MaterialIcons name="directions-bus" size={22} color={colors.banner} /></View><LabelValue label="Көлік нөмірі" value={bus.number} /><LabelValue label="Маршрут" value={bus.routeNumber} /><LabelValue label="Тариф" value={bus.tariffName} /><LabelValue label="Қала" value={bus.cityName} /><LabelValue label="Жол жүру сомасы" value={`${bus.price} ₸`} strong /></View>;
}
function LabelValue({ label, value, strong = false }: { label: string; value: string; strong?: boolean }) {
  return <View style={styles.labelBlock}><Text style={styles.label}>{label}</Text><Text style={[styles.valueText, strong && styles.valueStrong]}>{value}</Text></View>;
}
function PaymentRow({ title, subtitle, icon, iconColor, iconBg, onPress, disabled = false }: { title: string; subtitle: string; icon: string; iconColor: string; iconBg: string; onPress: () => void; disabled?: boolean }) {
  return <Pressable style={[styles.payRow, disabled && styles.payRowDisabled]} onPress={disabled ? undefined : onPress}><View style={[styles.payIcon, { backgroundColor: iconBg }]}><MaterialIcons name={icon as never} size={24} color={iconColor} /></View><View style={styles.payCopy}><Text style={styles.payTitle}>{title}</Text><Text style={styles.paySubtitle}>{subtitle}</Text></View><MaterialIcons name="chevron-right" size={28} color={colors.textSecondary} /></Pressable>;
}
function Empty({ text }: { text: string }) {
  return <View style={styles.empty}><Text style={styles.emptyText}>{text}</Text></View>;
}
function PrimaryButton({ label, disabled, onPress }: { label: string; disabled: boolean; onPress: () => void }) {
  return <Pressable style={[styles.primary, disabled && styles.primaryDisabled]} onPress={disabled ? undefined : onPress}><Text style={styles.primaryText}>{label}</Text></Pressable>;
}
function RoundButton({ icon, onPress }: { icon: string; onPress: () => void }) {
  return <Pressable style={styles.round} onPress={onPress}><MaterialIcons name={icon as never} size={24} color="#FFF" /></Pressable>;
}
const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: { flex: 1, backgroundColor: "#FFF", paddingHorizontal: 24, paddingBottom: 24 },
  header: { height: 56, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  headerBack: { width: 40, justifyContent: "center", alignItems: "flex-start" },
  headerTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  wallet: { marginTop: 18, backgroundColor: colors.banner, borderRadius: 22, padding: 20 },
  walletRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  walletTitle: { color: "#FFF", fontSize: 18, fontWeight: "700" },
  walletAmount: { color: "#FFF", fontSize: 20, fontWeight: "700" },
  walletSubtitle: { marginTop: 10, color: "#D7DCEC", fontSize: 15 },
  listRow: { flexDirection: "row", alignItems: "center", paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: colors.border },
  dot: { width: 28, height: 28, borderRadius: 14, alignItems: "center", justifyContent: "center" },
  rowCopy: { marginLeft: 12, flex: 1 },
  rowTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  rowSubtitle: { marginTop: 4, fontSize: 15, color: colors.textSecondary },
  helper: { textAlign: "center", marginTop: 20, marginBottom: 12, color: colors.textSecondary, fontSize: 15 },
  ghost: { minHeight: 56, borderRadius: 16, backgroundColor: colors.surfaceMuted, alignItems: "center", justifyContent: "center", marginTop: 8 },
  ghostText: { fontSize: 16, color: colors.textSecondary },
  error: { marginTop: 14, color: "#C62828", fontSize: 14 },
  errorOnDark: { marginTop: 14, color: "#FFF", textAlign: "center", fontSize: 14 },
  empty: { marginTop: 18, borderRadius: 22, padding: 20, backgroundColor: colors.surfaceMuted },
  emptyText: { fontSize: 16, lineHeight: 22, color: colors.textSecondary },
  form: { marginTop: 18, borderRadius: 22, padding: 18, backgroundColor: colors.surfaceMuted },
  labelPlain: { fontSize: 13, color: colors.textSecondary },
  valuePlain: { marginTop: 4, fontSize: 22, fontWeight: "700", color: colors.textPrimary },
  field: { height: 58, marginTop: 12, borderRadius: 16, backgroundColor: "#FFF", paddingHorizontal: 16, fontSize: 16, color: colors.textPrimary },
  tariffRow: { marginTop: 10, borderRadius: 16, backgroundColor: "#FFF", padding: 14, flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  tariffRowActive: { borderWidth: 1.5, borderColor: colors.primaryBlue },
  tariffName: { fontSize: 15, color: colors.textPrimary },
  tariffPrice: { fontSize: 15, fontWeight: "700", color: colors.textPrimary },
  primary: { height: 64, marginTop: 20, borderRadius: 18, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center" },
  primaryDisabled: { backgroundColor: "#C8C8C8" },
  primaryText: { color: "#FFF", fontSize: 18 },
  summary: { marginTop: 18, borderRadius: 22, backgroundColor: colors.banner, padding: 18 },
  summaryCompact: { marginTop: 0 },
  summaryBadge: { position: "absolute", top: 16, right: 16, width: 46, height: 46, borderRadius: 23, backgroundColor: "#FFF", alignItems: "center", justifyContent: "center" },
  labelBlock: { marginTop: 10 },
  label: { fontSize: 13, color: "#D7DCEC" },
  valueText: { marginTop: 4, fontSize: 20, color: "#FFF" },
  valueStrong: { fontSize: 28, fontWeight: "700" },
  payRow: { marginTop: 12, borderRadius: 18, padding: 14, backgroundColor: "#FFF", flexDirection: "row", alignItems: "center", ...shadow },
  payRowDisabled: { opacity: 0.55 },
  payIcon: { width: 46, height: 46, borderRadius: 23, alignItems: "center", justifyContent: "center" },
  payCopy: { flex: 1, marginLeft: 12 },
  payTitle: { fontSize: 16, fontWeight: "600", color: colors.textPrimary },
  paySubtitle: { marginTop: 4, fontSize: 13, color: colors.textSecondary },
  scanner: { flex: 1, backgroundColor: "#101318" },
  shade: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(6,8,12,0.28)" },
  scannerTop: { flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 22, paddingTop: 10 },
  round: { width: 42, height: 42, borderRadius: 21, backgroundColor: "rgba(255,255,255,0.28)", alignItems: "center", justifyContent: "center" },
  frame: { alignSelf: "center", marginTop: 160, width: 280, height: 280, borderRadius: 24, borderWidth: 4, borderColor: "rgba(54,79,214,0.88)", backgroundColor: "rgba(255,255,255,0.08)" },
  hint: { alignSelf: "center", marginTop: 20, borderRadius: 18, backgroundColor: "rgba(91,99,127,0.82)", paddingHorizontal: 20, paddingVertical: 14 },
  hintText: { color: "#D7DCEC", fontSize: 15 },
  bottom: { marginTop: "auto", paddingHorizontal: 24, paddingBottom: 34 },
  sheet: { backgroundColor: "#FFF", borderRadius: 24, padding: 20, ...shadow },
});
