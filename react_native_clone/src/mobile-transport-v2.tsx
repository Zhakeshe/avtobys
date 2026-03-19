import React, { useEffect, useState } from "react";
import { MaterialIcons } from "@expo/vector-icons";
import QRCode from "react-native-qrcode-svg";
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import {
  addBus,
  createTicket,
  getBuses,
  getCities,
  getTariffs,
  getTickets,
  type BusDto,
  type TariffDto,
  type TicketDto,
} from "./api";
import { colors, shadow } from "./theme";
import { formatBalance } from "./wallet-store";

type SearchStage = "input" | "details" | "add";
type PaymentMethod = "wallet" | "bank-card" | "kaspi";

export function TicketsScreen({
  phoneNumber,
  onBack,
}: {
  phoneNumber: string;
  onBack: () => void;
}) {
  const [tickets, setTickets] = useState<TicketDto[]>([]);
  const [selectedTicket, setSelectedTicket] = useState<TicketDto | null>(null);

  useEffect(() => {
    void getTickets(phoneNumber).then(setTickets).catch(() => setTickets([]));
  }, [phoneNumber]);

  return (
    <View style={styles.screen}>
      <Header title="Мои билеты" onBack={onBack} />
      <Text style={styles.sectionTitle}>Последний билет</Text>
      <ScrollView showsVerticalScrollIndicator={false}>
        {tickets.length === 0 ? (
          <EmptyState text="Билетов пока нет. Оплатите проезд по номеру автобуса, Bluetooth или QR." />
        ) : (
          tickets.map((ticket) => (
            <Pressable key={ticket.id} style={styles.ticketRow} onPress={() => setSelectedTicket(ticket)}>
              <View style={styles.ticketIcon}>
                <MaterialIcons name="directions-bus" size={22} color="#FFFFFF" />
              </View>
              <View style={styles.ticketCopy}>
                <Text style={styles.ticketRoute}>Маршрут {ticket.routeNumber}</Text>
                <Text style={styles.ticketMeta}>
                  {ticket.busNumber} • {ticket.cityName}
                </Text>
              </View>
              <Text style={styles.ticketPrice}>{ticket.amount} ₸</Text>
            </Pressable>
          ))
        )}
      </ScrollView>

      <TicketModal ticket={selectedTicket} onClose={() => setSelectedTicket(null)} />
    </View>
  );
}

