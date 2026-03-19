import React, { useEffect, useMemo, useRef, useState } from "react";
import { MaterialIcons } from "@expo/vector-icons";
import { CameraView, useCameraPermissions } from "expo-camera";
import { BleManager, type Device, State } from "react-native-ble-plx";
import QRCode from "react-native-qrcode-svg";
import {
  Modal,
  NativeModules,
  PermissionsAndroid,
  Platform,
  Pressable,
  SafeAreaView,
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
  type BusDto,
  type TariffDto,
  type TicketDto,
} from "./api";
import { colors, shadow } from "./theme";
import { formatBalance } from "./wallet-store";

type HardwareProps = {
  phoneNumber: string;
  cityName: string;
  walletBalance: number;
  onBack: () => void;
  onPaid: (amount: number) => void;
};

type ResolvedDevice = {
  id: string;
  label: string;
  raw: Device;
  bus: BusDto | null;
};

const hasNativeBle = Boolean((NativeModules as Record<string, unknown>).BleClientManager);

export function BluetoothScannerScreen({
  phoneNumber,
  cityName,
  walletBalance,
  onBack,
  onPaid,
}: HardwareProps) {
  const managerRef = useRef<BleManager | null>(null);
  const [cityId, setCityId] = useState("");
  const [tariffs, setTariffs] = useState<TariffDto[]>([]);
  const [selectedTariffId, setSelectedTariffId] = useState("");
  const [routeNumber, setRouteNumber] = useState("");
  const [validators, setValidators] = useState<ResolvedDevice[]>([]);
  const [selectedValidator, setSelectedValidator] = useState<ResolvedDevice | null>(null);
  const [ticket, setTicket] = useState<TicketDto | null>(null);
  const [loading, setLoading] = useState(true);
  const [scanning, setScanning] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    async function init() {
      try {
        const cities = await getCities();
        const city = cities.find((item) => item.name === cityName) ?? cities[0];
        const tariffList = city?.id ? await getTariffs(city.id) : [];
        if (cancelled) {
          return;
        }
        setCityId(city?.id ?? "");
        setTariffs(tariffList);
        setSelectedTariffId(tariffList[0]?.id ?? "");
      } catch {
        if (!cancelled) {
          setError("Не удалось загрузить тарифы для Bluetooth");
        }
      }
    }

    void init();

    return () => {
      cancelled = true;
    };
  }, [cityName]);

  useEffect(() => {
    if (!cityId || !hasNativeBle) {
      setLoading(false);
      if (!hasNativeBle) {
        setError("BLE работает в dev build. В Expo Go нативный BLE недоступен.");
      }
      return;
    }

    let mounted = true;

    async function start() {
      const granted = await requestBlePermissions();
      if (!granted || !mounted) {
        setLoading(false);
        if (!granted) {
          setError("Нет разрешения на Bluetooth");
        }
        return;
      }

      const manager = new BleManager();
      managerRef.current = manager;
      setLoading(false);
      setScanning(true);

      const currentState = await manager.state();
      if (currentState !== State.PoweredOn) {
        const subscription = manager.onStateChange((state) => {
          if (state === State.PoweredOn) {
            subscription.remove();
            startBleScan(manager, cityId, setValidators, setError);
          }
        }, true);
        return;
      }

      startBleScan(manager, cityId, setValidators, setError);
    }

    void start();

    return () => {
      mounted = false;
      managerRef.current?.stopDeviceScan();
      managerRef.current?.destroy();
      managerRef.current = null;
    };
  }, [cityId]);

  const selectedBus = selectedValidator?.bus ?? null;
  const selectedLabel = selectedValidator?.label ?? "";

  const handlePickValidator = async (validator: ResolvedDevice) => {
    setSelectedValidator(validator);
    if (validator.bus) {
      return;
    }

    try {
      const matches = await getBuses(cityId, { number: normalizeTransportValue(validator.label) });
      const exact =
        matches.find((item) => normalizeTransportValue(item.number) === normalizeTransportValue(validator.label)) ??
        matches[0] ??
        null;
      setSelectedValidator({ ...validator, bus: exact });
    } catch {
      setError("Не удалось сопоставить валидатор с автобусом");
    }
  };

  const handleAddBus = async () => {
    if (!cityId || !selectedLabel || !selectedTariffId || !routeNumber.trim()) {
      return;
    }

    try {
      const created = await addBus({
        cityId,
        tariffId: selectedTariffId,
        number: normalizeTransportValue(selectedLabel),
        routeNumber: routeNumber.trim(),
      });
      const nextValidator: ResolvedDevice = {
        ...(selectedValidator as ResolvedDevice),
        bus: created,
      };
      setSelectedValidator(nextValidator);
      setValidators((current) =>
        current.map((item) => (item.id === nextValidator.id ? nextValidator : item)),
      );
    } catch {
      setError("Не удалось добавить автобус из Bluetooth");
    }
  };

  const handlePay = async () => {
    if (!selectedBus) {
      return;
    }
    if (walletBalance < selectedBus.price) {
      setError("Недостаточно баланса в кошельке");
      return;
    }

    try {
      const created = await createTicket({
        phoneNumber,
        busId: selectedBus.id,
        paymentMethod: "wallet",
        cityId,
        cityName,
      });
      onPaid(selectedBus.price);
      setTicket(created);
    } catch {
      setError("Не удалось оплатить поездку через Bluetooth");
    }
  };

  const handleRescan = async () => {
    setValidators([]);
    setSelectedValidator(null);
    setError("");
    const manager = managerRef.current;
    if (!manager || !cityId) {
      return;
    }
    manager.stopDeviceScan();
    setScanning(true);
    startBleScan(manager, cityId, setValidators, setError);
  };

  return (
    <View style={styles.screen}>
      <Header title="Bluetooth оплата" onBack={onBack} />
      <WalletBanner phoneNumber={phoneNumber} balance={walletBalance} />
      <View style={styles.scanStatusRow}>
        <Text style={styles.scanStatusTitle}>
          {scanning ? "Идет поиск валидаторов" : "Сканирование остановлено"}
        </Text>
        <Pressable style={styles.ghostButton} onPress={() => void handleRescan()}>
          <MaterialIcons name="refresh" size={18} color={colors.primaryBlue} />
          <Text style={styles.ghostButtonText}>Повторить</Text>
        </Pressable>
      </View>

      <ScrollView showsVerticalScrollIndicator={false}>
        {loading ? (
          <View style={styles.emptyCard}>
            <Text style={styles.emptyText}>Запрашиваем Bluetooth и список валидаторов...</Text>
          </View>
        ) : validators.length === 0 ? (
          <View style={styles.emptyCard}>
            <Text style={styles.emptyText}>
              Пока нет найденных устройств. Включите Bluetooth и подойдите к валидатору автобуса.
            </Text>
          </View>
        ) : (
          validators.map((validator) => (
            <Pressable
              key={validator.id}
              style={[
                styles.validatorCard,
                selectedValidator?.id === validator.id && styles.validatorCardActive,
              ]}
              onPress={() => void handlePickValidator(validator)}
            >
              <View style={styles.validatorIcon}>
                <MaterialIcons name="bluetooth-searching" size={26} color="#FFFFFF" />
              </View>
              <View style={styles.validatorCopy}>
                <Text style={styles.validatorTitle}>{validator.label}</Text>
                <Text style={styles.validatorSubtitle}>
                  {validator.bus
                    ? `Маршрут ${validator.bus.routeNumber} • ${validator.bus.price} ₸`
                    : "Автобус не найден в базе"}
                </Text>
              </View>
            </Pressable>
          ))
        )}

        {selectedValidator && !selectedBus ? (
          <View style={styles.addBox}>
            <Text style={styles.addTitle}>Для этого валидатора автобуса пока нет</Text>
            <Text style={styles.addHint}>Номер будет взят из Bluetooth: {selectedLabel}</Text>
            <TextInput
              value={routeNumber}
              onChangeText={setRouteNumber}
              placeholder="Маршрут, например № 12"
              placeholderTextColor={colors.textSecondary}
              style={styles.field}
            />
            <Text style={styles.pickLabel}>Тариф</Text>
            {tariffs.map((tariff) => (
              <Pressable
                key={tariff.id}
                style={[
                  styles.tariffRow,
                  selectedTariffId === tariff.id && styles.tariffRowActive,
                ]}
                onPress={() => setSelectedTariffId(tariff.id)}
              >
                <Text style={styles.tariffName}>{tariff.name}</Text>
                <Text style={styles.tariffPrice}>{tariff.price} ₸</Text>
              </Pressable>
            ))}
            <PrimaryButton
              label="Добавить автобус"
              disabled={!routeNumber.trim() || !selectedTariffId}
              onPress={() => void handleAddBus()}
            />
          </View>
        ) : null}

        {selectedBus ? (
          <PaymentSummaryCard
            bus={selectedBus}
            walletBalance={walletBalance}
            onPay={() => void handlePay()}
          />
        ) : null}

        {error ? <Text style={styles.errorText}>{error}</Text> : null}
      </ScrollView>

      <TicketModal ticket={ticket} onClose={() => setTicket(null)} />
    </View>
  );
}

