import React from "react";
import { MaterialIcons } from "@expo/vector-icons";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { cityOptions, paymentCategories, transferOptions, type MenuItem } from "./mobile-data";
import { colors, shadow } from "./theme";
import {
  formatBalance,
  getActiveCard,
  maskCardNumber,
  normalizeCardNumber,
  type WalletState,
} from "./wallet-store";

export function LoginScreen({
  onRequestCode,
  onVerifyCode,
}: {
  onRequestCode: (value: string) => Promise<{
    phoneNumber: string;
    debugCode?: string;
    deliveryStatus?: string;
  }>;
  onVerifyCode: (value: string, code: string) => Promise<void>;
}) {
  const [digits, setDigits] = React.useState("");
  const [code, setCode] = React.useState("");
  const [step, setStep] = React.useState<"phone" | "code">("phone");
  const [busy, setBusy] = React.useState(false);
  const [requestPhone, setRequestPhone] = React.useState("");
  const [statusMessage, setStatusMessage] = React.useState("");
  const [errorMessage, setErrorMessage] = React.useState("");

  const formattedPhone = `+7 ${formatPhoneDigits(digits)}`;
  const canSubmit = step === "phone" ? digits.length >= 10 : code.trim().length >= 4;

  const handlePrimary = async () => {
    setBusy(true);
    setErrorMessage("");

    try {
      if (step === "phone") {
        const result = await onRequestCode(formattedPhone);
        setRequestPhone(result.phoneNumber);
        setStatusMessage(
          result.debugCode
            ? `Код отправлен в Telegram. Debug code: ${result.debugCode}`
            : `Код отправлен в Telegram (${result.deliveryStatus || "pending"})`,
        );
        setStep("code");
        setCode("");
      } else {
        await onVerifyCode(requestPhone || formattedPhone, code.trim());
      }
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Не удалось выполнить вход");
    } finally {
      setBusy(false);
    }
  };

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
              onChangeText={(value) => {
                setDigits(value.replace(/\D/g, "").slice(0, 10));
                setErrorMessage("");
              }}
              keyboardType="phone-pad"
              placeholder="Введите номер телефона"
              placeholderTextColor={colors.textSecondary}
              style={styles.phoneInput}
              editable={!busy && step === "phone"}
            />
            <Pressable onPress={() => setDigits("")}>
              <MaterialIcons name="cancel" size={24} color="#484848" />
            </Pressable>
          </View>
        </View>

        {step === "code" ? (
          <View style={styles.phoneCard}>
            <Text style={styles.phoneCardTitle}>Код из Telegram</Text>
            <Text style={styles.loginStatus}>{requestPhone || formattedPhone}</Text>
            <TextInput
              value={code}
              onChangeText={(value) => {
                setCode(value.replace(/\D/g, "").slice(0, 6));
                setErrorMessage("");
              }}
              keyboardType="number-pad"
              placeholder="Введите код"
              placeholderTextColor={colors.textSecondary}
              style={styles.field}
              editable={!busy}
            />
            <Pressable
              style={styles.loginLinkButton}
              onPress={() => {
                setStep("phone");
                setStatusMessage("");
                setCode("");
              }}
            >
              <Text style={styles.loginLinkText}>Изменить номер</Text>
            </Pressable>
          </View>
        ) : null}

        {statusMessage ? <Text style={styles.loginStatus}>{statusMessage}</Text> : null}
        {errorMessage ? <Text style={styles.loginError}>{errorMessage}</Text> : null}
      </View>

      <View style={styles.bottomButtonWrap}>
        <PrimaryButton
          label={step === "phone" ? "Получить код" : "Войти"}
          disabled={!canSubmit || busy}
          onPress={() => void handlePrimary()}
        />
      </View>
    </ScrollView>
  );
}