export function BusSearchScreen({
  mode,
  phoneNumber,
  cityName,
  walletBalance,
  onBack,
  onPaid,
}: {
  mode: "plate";
  phoneNumber: string;
  cityName: string;
  walletBalance: number;
  onBack: () => void;
  onPaid: (amount: number) => void;
}) {
  const [cityId, setCityId] = useState("");
  const [query, setQuery] = useState("");
  const [stage, setStage] = useState<SearchStage>("input");
  const [searching, setSearching] = useState(false);
  const [selectedBus, setSelectedBus] = useState<BusDto | null>(null);
  const [tariffs, setTariffs] = useState<TariffDto[]>([]);
  const [routeNumber, setRouteNumber] = useState("");
  const [tariffId, setTariffId] = useState("");
  const [ticket, setTicket] = useState<TicketDto | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    async function init() {
      const cities = await getCities();
      const city = cities.find((item) => item.name === cityName) ?? cities[0];
      setCityId(city?.id ?? "");

      if (city?.id) {
        const tariffList = await getTariffs(city.id);
        setTariffs(tariffList);
        setTariffId(tariffList[0]?.id ?? "");
      }
    }

    void init().catch(() => setError("Не удалось загрузить города и тарифы"));
  }, [cityName]);

  const handleSearch = async () => {
    if (!cityId || !query.trim()) {
      return;
    }

    setSearching(true);
    setError("");

    try {
      const searchValue = normalizeTransportValue(query);
      const buses = await getBuses(cityId, { number: searchValue });
      const match =
        buses.find(
          (bus) =>
            normalizeTransportValue(bus.number) === searchValue ||
            normalizeTransportValue(bus.validatorName || "") === searchValue,
        ) ||
        buses[0] ||
        null;

      if (match) {
        setSelectedBus(match);
        setStage("details");
      } else {
        setSelectedBus(null);
        setStage("add");
      }
    } catch {
      setError("Не удалось найти автобус в базе");
    } finally {
      setSearching(false);
    }
  };

  const handleAddBus = async () => {
    if (!cityId || !query.trim() || !tariffId || !routeNumber.trim()) {
      return;
    }

    try {
      const bus = await addBus({
        cityId,
        tariffId,
        number: normalizeTransportValue(query),
        routeNumber: routeNumber.trim(),
      });
      setSelectedBus(bus);
      setStage("details");
    } catch {
      setError("Не удалось добавить новый автобус");
    }
  };

  const handlePay = async (paymentMethod: PaymentMethod) => {
    if (!selectedBus) {
      return;
    }

    if (paymentMethod === "wallet" && walletBalance < selectedBus.price) {
      setError("Недостаточно баланса в кошельке");
      return;
    }

    try {
      const created = await createTicket({
        phoneNumber,
        busId: selectedBus.id,
        paymentMethod,
        cityId,
        cityName,
      });
      if (paymentMethod === "wallet") {
        onPaid(selectedBus.price);
      }
      setTicket(created);
    } catch {
      setError("Не удалось провести оплату");
    }
  };

  return (
    <View style={styles.screen}>
      <Header title={mode === "plate" ? "Мемл. номер бойынша төлем" : ""} onBack={onBack} />

      {stage === "input" ? (
        <View style={styles.flex}>
          <View style={styles.inputCard}>
            <Text style={styles.inputHint}>Көліктің мемлекеттік нөмірін енгізіңіз</Text>
            <View style={styles.searchBar}>
              <TextInput
                value={query}
                onChangeText={(value) => {
                  setQuery(value.toUpperCase());
                  setError("");
                }}
                placeholder="852CS02"
                placeholderTextColor={colors.textSecondary}
                style={styles.searchFieldInput}
                autoCapitalize="characters"
              />
              <Pressable onPress={() => setQuery("")}>
                <MaterialIcons name="cancel" size={22} color="#B4B9C6" />
              </Pressable>
            </View>
          </View>
          {error ? <Text style={styles.errorText}>{error}</Text> : null}
          <View style={styles.bottomButtonWrap}>
            <PrimaryButton
              label={searching ? "Ізделуде..." : "Келесі"}
              disabled={!query.trim() || searching}
              onPress={() => void handleSearch()}
            />
          </View>
        </View>
      ) : null}

      {stage === "add" ? (
        <ScrollView showsVerticalScrollIndicator={false}>
          <EmptyState text="Автобус базада табылмады. Жаңа автобус қосуға болады." />
          <View style={styles.addBox}>
            <Text style={styles.addLabel}>Көлік нөмірі</Text>
            <Text style={styles.addValue}>{normalizeTransportValue(query)}</Text>
            <TextInput
              value={routeNumber}
              onChangeText={setRouteNumber}
              placeholder="Маршрут, мысалы №12"
              placeholderTextColor={colors.textSecondary}
              style={styles.field}
            />
            <Text style={styles.addLabel}>Тариф</Text>
            {tariffs.map((tariff) => (
              <Pressable
                key={tariff.id}
                style={[styles.tariffRow, tariffId === tariff.id && styles.tariffRowActive]}
                onPress={() => setTariffId(tariff.id)}
              >
                <Text style={styles.tariffName}>{tariff.name}</Text>
                <Text style={styles.tariffPrice}>{tariff.price} ₸</Text>
              </Pressable>
            ))}
            <PrimaryButton
              label="Жаңа автобус қосу"
              disabled={!routeNumber.trim() || !tariffId}
              onPress={() => void handleAddBus()}
            />
            <Pressable style={styles.secondaryAction} onPress={() => setStage("input")}>
              <Text style={styles.secondaryActionText}>Қайта іздеу</Text>
            </Pressable>
          </View>
          {error ? <Text style={styles.errorText}>{error}</Text> : null}
        </ScrollView>
      ) : null}

      {stage === "details" && selectedBus ? (
        <ScrollView showsVerticalScrollIndicator={false}>
          <BusSummaryCard bus={selectedBus} />
          <View style={styles.paymentGroup}>
            <Text style={styles.paymentGroupTitle}>Төлем тәсілдері</Text>
            <PaymentOptionRow
              icon="account-balance-wallet"
              iconColor={colors.primaryBlue}
              iconBackground="#EEF3FF"
              title="Әмиянмен төлеу"
              subtitle={`Баланс: ${formatBalance(walletBalance)} ₸`}
              onPress={() => void handlePay("wallet")}
            />
            <PaymentOptionRow
              icon="payments"
              iconColor="#EA3F34"
              iconBackground="#FFF0EE"
              title="Kaspi.kz"
              subtitle="MVP төлем тәсілі"
              onPress={() => void handlePay("kaspi")}
            />
            <PaymentOptionRow
              icon="credit-card"
              iconColor="#FFB800"
              iconBackground="#FFF5D8"
              title="Банк картасымен"
              subtitle="Қосылған картамен төлеу"
              onPress={() => void handlePay("bank-card")}
            />
          </View>
          <Pressable
            style={styles.secondaryAction}
            onPress={() => {
              setStage("input");
              setSelectedBus(null);
            }}
          >
            <Text style={styles.secondaryActionText}>Басқа нөмір енгізу</Text>
          </Pressable>
          {error ? <Text style={styles.errorText}>{error}</Text> : null}
        </ScrollView>
      ) : null}

      <TicketModal ticket={ticket} onClose={() => setTicket(null)} />
    </View>
  );
}