export function QrScannerPaymentScreen({
  phoneNumber,
  cityName,
  walletBalance,
  onBack,
  onPaid,
}: HardwareProps) {
  const [permission, requestPermission] = useCameraPermissions();
  const [cityId, setCityId] = useState("");
  const [scanned, setScanned] = useState(false);
  const [flashEnabled, setFlashEnabled] = useState(false);
  const [resolvedBus, setResolvedBus] = useState<BusDto | null>(null);
  const [ticket, setTicket] = useState<TicketDto | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let mounted = true;

    async function init() {
      const cities = await getCities();
      const city = cities.find((item) => item.name === cityName) ?? cities[0];
      if (mounted) {
        setCityId(city?.id ?? "");
      }
    }

    void init().catch(() => setError("Не удалось загрузить город для QR"));

    return () => {
      mounted = false;
    };
  }, [cityName]);

  useEffect(() => {
    if (!permission) {
      return;
    }
    if (!permission.granted) {
      void requestPermission();
    }
  }, [permission, requestPermission]);

  const handleBarcodeScanned = async ({ data }: { data: string }) => {
    if (scanned || !cityId) {
      return;
    }
    setScanned(true);
    setError("");

    try {
      const byQr = await getBuses(cityId, { qrToken: data.trim() });
      const match = byQr[0] ?? (await getBuses(cityId, { number: data.trim() }))[0] ?? null;
      if (!match) {
        setResolvedBus(null);
        setError("Автобус по QR не найден");
        return;
      }
      setResolvedBus(match);
    } catch {
      setResolvedBus(null);
      setError("Не удалось обработать QR-код");
    }
  };

  const handlePay = async () => {
    if (!resolvedBus) {
      return;
    }
    if (walletBalance < resolvedBus.price) {
      setError("Недостаточно баланса в кошельке");
      return;
    }

    try {
      const created = await createTicket({
        phoneNumber,
        busId: resolvedBus.id,
        paymentMethod: "wallet",
        cityId,
        cityName,
      });
      onPaid(resolvedBus.price);
      setTicket(created);
    } catch {
      setError("Не удалось оплатить поездку по QR");
    }
  };

  const resetScan = () => {
    setScanned(false);
    setResolvedBus(null);
    setError("");
  };

  if (!permission) {
    return <View style={styles.screen} />;
  }

  if (!permission.granted) {
    return (
      <View style={styles.screen}>
        <Header title="QR оплата" onBack={onBack} />
        <View style={styles.emptyCard}>
          <Text style={styles.emptyText}>Нужно разрешение на камеру для сканирования QR.</Text>
        </View>
        <PrimaryButton label="Разрешить камеру" disabled={false} onPress={() => void requestPermission()} />
      </View>
    );
  }

  return (
    <View style={styles.scannerRoot}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        enableTorch={flashEnabled}
        onBarcodeScanned={handleBarcodeScanned}
      />
      <View style={styles.scannerShade} />
      <SafeAreaView style={styles.flex}>
        <View style={styles.scannerTopButtons}>
          <ScannerRoundButton
            icon={flashEnabled ? "flash-off" : "flash-on"}
            onPress={() => setFlashEnabled((current) => !current)}
          />
          <ScannerRoundButton icon="close" onPress={onBack} />
        </View>
        <View style={styles.cameraFrame} />
        <View style={styles.scannerHint}>
          <Text style={styles.scannerHintText}>
            {resolvedBus ? "QR считан, проверьте автобус ниже" : "Наведите камеру на QR-код"}
          </Text>
        </View>
        <View style={styles.scannerBottom}>
          {resolvedBus ? (
            <View style={styles.scannerPayCard}>
              <Text style={styles.payLabel}>Номер транспорта</Text>
              <Text style={styles.payValue}>{resolvedBus.number}</Text>
              <Text style={styles.payLabel}>Маршрут</Text>
              <Text style={styles.payValue}>{resolvedBus.routeNumber}</Text>
              <Text style={styles.payLabel}>Вид тарифа</Text>
              <Text style={styles.payValue}>{resolvedBus.tariffName}</Text>
              <Text style={styles.payLabel}>Сумма</Text>
              <Text style={styles.payPrice}>{resolvedBus.price} ₸</Text>
              <PrimaryButton label="Оплатить с помощью кошелька" disabled={false} onPress={() => void handlePay()} />
              <Pressable style={styles.altButton} onPress={resetScan}>
                <Text style={styles.altButtonText}>Сканировать заново</Text>
              </Pressable>
            </View>
          ) : (
            <WalletBanner phoneNumber={phoneNumber} balance={walletBalance} />
          )}
          {error ? <Text style={styles.errorText}>{error}</Text> : null}
        </View>
      </SafeAreaView>
      <TicketModal ticket={ticket} onClose={() => setTicket(null)} />
    </View>
  );
}