export function CityScreen({
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
  const [query, setQuery] = React.useState("");
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
            {selectedCity === city ? (
              <View style={styles.cityCheck}>
                <MaterialIcons name="check" size={24} color="#FFFFFF" />
              </View>
            ) : null}
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
}

export function PaymentsScreen({
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

export function TransfersScreen({ onBack }: { onBack: () => void }) {
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

export function SettingsScreen({
  phoneNumber,
  city,
  walletState,
  onBack,
  onLogout,
  onOpenCards,
}: {
  phoneNumber: string;
  city: string;
  walletState: WalletState;
  onBack: () => void;
  onLogout: () => void;
  onOpenCards: () => void;
}) {
  return (
    <View style={styles.overlayScreen}>
      <Header title="Настройки" onBack={onBack} />
      <View style={styles.settingsCard}>
        <Text style={styles.settingsPhone}>{phoneNumber}</Text>
        <Text style={styles.settingsCity}>{city}</Text>
        <Text style={styles.settingsMeta}>Баланс: {formatBalance(walletState.balance)} ₸</Text>
      </View>
      <OverlayListRow
        item={{ id: "cards", title: "Мои карты", icon: "credit-card" }}
        color="#E7EDFF"
        onPress={onOpenCards}
      />
      <OverlayListRow
        item={{ id: "logout", title: "Выйти", icon: "logout" }}
        color="#FFE3E3"
        iconColor="#B62424"
        onPress={onLogout}
      />
    </View>
  );
}

export function CardsScreen({
  walletState,
  onBack,
  onAddCard,
  onSetActiveCard,
}: {
  walletState: WalletState;
  onBack: () => void;
  onAddCard: (
    holderName: string,
    number: string,
    cardType: "bank" | "transport",
  ) => void;
  onSetActiveCard: (cardId: string) => void;
}) {
  const [holderName, setHolderName] = React.useState("");
  const [number, setNumber] = React.useState("");
  const [cardType, setCardType] = React.useState<"bank" | "transport">("bank");
  const activeCard = getActiveCard(walletState);
  const normalizedNumber = normalizeCardNumber(number);
  const canAdd =
    holderName.trim().length > 0 &&
    (cardType === "transport" ? normalizedNumber.length >= 6 : normalizedNumber.length >= 16);

  return (
    <View style={styles.overlayScreen}>
      <Header title="Карты" onBack={onBack} />
      <ScrollView showsVerticalScrollIndicator={false}>
        {walletState.cards.length === 0 ? (
          <View style={styles.emptyCardState}>
            <Text style={styles.emptyCardText}>Пока нет добавленных карт. Добавьте первую карту ниже.</Text>
          </View>
        ) : (
          walletState.cards.map((card) => (
            <Pressable
              key={card.id}
              style={[styles.savedCard, activeCard?.id === card.id && styles.savedCardActive]}
              onPress={() => onSetActiveCard(card.id)}
            >
              <View style={styles.savedCardIcon}>
                <MaterialIcons name="credit-card" size={24} color={colors.primaryBlue} />
              </View>
              <View style={styles.savedCardCopy}>
                <Text style={styles.savedCardTitle}>{card.holderName}</Text>
                <Text style={styles.savedCardSubtitle}>
                  {card.cardType === "transport" ? "Транспортная" : "Банковская"} •{" "}
                  {maskCardNumber(card.number)}
                </Text>
              </View>
              {activeCard?.id === card.id ? (
                <MaterialIcons name="check-circle" size={24} color={colors.primaryBlue} />
              ) : null}
            </Pressable>
          ))
        )}

        <View style={styles.cardTypeRow}>
          <Pressable
            style={[styles.cardTypeChip, cardType === "bank" && styles.cardTypeChipActive]}
            onPress={() => setCardType("bank")}
          >
            <Text style={[styles.cardTypeText, cardType === "bank" && styles.cardTypeTextActive]}>
              Банковская
            </Text>
          </Pressable>
          <Pressable
            style={[
              styles.cardTypeChip,
              cardType === "transport" && styles.cardTypeChipActive,
            ]}
            onPress={() => setCardType("transport")}
          >
            <Text
              style={[
                styles.cardTypeText,
                cardType === "transport" && styles.cardTypeTextActive,
              ]}
            >
              Транспортная
            </Text>
          </Pressable>
        </View>

        <TextInput
          value={holderName}
          onChangeText={setHolderName}
          placeholder="Название карты"
          placeholderTextColor={colors.textSecondary}
          style={styles.field}
        />
        <TextInput
          value={number}
          onChangeText={(value) =>
            setNumber(value.replace(cardType === "transport" ? /[^0-9A-Za-z]/g : /\D/g, "").slice(0, 16))
          }
          placeholder={cardType === "transport" ? "Номер транспортной карты" : "Номер карты"}
          placeholderTextColor={colors.textSecondary}
          keyboardType={cardType === "transport" ? "default" : "number-pad"}
          autoCapitalize="characters"
          style={styles.field}
        />

        <PrimaryButton
          label="Добавить карту"
          disabled={!canAdd}
          onPress={() => {
            onAddCard(holderName.trim(), normalizedNumber, cardType);
            setHolderName("");
            setNumber("");
            setCardType("bank");
          }}
        />
      </ScrollView>
    </View>
  );
}

export function TopUpScreen({
  balance,
  onBack,
  onTopUp,
}: {
  balance: number;
  onBack: () => void;
  onTopUp: (amount: number) => void;
}) {
  const [value, setValue] = React.useState("1000");

  return (
    <View style={styles.overlayScreen}>
      <Header title="Пополнение баланса" onBack={onBack} />
      <View style={styles.balanceBanner}>
        <Text style={styles.balanceLabel}>Текущий баланс</Text>
        <Text style={styles.balanceValue}>{formatBalance(balance)} ₸</Text>
      </View>
      <View style={styles.amountRow}>
        {[500, 1000, 2000, 5000].map((amount) => (
          <Pressable
            key={amount}
            style={[styles.amountChip, Number(value) === amount && styles.amountChipActive]}
            onPress={() => setValue(String(amount))}
          >
            <Text style={[styles.amountChipText, Number(value) === amount && styles.amountChipTextActive]}>
              {amount} ₸
            </Text>
          </Pressable>
        ))}
      </View>
      <TextInput
        value={value}
        onChangeText={(next) => setValue(next.replace(/[^0-9]/g, ""))}
        placeholder="Сумма пополнения"
        placeholderTextColor={colors.textSecondary}
        keyboardType="number-pad"
        style={styles.field}
      />
      <View style={styles.bottomButtonWrap}>
        <PrimaryButton label="Пополнить" disabled={!Number(value)} onPress={() => onTopUp(Number(value))} />
      </View>
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
      <MaterialIcons name={icon as never} size={28} color={colors.textSecondary} />
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
        <MaterialIcons name={item.icon as never} size={28} color={iconColor} />
      </View>
      <Text style={styles.overlayRowTitle}>{item.title}</Text>
      <MaterialIcons name="chevron-right" size={30} color={colors.textPrimary} />
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
    <Pressable style={[styles.primaryButton, disabled && styles.primaryButtonDisabled]} onPress={disabled ? undefined : onPress}>
      <Text style={styles.primaryButtonLabel}>{label}</Text>
    </Pressable>
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

const styles = StyleSheet.create({
  overlayScreen: { flex: 1, backgroundColor: "#FFFFFF", paddingHorizontal: 24, paddingBottom: 24 },
  loginScreen: { minHeight: "100%", backgroundColor: "#FFFFFF", paddingHorizontal: 24, paddingTop: 16, paddingBottom: 28 },
  skylineWrap: { height: 170, justifyContent: "flex-end", alignItems: "center" },
  skyline: { position: "absolute", left: 0, right: 0, top: 10, bottom: 12, borderBottomLeftRadius: 32, borderBottomRightRadius: 32, backgroundColor: "#EFF2FC" },
  busBadge: { width: 52, height: 52, borderRadius: 14, backgroundColor: colors.accentYellow, alignItems: "center", justifyContent: "center", ...shadow },
  loginCard: { backgroundColor: "#FFFFFF", borderRadius: 30, paddingHorizontal: 20, paddingTop: 16, paddingBottom: 18, ...shadow },
  dragHandle: { alignSelf: "center", width: 78, height: 5, borderRadius: 999, backgroundColor: "#D7D7D7" },
  loginTitle: { marginTop: 22, fontSize: 22, fontWeight: "700", color: colors.textPrimary },
  loginSubtitle: { marginTop: 8, fontSize: 16, color: colors.textSecondary },
  loginStatus: { marginTop: 12, fontSize: 14, lineHeight: 20, color: colors.textSecondary },
  loginError: { marginTop: 10, fontSize: 14, lineHeight: 20, color: "#C62828" },
  phoneCard: { marginTop: 26, backgroundColor: "#FFFFFF", borderRadius: 24, paddingHorizontal: 16, paddingTop: 18, paddingBottom: 16, ...shadow },
  phoneCardTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  phoneInputWrap: { marginTop: 16, minHeight: 72, borderRadius: 20, backgroundColor: colors.surfaceMuted, paddingHorizontal: 16, flexDirection: "row", alignItems: "center" },
  flag: { fontSize: 22 },
  countryCode: { marginLeft: 10, fontSize: 18, color: colors.textPrimary },
  inputDivider: { width: 1, height: 30, backgroundColor: "#3C3C3C", marginHorizontal: 16 },
  phoneInput: { flex: 1, fontSize: 18, color: colors.textPrimary },
  loginLinkButton: { alignSelf: "flex-start", marginTop: 8, paddingVertical: 6 },
  loginLinkText: { fontSize: 14, color: colors.primaryBlue, fontWeight: "600" },
  bottomButtonWrap: { marginTop: "auto", paddingTop: 24 },
  header: { height: 56, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  headerBack: { width: 40, alignItems: "flex-start", justifyContent: "center" },
  headerTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  searchField: { height: 72, marginTop: 6, marginBottom: 14, borderRadius: 18, backgroundColor: colors.surfaceMuted, paddingHorizontal: 18, flexDirection: "row", alignItems: "center" },
  searchInput: { flex: 1, marginLeft: 12, fontSize: 18, color: colors.textPrimary },
  cityRow: { minHeight: 72, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  cityText: { fontSize: 20, color: colors.textPrimary },
  cityCheck: { width: 38, height: 38, borderRadius: 19, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center" },
  tabsRow: { flexDirection: "row", gap: 26, marginTop: 10, marginBottom: 12 },
  topTabWrap: { alignItems: "flex-start" },
  topTabLabel: { fontSize: 16, fontWeight: "500", color: colors.textSecondary },
  topTabLabelSelected: { fontWeight: "700", color: colors.textPrimary },
  topTabLine: { width: 82, height: 4, marginTop: 10, borderRadius: 999, backgroundColor: "transparent" },
  topTabLineSelected: { backgroundColor: colors.primaryBlue },
  overlayRow: { flexDirection: "row", alignItems: "center", paddingVertical: 16 },
  overlayIconCircle: { width: 54, height: 54, borderRadius: 27, alignItems: "center", justifyContent: "center" },
  overlayRowTitle: { flex: 1, marginLeft: 14, fontSize: 17, color: colors.textPrimary },
  settingsCard: { marginTop: 20, borderRadius: 22, backgroundColor: colors.surfaceMuted, padding: 20 },
  settingsPhone: { fontSize: 18, fontWeight: "700", color: colors.textPrimary },
  settingsCity: { marginTop: 6, fontSize: 16, color: colors.textSecondary },
  settingsMeta: { marginTop: 10, fontSize: 15, color: colors.textSecondary },
  emptyCardState: { padding: 20, borderRadius: 22, backgroundColor: colors.surfaceMuted, marginBottom: 14 },
  emptyCardText: { fontSize: 16, color: colors.textSecondary },
  savedCard: { padding: 18, borderRadius: 22, backgroundColor: colors.surfaceMuted, flexDirection: "row", alignItems: "center", marginBottom: 14 },
  savedCardActive: { borderWidth: 1, borderColor: colors.primaryBlue, backgroundColor: "rgba(36,87,245,0.08)" },
  savedCardIcon: { width: 42, height: 42, borderRadius: 21, backgroundColor: "#FFFFFF", alignItems: "center", justifyContent: "center" },
  savedCardCopy: { flex: 1, marginLeft: 12 },
  savedCardTitle: { fontSize: 16, fontWeight: "600", color: colors.textPrimary },
  savedCardSubtitle: { marginTop: 4, fontSize: 14, color: colors.textSecondary },
  cardTypeRow: { flexDirection: "row", gap: 10, marginBottom: 14 },
  cardTypeChip: { flex: 1, paddingVertical: 12, borderRadius: 16, backgroundColor: "#F0F4FF", alignItems: "center" },
  cardTypeChipActive: { backgroundColor: "rgba(36,87,245,0.14)" },
  cardTypeText: { fontSize: 14, color: colors.textPrimary },
  cardTypeTextActive: { color: colors.primaryBlue, fontWeight: "700" },
  field: { height: 60, borderRadius: 18, backgroundColor: colors.surfaceMuted, paddingHorizontal: 18, fontSize: 17, color: colors.textPrimary, marginTop: 14, marginBottom: 14 },
  balanceBanner: { marginTop: 20, borderRadius: 22, backgroundColor: colors.banner, padding: 20 },
  balanceLabel: { fontSize: 15, color: "#D7DCEC" },
  balanceValue: { marginTop: 8, fontSize: 24, fontWeight: "700", color: "#FFFFFF" },
  amountRow: { flexDirection: "row", flexWrap: "wrap", gap: 12, marginTop: 20, marginBottom: 20 },
  amountChip: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 999, backgroundColor: "#F0F4FF" },
  amountChipActive: { backgroundColor: "rgba(36,87,245,0.14)" },
  amountChipText: { fontSize: 15, color: colors.textPrimary },
  amountChipTextActive: { color: colors.primaryBlue },
  primaryButton: { height: 64, borderRadius: 18, backgroundColor: colors.primaryBlue, alignItems: "center", justifyContent: "center" },
  primaryButtonDisabled: { backgroundColor: "#C8C8C8" },
  primaryButtonLabel: { fontSize: 18, color: "#FFFFFF" },
});