function EmptyState({ text }: { text: string }) {
  return (
    <View style={styles.emptyCard}>
      <Text style={styles.emptyText}>{text}</Text>
    </View>
  );
}

function BusSummaryCard({ bus }: { bus: BusDto }) {
  return (
    <View style={styles.summaryCard}>
      <View style={styles.summaryIcon}>
        <MaterialIcons name="directions-bus" size={22} color={colors.banner} />
      </View>
      <InfoLine label="Көлік нөмірі" value={bus.number} />
      <InfoLine label="Маршрут" value={bus.routeNumber} />
      <InfoLine label="Тариф" value={bus.tariffName} />
      <InfoLine label="Қала" value={bus.cityName} />
      <InfoLine label="Жол жүру сомасы" value={`${bus.price} ₸`} emphasized />
    </View>
  );
}

function PaymentOptionRow({
  icon,
  iconColor,
  iconBackground,
  title,
  subtitle,
  onPress,
}: {
  icon: string;
  iconColor: string;
  iconBackground: string;
  title: string;
  subtitle: string;
  onPress: () => void;
}) {
  return (
    <Pressable style={styles.paymentOption} onPress={onPress}>
      <View style={[styles.paymentOptionIcon, { backgroundColor: iconBackground }]}>
        <MaterialIcons name={icon as never} size={24} color={iconColor} />
      </View>
      <View style={styles.paymentOptionCopy}>
        <Text style={styles.paymentOptionTitle}>{title}</Text>
        <Text style={styles.paymentOptionSubtitle}>{subtitle}</Text>
      </View>
      <MaterialIcons name="chevron-right" size={28} color={colors.textSecondary} />
    </Pressable>
  );
}

function InfoLine({
  label,
  value,
  emphasized = false,
}: {
  label: string;
  value: string;
  emphasized?: boolean;
}) {
  return (
    <View style={styles.infoLine}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={[styles.infoValue, emphasized && styles.infoValueEmphasized]}>{value}</Text>
    </View>
  );
}