function PaymentSummaryCard({
  bus,
  walletBalance,
  onPay,
}: {
  bus: BusDto;
  walletBalance: number;
  onPay: () => void;
}) {
  return (
    <View style={styles.payBox}>
      <Text style={styles.payLabel}>Номер транспорта</Text>
      <Text style={styles.payValue}>{bus.number}</Text>
      <Text style={styles.payLabel}>Маршрут</Text>
      <Text style={styles.payValue}>{bus.routeNumber}</Text>
      <Text style={styles.payLabel}>Вид тарифа</Text>
      <Text style={styles.payValue}>{bus.tariffName}</Text>
      <Text style={styles.payLabel}>Сумма</Text>
      <Text style={styles.payPrice}>{bus.price} ₸</Text>
      <PrimaryButton label="Оплатить с помощью кошелька" disabled={false} onPress={onPay} />
      <View style={styles.altButton}>
        <Text style={styles.altButtonText}>Баланс: {formatBalance(walletBalance)} ₸</Text>
      </View>
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
            <Text style={styles.transportTitle}>Номер транспорта</Text>
            <Text style={styles.transportNumber}>{ticket.busNumber}</Text>
            <View style={styles.qrWrap}>
              <QRCode value={ticket.qrValue} size={180} />
            </View>
            <Text style={styles.modalMainTitle}>Мой билет</Text>
            <View style={styles.ticketGrid}>
              <TicketStat label="Город" value={ticket.cityName} />
              <TicketStat label="Дата оплаты" value="Сегодня" />
              <TicketStat label="Маршрут" value={ticket.routeNumber} />
              <TicketStat label="Сумма проезда" value={`${ticket.amount} ₸`} />
              <TicketStat label="Вид тарифа" value={ticket.tariffName} />
              <TicketStat
                label="Действует до"
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

function WalletBanner({
  phoneNumber,
  balance,
}: {
  phoneNumber: string;
  balance: number;
}) {
  return (
    <View style={styles.walletCard}>
      <View style={styles.walletRow}>
        <Text style={styles.walletTitle}>Кошелек</Text>
        <Text style={styles.walletAmount}>{formatBalance(balance)} ₸</Text>
      </View>
      <Text style={styles.walletSubtitle}>{phoneNumber}  Стандарт</Text>
    </View>
  );
}

function ScannerRoundButton({
  icon,
  onPress,
}: {
  icon: string;
  onPress?: () => void;
}) {
  return (
    <Pressable style={styles.scannerIconButton} onPress={onPress}>
      <MaterialIcons name={icon as never} size={24} color="#FFFFFF" />
    </Pressable>
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
  return value.replace(/\s+/g, "").toUpperCase();
}

async function requestBlePermissions() {
  if (Platform.OS !== "android") {
    return true;
  }

  if (Platform.Version >= 31) {
    const scanPermission = (PermissionsAndroid.PERMISSIONS as Record<string, unknown>)
      .BLUETOOTH_SCAN as string;
    const connectPermission = (PermissionsAndroid.PERMISSIONS as Record<string, unknown>)
      .BLUETOOTH_CONNECT as string;
    const permissions = [
      scanPermission,
      connectPermission,
      PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
    ].filter(Boolean) as string[];
    const result = await PermissionsAndroid.requestMultiple(permissions as never);

    return permissions.every(
      (permission) =>
        result[permission as keyof typeof result] === PermissionsAndroid.RESULTS.GRANTED,
    );
  }

  const location = await PermissionsAndroid.request(
    PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
  );
  return location === PermissionsAndroid.RESULTS.GRANTED;
}

function startBleScan(
  manager: BleManager,
  cityId: string,
  setValidators: React.Dispatch<React.SetStateAction<ResolvedDevice[]>>,
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
      const next: ResolvedDevice = {
        id: device.id,
        label,
        raw: device,
        bus: null,
      };
      return [next, ...current].slice(0, 20);
    });

    void getBuses(cityId, { number: normalizeTransportValue(label) })
      .then((matches) => {
        const exact =
          matches.find((item) => normalizeTransportValue(item.number) === normalizeTransportValue(label)) ??
          matches[0] ??
          null;
        setValidators((current) =>
          current.map((item) =>
            item.id === device.id
              ? {
                  ...item,
                  bus: exact,
                }
              : item,
          ),
        );
      })
      .catch(() => {
        // keep unresolved validator in list
      });
  });
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: { flex: 1, backgroundColor: "#FFFFFF", paddingHorizontal: 24, paddingBottom: 24 },
  header: { height: 56, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  headerBack: { width: 40, alignItems: "flex-start", justifyContent: "center" },
  headerTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  walletCard: { marginTop: 18, backgroundColor: colors.banner, borderRadius: 22, padding: 22 },
  walletRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  walletTitle: { fontSize: 18, fontWeight: "700", color: "#FFFFFF" },
  walletAmount: { fontSize: 20, fontWeight: "700", color: "#FFFFFF" },
  walletSubtitle: { marginTop: 10, fontSize: 15, color: "#D7DCEC" },
  scanStatusRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: 18, marginBottom: 12 },
  scanStatusTitle: { fontSize: 16, fontWeight: "600", color: colors.textPrimary },
  ghostButton: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 12, paddingVertical: 8, borderRadius: 999, backgroundColor: "#EEF3FF" },
  ghostButtonText: { fontSize: 14, color: colors.primaryBlue, fontWeight: "600" },
  emptyCard: { marginTop: 12, padding: 20, borderRadius: 22, backgroundColor: colors.surfaceMuted },
  emptyText: { fontSize: 16, lineHeight: 22, color: colors.textSecondary },
  validatorCard: { marginTop: 12, padding: 16, borderRadius: 20, backgroundColor: "#FFFFFF", flexDirection: "row", alignItems: "center", ...shadow },
  validatorCardActive: { borderWidth: 1, borderColor: colors.primaryBlue },
  validatorIcon: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center" },
  validatorCopy: { flex: 1, marginLeft: 12 },
  validatorTitle: { fontSize: 16, fontWeight: "700", color: colors.textPrimary },
  validatorSubtitle: { marginTop: 4, fontSize: 13, color: colors.textSecondary },
  addBox: { marginTop: 18, padding: 18, borderRadius: 22, backgroundColor: colors.surfaceMuted },
  addTitle: { fontSize: 16, fontWeight: "600", color: colors.textPrimary },
  addHint: { marginTop: 8, fontSize: 14, color: colors.textSecondary },
  field: { height: 60, borderRadius: 18, backgroundColor: "#FFFFFF", paddingHorizontal: 18, fontSize: 17, color: colors.textPrimary, marginTop: 14 },
  pickLabel: { marginTop: 14, fontSize: 14, color: colors.textSecondary },
  tariffRow: { marginTop: 10, padding: 14, borderRadius: 16, backgroundColor: "#FFFFFF", flexDirection: "row", justifyContent: "space-between" },
  tariffRowActive: { borderWidth: 1, borderColor: colors.primaryBlue },
  tariffName: { fontSize: 15, color: colors.textPrimary },
  tariffPrice: { fontSize: 15, fontWeight: "700", color: colors.textPrimary },
  payBox: { marginTop: 24 },
  payLabel: { marginTop: 12, fontSize: 14, color: colors.textSecondary },
  payValue: { marginTop: 4, fontSize: 19, color: colors.textPrimary },
  payPrice: { marginTop: 4, fontSize: 28, fontWeight: "700", color: colors.textPrimary },
  primaryButton: { height: 64, borderRadius: 18, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center", marginTop: 24 },
  primaryButtonDisabled: { backgroundColor: "#C8C8C8" },
  primaryButtonLabel: { fontSize: 18, color: "#FFFFFF" },
  altButton: { height: 64, borderRadius: 18, backgroundColor: "#F1F1F1", alignItems: "center", justifyContent: "center", marginTop: 14 },
  altButtonText: { fontSize: 18, color: colors.textPrimary },
  errorText: { marginTop: 16, color: "#C62828", fontSize: 14 },
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
  scannerRoot: { flex: 1, backgroundColor: "#101318" },
  scannerShade: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(6,8,12,0.28)" },
  scannerTopButtons: { flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 22, paddingTop: 10 },
  scannerIconButton: { width: 42, height: 42, borderRadius: 21, backgroundColor: "rgba(255,255,255,0.28)", alignItems: "center", justifyContent: "center" },
  cameraFrame: { alignSelf: "center", marginTop: 160, width: 280, height: 280, borderRadius: 24, borderWidth: 4, borderColor: "rgba(54,79,214,0.88)", backgroundColor: "rgba(255,255,255,0.08)" },
  scannerHint: { alignSelf: "center", marginTop: 20, borderRadius: 18, backgroundColor: "rgba(91,99,127,0.82)", paddingHorizontal: 20, paddingVertical: 14 },
  scannerHintText: { fontSize: 15, color: "#D7DCEC" },
  scannerBottom: { marginTop: "auto", paddingHorizontal: 24, paddingBottom: 34 },
  scannerPayCard: { backgroundColor: "#FFFFFF", borderRadius: 24, padding: 20, ...shadow },
});
