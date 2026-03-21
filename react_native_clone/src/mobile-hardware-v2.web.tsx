import React, { useEffect, useState } from "react";
import { MaterialIcons } from "@expo/vector-icons";
import { CameraView, useCameraPermissions } from "expo-camera";
import QRCode from "react-native-qrcode-svg";
import { Modal, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

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

type WebValidator = { id: string; label: string; bus: BusDto | null };
type Stage = "scan" | "details" | "add";
type PayMethod = "wallet" | "transport-card" | "bank-card" | "kaspi";

const browserBluetooth =
  typeof navigator !== "undefined"
    ? (navigator as Navigator & {
        bluetooth?: { requestDevice?: (options: unknown) => Promise<{ id?: string; name?: string }> };
      }).bluetooth
    : undefined;

export function BluetoothScannerScreen(props: HardwareProps) {
  const [cityId, setCityId] = useState("");
  const [tariffs, setTariffs] = useState<TariffDto[]>([]);
  const [tariffId, setTariffId] = useState("");
  const [routeNumber, setRouteNumber] = useState("");
  const [validators, setValidators] = useState<WebValidator[]>([]);
  const [selected, setSelected] = useState<WebValidator | null>(null);
  const [stage, setStage] = useState<Stage>("scan");
  const [ticket, setTicket] = useState<TicketDto | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    void (async () => {
      try {
        const cities = await getCities();
        const city = cities.find((item) => item.name === props.cityName) ?? cities[0];
        const nextCityId = city?.id ?? "";
        const nextTariffs = nextCityId ? await getTariffs(nextCityId) : [];
        setCityId(nextCityId);
        setTariffs(nextTariffs);
        setTariffId(nextTariffs[0]?.id ?? "");
      } catch (nextError) {
        setError(formatApiError(nextError, "Не удалось загрузить тарифы"));
      }
    })();
  }, [props.cityName]);

  async function searchBluetooth() {
    if (!browserBluetooth?.requestDevice) {
      setError("Web Bluetooth в браузере не поддерживается.");
      return;
    }

    try {
      const device = await browserBluetooth.requestDevice({ acceptAllDevices: true });
      const label = device.name || device.id || "Unknown device";
      const bus = await findBus(cityId, label);
      const nextItem = { id: device.id || label, label, bus };
      setValidators((current) =>
        current.some((item) => item.id === nextItem.id)
          ? current.map((item) => (item.id === nextItem.id ? nextItem : item))
          : [nextItem, ...current],
      );
      setError("");
    } catch (nextError) {
      setError(formatApiError(nextError, "Устройство не выбрано"));
    }
  }

  async function handleSelect(item: WebValidator) {
    const bus = item.bus ?? (await findBus(cityId, item.label));
    const next = { ...item, bus };
    setSelected(next);
    setValidators((current) => current.map((candidate) => (candidate.id === item.id ? next : candidate)));
    setStage(bus ? "details" : "add");
  }

  async function handleAddBus() {
    if (!selected || !routeNumber.trim() || !tariffId) {
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
      setError("Недостаточно баланса в кошельке");
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

  const transportSubtitle = props.activeTransportCard
    ? `${props.activeTransportCard.holderName} • ${formatBalance(props.activeTransportCard.balance || 0)} ₸`
    : "Сначала выберите активную транспортную карту";

  const back = () => {
    if (stage === "scan") {
      props.onBack();
    } else {
      setStage("scan");
    }
  };

  return (
    <View style={styles.screen}>
      <Header title="Bluetooth төлем" onBack={back} />
      {stage === "scan" ? (
        <>
          <WalletBanner phoneNumber={props.phoneNumber} balance={props.walletBalance} />
          <ScrollView showsVerticalScrollIndicator={false}>
            {validators.length === 0 ? (
              <Empty text="Bluetooth құрылғысын іздеу үшін браузер chooser ашылады." />
            ) : null}
            {validators.map((item) => (
              <Pressable key={item.id} style={styles.listRow} onPress={() => void handleSelect(item)}>
                <View style={styles.dot}>
                  <MaterialIcons name="directions-bus" size={18} color="#FFF" />
                </View>
                <View style={styles.rowCopy}>
                  <Text style={styles.rowTitle}>
                    {item.bus ? `Маршрут ${item.bus.routeNumber}` : "Автобус табылмады"}
                  </Text>
                  <Text style={styles.rowSubtitle}>Көлік нөмірі: {item.label}</Text>
                </View>
              </Pressable>
            ))}
            <Pressable style={styles.ghost} onPress={() => void searchBluetooth()}>
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
            <TextInput
              value={routeNumber}
              onChangeText={setRouteNumber}
              placeholder="Маршрут, мысалы №12"
              placeholderTextColor={colors.textSecondary}
              style={styles.field}
            />
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

      <TicketModal ticket={ticket} onClose={() => setTicket(null)} />
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
    void (async () => {
      const cities = await getCities();
      const city = cities.find((item) => item.name === props.cityName) ?? cities[0];
      setCityId(city?.id ?? "");
    })().catch((nextError) => setError(formatApiError(nextError, "Не удалось загрузить город")));
  }, [props.cityName]);

  useEffect(() => {
    if (permission && !permission.granted) {
      void requestPermission();
    }
  }, [permission, requestPermission]);

  async function pay(method: PayMethod) {
    if (!bus) {
      return;
    }
    if (method === "wallet" && props.walletBalance < bus.price) {
      setError("Недостаточно баланса в кошельке");
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
        <View style={styles.hint}>
          <Text style={styles.hintText}>{bus ? "Автобус табылды" : "Камераны QR-кодқа бағыттаңыз"}</Text>
        </View>
        <View style={styles.bottom}>
          {bus ? (
            <View style={styles.sheet}>
              <SummaryCard bus={bus} compact />
              <PaymentRow title="Әмиян" subtitle={`Баланс: ${formatBalance(props.walletBalance)} ₸`} icon="account-balance-wallet" iconColor={colors.primaryBlue} iconBg="#EEF3FF" onPress={() => void pay("wallet")} />
              <PaymentRow title="Транспорт картасы" subtitle={transportSubtitle} icon="directions-bus" iconColor="#1FA868" iconBg="#E8FFF2" onPress={() => void pay("transport-card")} disabled={!props.activeTransportCard} />
              <PaymentRow title="Kaspi.kz" subtitle="MVP төлем тәсілі" icon="payments" iconColor="#EA3F34" iconBg="#FFF0EE" onPress={() => void pay("kaspi")} />
              <PaymentRow title="Банк картасымен" subtitle="Қосылған картамен төлеу" icon="credit-card" iconColor="#FFB800" iconBg="#FFF6D9" onPress={() => void pay("bank-card")} />
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
      <TicketModal ticket={ticket} onClose={() => setTicket(null)} />
    </View>
  );
}

async function findBus(cityId: string, label: string) {
  const query = normalizeTransportValue(label);
  const buses = await getBuses(cityId, { number: query });
  return buses.find((item) => normalizeTransportValue(item.number) === query || normalizeTransportValue(item.validatorName || "") === query) ?? buses[0] ?? null;
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
function TicketModal({ ticket, onClose }: { ticket: TicketDto | null; onClose: () => void }) {
  return <Modal visible={Boolean(ticket)} transparent animationType="slide" onRequestClose={onClose}><View style={styles.modalBackdrop}>{ticket ? <View style={styles.modalCard}><Pressable style={styles.modalClose} onPress={onClose}><MaterialIcons name="close" size={20} color={colors.textSecondary} /></Pressable><Text style={styles.modalCaption}>Нөмір транспорта</Text><Text style={styles.modalNumber}>{ticket.busNumber}</Text><View style={styles.qrWrap}><QRCode value={ticket.qrValue} size={180} /></View><Text style={styles.modalTitle}>Менің билетім</Text><View style={styles.grid}><TicketStat label="Қала" value={ticket.cityName} /><TicketStat label="Төлем күні" value="Бүгін" /><TicketStat label="Маршрут" value={ticket.routeNumber} /><TicketStat label="Жол ақысы" value={`${ticket.amount} ₸`} /><TicketStat label="Тариф" value={ticket.tariffName} /><TicketStat label="Жарамды дейін" value={new Date(ticket.validUntil).toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" })} /></View></View> : null}</View></Modal>;
}
function TicketStat({ label, value }: { label: string; value: string }) {
  return <View style={styles.stat}><Text style={styles.statLabel}>{label}</Text><Text style={styles.statValue}>{value}</Text></View>;
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
  dot: { width: 28, height: 28, borderRadius: 14, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center" },
  rowCopy: { marginLeft: 12, flex: 1 },
  rowTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  rowSubtitle: { marginTop: 4, fontSize: 15, color: colors.textSecondary },
  ghost: { minHeight: 56, borderRadius: 16, backgroundColor: colors.surfaceMuted, alignItems: "center", justifyContent: "center", marginTop: 18 },
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
  modalBackdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.28)", alignItems: "center", justifyContent: "center", padding: 20 },
  modalCard: { width: "100%", maxWidth: 420, borderRadius: 28, backgroundColor: "#FFF", padding: 24, ...shadow },
  modalClose: { alignSelf: "flex-end" },
  modalCaption: { textAlign: "center", fontSize: 15, color: colors.textSecondary },
  modalNumber: { marginTop: 4, textAlign: "center", fontSize: 28, fontWeight: "700", color: colors.textPrimary },
  qrWrap: { alignItems: "center", marginVertical: 20 },
  modalTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary, marginBottom: 12 },
  grid: { flexDirection: "row", flexWrap: "wrap", gap: 12 },
  stat: { width: "47%" },
  statLabel: { fontSize: 13, color: colors.textSecondary },
  statValue: { marginTop: 4, fontSize: 16, fontWeight: "600", color: colors.textPrimary },
});