function TicketModal({
  ticket,
  onClose,
}: {
  ticket: TicketDto | null;
  onClose: () => void;
}) {
  return (
    <Modal visible={Boolean(ticket)} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        {ticket ? (
          <View style={styles.ticketModal}>
            <Pressable style={styles.modalClose} onPress={onClose}>
              <MaterialIcons name="close" size={20} color={colors.textSecondary} />
            </Pressable>
            <Text style={styles.transportTitle}>Нөмір транспорта</Text>
            <Text style={styles.transportNumber}>{ticket.busNumber}</Text>
            <View style={styles.qrWrap}>
              <QRCode value={ticket.qrValue} size={180} />
            </View>
            <Text style={styles.modalMainTitle}>Менің билетім</Text>
            <View style={styles.ticketGrid}>
              <TicketStat label="Қала" value={ticket.cityName} />
              <TicketStat label="Төлем күні" value="Бүгін" />
              <TicketStat label="Маршрут" value={ticket.routeNumber} />
              <TicketStat label="Жол ақысы" value={`${ticket.amount} ₸`} />
              <TicketStat label="Тариф" value={ticket.tariffName} />
              <TicketStat
                label="Жарамды дейін"
                value={new Date(ticket.validUntil).toLocaleTimeString("ru-RU", {
                  hour: "2-digit",
                  minute: "2-digit",
                })}
              />
            </View>
          </View>
        ) : null}
      </View>
    </Modal>
  );
}

function TicketStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={styles.statValue}>{value}</Text>
    </View>
  );
}

function Header({ title, onBack }: { title: string; onBack: () => void }) {
  return (
    <View style={styles.header}>
      <Pressable style={styles.headerBack} onPress={onBack}>
        <MaterialIcons name="arrow-back-ios-new" size={28} color={colors.textPrimary} />
      </Pressable>
      <Text style={styles.headerTitle}>{title}</Text>
      <View style={styles.headerBack} />
    </View>
  );
}

function PrimaryButton({
  label,
  disabled,
  onPress,
}: {
  label: string;
  disabled: boolean;
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

function normalizeTransportValue(value: string) {
  return value.replace(/[^0-9A-Za-z]/g, "").toUpperCase();
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: { flex: 1, backgroundColor: "#FFFFFF", paddingHorizontal: 24, paddingBottom: 24 },
  header: { height: 56, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  headerBack: { width: 40, alignItems: "flex-start", justifyContent: "center" },
  headerTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  sectionTitle: { marginTop: 18, marginBottom: 12, fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  inputCard: { marginTop: 20, padding: 16, borderRadius: 20, backgroundColor: colors.surfaceMuted },
  inputHint: { fontSize: 13, color: colors.textSecondary },
  searchBar: { marginTop: 10, minHeight: 54, borderRadius: 16, backgroundColor: "#FFFFFF", paddingHorizontal: 16, flexDirection: "row", alignItems: "center" },
  searchFieldInput: { flex: 1, fontSize: 20, color: colors.textPrimary, letterSpacing: 0.5 },
  bottomButtonWrap: { marginTop: "auto", paddingTop: 24 },
  emptyCard: { marginTop: 18, padding: 20, borderRadius: 22, backgroundColor: colors.surfaceMuted },
  emptyText: { fontSize: 16, lineHeight: 22, color: colors.textSecondary },
  addBox: { marginTop: 18, padding: 18, borderRadius: 22, backgroundColor: colors.surfaceMuted },
  addLabel: { marginTop: 10, fontSize: 13, color: colors.textSecondary },
  addValue: { marginTop: 4, fontSize: 22, fontWeight: "700", color: colors.textPrimary },
  field: { height: 58, borderRadius: 16, backgroundColor: "#FFFFFF", paddingHorizontal: 16, fontSize: 16, color: colors.textPrimary, marginTop: 12 },
  tariffRow: { marginTop: 10, padding: 14, borderRadius: 16, backgroundColor: "#FFFFFF", flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  tariffRowActive: { borderWidth: 1.5, borderColor: colors.primaryBlue },
  tariffName: { fontSize: 15, color: colors.textPrimary },
  tariffPrice: { fontSize: 15, fontWeight: "700", color: colors.textPrimary },
  summaryCard: { marginTop: 18, backgroundColor: colors.banner, borderRadius: 22, padding: 18 },
  summaryIcon: { position: "absolute", top: 16, right: 16, width: 46, height: 46, borderRadius: 23, backgroundColor: "#FFFFFF", alignItems: "center", justifyContent: "center" },
  infoLine: { marginTop: 10 },
  infoLabel: { fontSize: 13, color: "#D7DCEC" },
  infoValue: { marginTop: 4, fontSize: 20, color: "#FFFFFF" },
  infoValueEmphasized: { fontSize: 28, fontWeight: "700" },
  paymentGroup: { marginTop: 24 },
  paymentGroupTitle: { marginBottom: 12, fontSize: 16, fontWeight: "600", color: colors.textPrimary },
  paymentOption: { flexDirection: "row", alignItems: "center", borderRadius: 18, backgroundColor: "#FFFFFF", padding: 14, marginBottom: 12, ...shadow },
  paymentOptionIcon: { width: 46, height: 46, borderRadius: 23, alignItems: "center", justifyContent: "center" },
  paymentOptionCopy: { flex: 1, marginLeft: 12 },
  paymentOptionTitle: { fontSize: 16, fontWeight: "600", color: colors.textPrimary },
  paymentOptionSubtitle: { marginTop: 4, fontSize: 13, color: colors.textSecondary },
  secondaryAction: { marginTop: 8, minHeight: 56, borderRadius: 16, backgroundColor: colors.surfaceMuted, alignItems: "center", justifyContent: "center" },
  secondaryActionText: { fontSize: 16, color: colors.textSecondary },
  ticketRow: { backgroundColor: "#FFFFFF", borderRadius: 18, padding: 16, flexDirection: "row", alignItems: "center", marginBottom: 12, ...shadow },
  ticketIcon: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.accentYellow, alignItems: "center", justifyContent: "center" },
  ticketCopy: { flex: 1, marginLeft: 12 },
  ticketRoute: { fontSize: 16, fontWeight: "700", color: colors.textPrimary },
  ticketMeta: { marginTop: 4, fontSize: 13, color: colors.textSecondary },
  ticketPrice: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  modalBackdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.28)", alignItems: "center", justifyContent: "center", padding: 20 },
  ticketModal: { width: "100%", maxWidth: 420, borderRadius: 28, backgroundColor: "#FFFFFF", padding: 24, ...shadow },
  modalClose: { alignSelf: "flex-end" },
  transportTitle: { textAlign: "center", fontSize: 15, color: colors.textSecondary },
  transportNumber: { textAlign: "center", fontSize: 28, fontWeight: "700", color: colors.textPrimary, marginTop: 4 },
  qrWrap: { alignItems: "center", marginVertical: 20 },
  modalMainTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary, marginBottom: 12 },
  ticketGrid: { flexDirection: "row", flexWrap: "wrap", gap: 12 },
  stat: { width: "47%" },
  statLabel: { fontSize: 13, color: colors.textSecondary },
  statValue: { marginTop: 4, fontSize: 16, fontWeight: "600", color: colors.textPrimary },
  primaryButton: { height: 64, borderRadius: 18, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center", marginTop: 20 },
  primaryButtonDisabled: { backgroundColor: "#C8C8C8" },
  primaryButtonLabel: { fontSize: 18, color: "#FFFFFF" },
  errorText: { marginTop: 14, color: "#C62828", fontSize: 14 },
});
