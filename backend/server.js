const cors = require("cors");
const crypto = require("crypto");
const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = Number(process.env.PORT || 4000);
const storePath = path.join(__dirname, "data", "store.json");
const publicDir = path.join(__dirname, "public");

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const AUTH_CODE_TTL_MS = 5 * 60 * 1000;
const RIDE_TICKET_TTL_MS = 45 * 60 * 1000;
const DEFAULT_ADMIN_TOKEN = process.env.ADMIN_TOKEN || "avtobys-admin-dev";
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "";
const TELEGRAM_DEFAULT_CHAT_ID = process.env.TELEGRAM_DEFAULT_CHAT_ID || "";
const TELEGRAM_CHAT_MAP = safeJsonObject(process.env.TELEGRAM_CHAT_MAP_JSON);
const IS_PROD = process.env.NODE_ENV === "production";

app.use(cors());
app.use(express.json({ limit: "1mb" }));
app.use(express.static(publicDir));

// HELPERS
function nowIso() {
  return new Date().toISOString();
}

function futureIso(ms) {
  return new Date(Date.now() + ms).toISOString();
}

function id(prefix) {
  return `${prefix}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}`;
}

function safeJsonObject(value) {
  if (!value) {
    return {};
  }

  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function normalizePhoneNumber(value) {
  const digits = `${value || ""}`.replace(/\D/g, "");
  if (!digits) {
    return "";
  }
  if (digits.length === 11 && digits.startsWith("8")) {
    return `+7${digits.slice(1)}`;
  }
  if (digits.length === 11 && digits.startsWith("7")) {
    return `+${digits}`;
  }
  if (digits.length === 10) {
    return `+7${digits}`;
  }
  return `+${digits}`;
}

function normalizeTransportValue(value) {
  return `${value || ""}`.replace(/[^0-9A-Za-z]+/g, "").toUpperCase();
}

function normalizeCardNumber(value) {
  return `${value || ""}`.replace(/\s+/g, "").toUpperCase();
}

function createLoginCode() {
  return `${Math.floor(1000 + Math.random() * 9000)}`;
}

function parsePositiveAmount(value) {
  const amount = Number(value);
  return Number.isFinite(amount) && amount > 0 ? amount : 0;
}

function toBool(value, fallback = false) {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    return value === "true";
  }
  return fallback;
}

// STORE
function defaultStore() {
  return {
    meta: {
      version: 3,
      updatedAt: nowIso(),
    },
    appSettings: {
      appName: "Avtobys MVP",
      supportPhone: "+7 700-255-56-19",
      supportTelegram: "@avtobys_support_bot",
      loginDeliveryMode: "telegram",
      defaultLanguage: "Русский",
      availableLanguages: ["Русский", "Қазақша"],
      shareUrl: "https://avtobys.local/app",
      currencySymbol: "₸",
      newUserBonusBalance: 3000,
      minimumTopUpAmount: 500,
      maintenanceMode: false,
    },
    cities: [
      { id: "aktau", name: "Актау" },
      { id: "astana", name: "Астана" },
      { id: "almaty", name: "Алматы" },
    ],
    tariffs: [
      { id: "aktau-standard", cityId: "aktau", name: "Стандарт", price: 70 },
      { id: "aktau-student", cityId: "aktau", name: "Студент", price: 50 },
      { id: "astana-standard", cityId: "astana", name: "Стандарт", price: 80 },
      { id: "almaty-standard", cityId: "almaty", name: "Стандарт", price: 90 },
    ],
    buses: [
      {
        id: "bus-1",
        cityId: "aktau",
        number: "861AQ12",
        routeNumber: "№ 11",
        tariffId: "aktau-standard",
        bluetoothEnabled: true,
        validatorName: "861AQ12",
        qrToken: "bus-1-qr",
      },
      {
        id: "bus-2",
        cityId: "astana",
        number: "852CS02",
        routeNumber: "№ 12",
        tariffId: "astana-standard",
        bluetoothEnabled: true,
        validatorName: "852CS02",
        qrToken: "bus-2-qr",
      },
      {
        id: "bus-3",
        cityId: "almaty",
        number: "870KM05",
        routeNumber: "№ 32",
        tariffId: "almaty-standard",
        bluetoothEnabled: true,
        validatorName: "870KM05",
        qrToken: "bus-3-qr",
      },
    ],
    tickets: [],
    users: [],
    sessions: [],
    authCodes: [],
    walletTransactions: [],
    supportMessages: [],
    notifications: [],
    telegramDeliveries: [],
    admins: [
      {
        id: "admin-dev",
        name: "Local Admin",
        token: DEFAULT_ADMIN_TOKEN,
      },
    ],
  };
}

function migrateUser(user) {
  const wallet = user.wallet || {};
  const cards = Array.isArray(wallet.cards)
    ? wallet.cards.map((card) => ({
        id: card.id || id("card"),
        holderName: card.holderName || "Моя карта",
        number: normalizeCardNumber(card.number),
        cardType: card.cardType === "transport" ? "transport" : "bank",
        addedAt: card.addedAt || user.createdAt || nowIso(),
      }))
    : [];

  return {
    id: user.id || id("user"),
    phoneNumber: normalizePhoneNumber(user.phoneNumber),
    fullName: user.fullName || "Новый пользователь",
    cityName: user.cityName || "",
    telegramChatId: user.telegramChatId || "",
    status: user.status || "active",
    createdAt: user.createdAt || nowIso(),
    updatedAt: user.updatedAt || nowIso(),
    settings: {
      language: user.settings?.language || "Русский",
      notificationsEnabled: user.settings?.notificationsEnabled !== false,
      appTheme: user.settings?.appTheme || "light",
    },
    wallet: {
      balance: Number(wallet.balance || 0),
      cards,
      activeCardId: wallet.activeCardId || cards[0]?.id || null,
    },
  };
}

function migrateStore(store) {
  const base = defaultStore();
  const next = {
    ...base,
    ...store,
  };

  next.meta = {
    ...base.meta,
    ...(store.meta || {}),
    version: 3,
  };
  next.appSettings = {
    ...base.appSettings,
    ...(store.appSettings || {}),
  };
  next.cities = Array.isArray(store.cities) && store.cities.length ? store.cities : base.cities;
  next.tariffs =
    Array.isArray(store.tariffs) && store.tariffs.length ? store.tariffs : base.tariffs;
  next.buses = Array.isArray(store.buses) && store.buses.length
    ? store.buses.map((bus) => ({
        ...bus,
        number: `${bus.number || ""}`.trim().toUpperCase(),
        validatorName: `${bus.validatorName || bus.number || ""}`.trim().toUpperCase(),
        qrToken: `${bus.qrToken || `qr-${bus.id || Date.now()}`}`.trim(),
      }))
    : base.buses;
  next.tickets = Array.isArray(store.tickets) ? store.tickets : [];
  next.users = Array.isArray(store.users) ? store.users.map(migrateUser) : [];
  next.sessions = Array.isArray(store.sessions) ? store.sessions : [];
  next.authCodes = Array.isArray(store.authCodes) ? store.authCodes : [];
  next.walletTransactions = Array.isArray(store.walletTransactions)
    ? store.walletTransactions
    : [];
  next.supportMessages = Array.isArray(store.supportMessages) ? store.supportMessages : [];
  next.notifications = Array.isArray(store.notifications) ? store.notifications : [];
  next.telegramDeliveries = Array.isArray(store.telegramDeliveries)
    ? store.telegramDeliveries
    : [];
  next.admins =
    Array.isArray(store.admins) && store.admins.length ? store.admins : base.admins;

  return next;
}

function readStore() {
  const raw = fs.existsSync(storePath) ? fs.readFileSync(storePath, "utf8") : "{}";
  return migrateStore(JSON.parse(raw || "{}"));
}

function writeStore(store) {
  fs.mkdirSync(path.dirname(storePath), { recursive: true });
  store.meta = {
    ...(store.meta || {}),
    version: 3,
    updatedAt: nowIso(),
  };
  fs.writeFileSync(storePath, JSON.stringify(store, null, 2));
}

// ROUTES
app.get("/api/health", (_req, res) => {
  const store = readStore();
  res.json({
    ok: true,
    now: nowIso(),
    ...serializeSummary(store),
  });
});

app.get("/api/config/public", (_req, res) => {
  const store = readStore();
  res.json(serializePublicConfig(store));
});

app.get("/api/summary", (_req, res) => {
  const store = readStore();
  res.json(serializeSummary(store));
});

app.post("/api/auth/request-code", async (req, res) => {
  try {
    const store = readStore();
    const phoneNumber = normalizePhoneNumber(req.body.phoneNumber);
    if (!phoneNumber) {
      res.status(400).json({ message: "Phone number is required" });
      return;
    }

    const user = ensureUser(store, phoneNumber, {
      fullName: req.body.fullName,
      cityName: req.body.cityName,
      telegramChatId: req.body.telegramChatId,
    });
    const code = createLoginCode();
    const delivery = await sendTelegramCode(store, phoneNumber, code, req.body.telegramChatId);

    store.authCodes = store.authCodes.filter(
      (item) =>
        item.phoneNumber !== phoneNumber &&
        new Date(item.expiresAt).getTime() > Date.now() - AUTH_CODE_TTL_MS,
    );
    store.authCodes.push({
      id: id("auth"),
      phoneNumber,
      code,
      status: "pending",
      attempts: 0,
      createdAt: nowIso(),
      expiresAt: futureIso(AUTH_CODE_TTL_MS),
      deliveryId: delivery.id,
    });
    store.telegramDeliveries.push(delivery);
    user.updatedAt = nowIso();
    writeStore(store);

    res.json({
      ok: true,
      phoneNumber,
      expiresAt: futureIso(AUTH_CODE_TTL_MS),
      delivery,
      debugCode: IS_PROD ? undefined : code,
    });
  } catch (error) {
    res.status(500).json({
      message: error instanceof Error ? error.message : "Failed to request code",
    });
  }
});

app.post("/api/auth/verify-code", (req, res) => {
  const store = readStore();
  const phoneNumber = normalizePhoneNumber(req.body.phoneNumber);
  const code = `${req.body.code || ""}`.trim();
  if (!phoneNumber || !code) {
    res.status(400).json({ message: "Phone number and code are required" });
    return;
  }

  const authCode = store.authCodes
    .filter(
      (item) =>
        item.phoneNumber === phoneNumber &&
        item.status === "pending" &&
        new Date(item.expiresAt).getTime() > Date.now(),
    )
    .slice()
    .reverse()
    .find((item) => item.code === code);

  if (!authCode) {
    res.status(400).json({ message: "Invalid or expired code" });
    return;
  }

  authCode.status = "used";
  const user = ensureUser(store, phoneNumber, {
    cityName: req.body.cityName,
    fullName: req.body.fullName,
  });
  const session = issueSession(store, user);
  writeStore(store);

  res.json({
    token: session.token,
    user: serializeUser(user),
    wallet: serializeWallet(store, user),
    config: serializePublicConfig(store),
  });
});

app.get("/api/auth/debug-last-code", (req, res) => {
  if (IS_PROD) {
    res.status(404).json({ message: "Not available" });
    return;
  }

  const store = readStore();
  const phoneNumber = normalizePhoneNumber(req.query.phone);
  const latest = store.authCodes
    .filter((item) => item.phoneNumber === phoneNumber)
    .slice()
    .reverse()[0];

  res.json({
    phoneNumber,
    code: latest?.code || null,
    status: latest?.status || null,
    expiresAt: latest?.expiresAt || null,
  });
});

app.get("/api/auth/me", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  writeStore(context.store);
  res.json({
    token: parseAuthToken(req),
    user: serializeUser(context.user),
    wallet: serializeWallet(context.store, context.user),
    config: serializePublicConfig(context.store),
  });
});

app.post("/api/auth/logout", (req, res) => {
  const store = readStore();
  const token = parseAuthToken(req);
  if (token) {
    store.sessions = store.sessions.filter((item) => item.token !== token);
    writeStore(store);
  }
  res.json({ ok: true });
});

app.get("/api/me", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  writeStore(context.store);
  res.json(serializeUser(context.user));
});

app.patch("/api/me", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  const { user, store } = context;
  if (typeof req.body.fullName === "string" && req.body.fullName.trim()) {
    user.fullName = req.body.fullName.trim();
  }
  if (typeof req.body.cityName === "string") {
    user.cityName = req.body.cityName.trim();
  }
  if (typeof req.body.telegramChatId === "string") {
    user.telegramChatId = req.body.telegramChatId.trim();
  }
  user.updatedAt = nowIso();
  writeStore(store);
  res.json(serializeUser(user));
});

app.get("/api/settings", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  writeStore(context.store);
  res.json({
    ...context.user.settings,
    cityName: context.user.cityName,
    supportPhone: context.store.appSettings.supportPhone,
    supportTelegram: context.store.appSettings.supportTelegram,
  });
});

app.patch("/api/settings", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  const { user, store } = context;
  if (typeof req.body.language === "string" && req.body.language.trim()) {
    user.settings.language = req.body.language.trim();
  }
  if (typeof req.body.notificationsEnabled === "boolean") {
    user.settings.notificationsEnabled = req.body.notificationsEnabled;
  }
  if (typeof req.body.appTheme === "string" && req.body.appTheme.trim()) {
    user.settings.appTheme = req.body.appTheme.trim();
  }
  if (typeof req.body.cityName === "string") {
    user.cityName = req.body.cityName.trim();
  }
  user.updatedAt = nowIso();
  writeStore(store);
  res.json({
    ...user.settings,
    cityName: user.cityName,
  });
});

app.get("/api/wallet", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  writeStore(context.store);
  res.json(serializeWallet(context.store, context.user));
});

app.get("/api/wallet/cards", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  writeStore(context.store);
  res.json(context.user.wallet.cards || []);
});

app.post("/api/wallet/cards", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  const holderName = `${req.body.holderName || ""}`.trim();
  const number = normalizeCardNumber(req.body.number);
  const cardType = req.body.cardType === "transport" ? "transport" : "bank";
  const minLength = cardType === "transport" ? 6 : 12;

  if (!holderName || number.length < minLength) {
    res.status(400).json({ message: "Card payload is invalid" });
    return;
  }

  const card = {
    id: id("card"),
    holderName,
    number,
    cardType,
    addedAt: nowIso(),
  };
  context.user.wallet.cards.push(card);
  context.user.wallet.activeCardId = card.id;
  context.user.updatedAt = nowIso();
  writeStore(context.store);
  res.status(201).json(card);
});

app.patch("/api/wallet/cards/:cardId", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  const card = context.user.wallet.cards.find((item) => item.id === req.params.cardId);
  if (!card) {
    res.status(404).json({ message: "Card not found" });
    return;
  }

  if (typeof req.body.holderName === "string" && req.body.holderName.trim()) {
    card.holderName = req.body.holderName.trim();
  }
  if (typeof req.body.number === "string" && req.body.number.trim()) {
    card.number = normalizeCardNumber(req.body.number);
  }
  if (req.body.cardType === "transport" || req.body.cardType === "bank") {
    card.cardType = req.body.cardType;
  }
  context.user.updatedAt = nowIso();
  writeStore(context.store);
  res.json(card);
});

app.delete("/api/wallet/cards/:cardId", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  context.user.wallet.cards = context.user.wallet.cards.filter(
    (item) => item.id !== req.params.cardId,
  );
  if (
    context.user.wallet.activeCardId === req.params.cardId &&
    !context.user.wallet.cards.find((item) => item.id === req.params.cardId)
  ) {
    context.user.wallet.activeCardId = context.user.wallet.cards[0]?.id || null;
  }
  context.user.updatedAt = nowIso();
  writeStore(context.store);
  res.json({ ok: true });
});

app.post("/api/wallet/cards/:cardId/activate", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  const card = context.user.wallet.cards.find((item) => item.id === req.params.cardId);
  if (!card) {
    res.status(404).json({ message: "Card not found" });
    return;
  }

  context.user.wallet.activeCardId = card.id;
  context.user.updatedAt = nowIso();
  writeStore(context.store);
  res.json({ ok: true, activeCardId: card.id });
});

app.post("/api/wallet/top-up", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  const amount = parsePositiveAmount(req.body.amount);
  const minimum = Number(context.store.appSettings.minimumTopUpAmount || 0);
  if (!amount || amount < minimum) {
    res.status(400).json({ message: `Minimum top-up amount is ${minimum}` });
    return;
  }

  const before = Number(context.user.wallet.balance || 0);
  const after = before + amount;
  context.user.wallet.balance = after;
  context.user.updatedAt = nowIso();
  createWalletTransaction(context.store, context.user, {
    type: "topup",
    source: req.body.source || "manual",
    description: req.body.description || "Balance top-up",
    amount,
    balanceBefore: before,
    balanceAfter: after,
    meta: {
      cardId: req.body.cardId || context.user.wallet.activeCardId || null,
    },
  });
  writeStore(context.store);
  res.json(serializeWallet(context.store, context.user));
});

app.get("/api/wallet/transactions", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  writeStore(context.store);
  res.json(
    context.store.walletTransactions
      .filter((item) => item.userId === context.user.id)
      .slice()
      .reverse(),
  );
});

app.get("/api/cities", (_req, res) => {
  const store = readStore();
  res.json(store.cities);
});

app.post("/api/cities", (req, res) => {
  const store = readStore();
  const name = `${req.body.name || ""}`.trim();
  if (!name) {
    res.status(400).json({ message: "City name is required" });
    return;
  }

  const city = {
    id: req.body.id || id("city"),
    name,
  };
  store.cities.push(city);
  writeStore(store);
  res.status(201).json(city);
});

app.patch("/api/cities/:cityId", (req, res) => {
  const store = readStore();
  const city = getCity(store, req.params.cityId);
  if (!city) {
    res.status(404).json({ message: "City not found" });
    return;
  }

  if (typeof req.body.name === "string" && req.body.name.trim()) {
    city.name = req.body.name.trim();
  }
  writeStore(store);
  res.json(city);
});

app.delete("/api/cities/:cityId", (req, res) => {
  const store = readStore();
  store.cities = store.cities.filter((item) => item.id !== req.params.cityId);
  store.tariffs = store.tariffs.filter((item) => item.cityId !== req.params.cityId);
  store.buses = store.buses.filter((item) => item.cityId !== req.params.cityId);
  writeStore(store);
  res.json({ ok: true });
});

app.get("/api/tariffs", (req, res) => {
  const store = readStore();
  const cityId = `${req.query.cityId || ""}`.trim();
  const tariffs = cityId
    ? store.tariffs.filter((item) => item.cityId === cityId)
    : store.tariffs;
  res.json(tariffs.map((item) => ({ ...item, price: Number(item.price || 0) })));
});

app.post("/api/tariffs", (req, res) => {
  const store = readStore();
  if (!getCity(store, req.body.cityId)) {
    res.status(400).json({ message: "City not found" });
    return;
  }

  const tariff = {
    id: req.body.id || id("tariff"),
    cityId: req.body.cityId,
    name: `${req.body.name || ""}`.trim() || "Стандарт",
    price: parsePositiveAmount(req.body.price),
  };
  store.tariffs.push(tariff);
  writeStore(store);
  res.status(201).json(tariff);
});

app.patch("/api/tariffs/:tariffId", (req, res) => {
  const store = readStore();
  const tariff = getTariff(store, req.params.tariffId);
  if (!tariff) {
    res.status(404).json({ message: "Tariff not found" });
    return;
  }

  if (typeof req.body.name === "string" && req.body.name.trim()) {
    tariff.name = req.body.name.trim();
  }
  if (req.body.price !== undefined) {
    tariff.price = parsePositiveAmount(req.body.price);
  }
  writeStore(store);
  res.json(tariff);
});

app.delete("/api/tariffs/:tariffId", (req, res) => {
  const store = readStore();
  store.tariffs = store.tariffs.filter((item) => item.id !== req.params.tariffId);
  store.buses = store.buses.filter((item) => item.tariffId !== req.params.tariffId);
  writeStore(store);
  res.json({ ok: true });
});

app.get("/api/buses", (req, res) => {
  const store = readStore();
  const cityId = `${req.query.cityId || ""}`.trim();
  const number = normalizeTransportValue(req.query.number);
  const qrToken = `${req.query.qrToken || ""}`.trim();
  const bluetoothOnly = req.query.bluetooth === "true";

  let buses = store.buses.slice();
  if (cityId) {
    buses = buses.filter((item) => item.cityId === cityId);
  }
  if (number) {
    buses = buses.filter((item) =>
      normalizeTransportValue(item.number).includes(number) ||
      normalizeTransportValue(item.validatorName || "").includes(number),
    );
  }
  if (qrToken) {
    buses = buses.filter(
      (item) =>
        item.qrToken === qrToken ||
        normalizeTransportValue(item.number) === normalizeTransportValue(qrToken),
    );
  }
  if (bluetoothOnly) {
    buses = buses.filter((item) => Boolean(item.bluetoothEnabled));
  }

  res.json(buses.map((item) => withBusRelations(store, item)));
});

app.post("/api/buses", (req, res) => {
  const store = readStore();
  if (!getCity(store, req.body.cityId) || !getTariff(store, req.body.tariffId)) {
    res.status(400).json({ message: "City or tariff not found" });
    return;
  }

  const bus = {
    id: req.body.id || id("bus"),
    cityId: req.body.cityId,
    number: `${req.body.number || ""}`.trim().toUpperCase(),
    routeNumber: `${req.body.routeNumber || ""}`.trim() || "№ 1",
    tariffId: req.body.tariffId,
    bluetoothEnabled: toBool(req.body.bluetoothEnabled, true),
    validatorName: `${req.body.validatorName || req.body.number || ""}`.trim().toUpperCase(),
    qrToken: `${req.body.qrToken || `qr-${Date.now()}`}`.trim(),
  };
  if (!bus.number) {
    res.status(400).json({ message: "Bus number is required" });
    return;
  }

  store.buses.push(bus);
  writeStore(store);
  res.status(201).json(withBusRelations(store, bus));
});

app.patch("/api/buses/:busId", (req, res) => {
  const store = readStore();
  const bus = getBus(store, req.params.busId);
  if (!bus) {
    res.status(404).json({ message: "Bus not found" });
    return;
  }

  if (typeof req.body.number === "string" && req.body.number.trim()) {
    bus.number = req.body.number.trim().toUpperCase();
  }
  if (typeof req.body.routeNumber === "string" && req.body.routeNumber.trim()) {
    bus.routeNumber = req.body.routeNumber.trim();
  }
  if (typeof req.body.tariffId === "string" && getTariff(store, req.body.tariffId)) {
    bus.tariffId = req.body.tariffId;
  }
  if (typeof req.body.qrToken === "string" && req.body.qrToken.trim()) {
    bus.qrToken = req.body.qrToken.trim();
  }
  if (req.body.bluetoothEnabled !== undefined) {
    bus.bluetoothEnabled = toBool(req.body.bluetoothEnabled, bus.bluetoothEnabled);
  }
  if (typeof req.body.validatorName === "string" && req.body.validatorName.trim()) {
    bus.validatorName = req.body.validatorName.trim().toUpperCase();
  }
  writeStore(store);
  res.json(withBusRelations(store, bus));
});

app.delete("/api/buses/:busId", (req, res) => {
  const store = readStore();
  store.buses = store.buses.filter((item) => item.id !== req.params.busId);
  writeStore(store);
  res.json({ ok: true });
});

app.get("/api/tickets", (req, res) => {
  const store = readStore();
  const auth = getSessionContext(req, store);
  const phoneNumber = normalizePhoneNumber(req.query.phone);
  const targetPhone = auth?.user.phoneNumber || phoneNumber;
  const tickets = targetPhone
    ? store.tickets.filter(
        (item) => normalizePhoneNumber(item.phoneNumber) === targetPhone,
      )
    : store.tickets;

  writeStore(store);
  res.json(tickets.slice().reverse().map((item) => withTicketRelations(store, item)));
});

app.post("/api/tickets", (req, res) => {
  const store = readStore();
  const auth = getSessionContext(req, store);
  const user =
    auth?.user ||
    (req.body.phoneNumber ? ensureUser(store, normalizePhoneNumber(req.body.phoneNumber)) : null);

  if (!user) {
    res.status(401).json({ message: "Authentication or phone number is required" });
    return;
  }

  const bus = getBus(store, req.body.busId);
  if (!bus) {
    res.status(404).json({ message: "Bus not found" });
    return;
  }

  const relatedBus = withBusRelations(store, bus);
  const amount = Number(relatedBus.price || 0);
  const paymentMethod = `${req.body.paymentMethod || "wallet"}`.trim();
  const requestedCity =
    getCity(store, `${req.body.cityId || ""}`.trim()) ||
    getCityByName(store, req.body.cityName) ||
    getCityByName(store, user.cityName) ||
    getCity(store, bus.cityId);

  if (paymentMethod === "wallet") {
    const before = Number(user.wallet.balance || 0);
    if (before < amount) {
      res.status(400).json({ message: "Insufficient wallet balance" });
      return;
    }
    user.wallet.balance = before - amount;
    createWalletTransaction(store, user, {
      type: "ride",
      source: "ticket",
      description: `Ride payment for ${relatedBus.number}`,
      amount: -amount,
      balanceBefore: before,
      balanceAfter: user.wallet.balance,
      meta: {
        busId: bus.id,
        routeNumber: relatedBus.routeNumber,
      },
    });
  }

  const ticket = {
    id: id("ticket"),
    userId: user.id,
    phoneNumber: user.phoneNumber,
    cityId: requestedCity?.id || bus.cityId,
    cityName: requestedCity?.name || user.cityName || relatedBus.cityName,
    busId: bus.id,
    busNumber: relatedBus.number,
    routeNumber: relatedBus.routeNumber,
    tariffName: relatedBus.tariffName,
    amount,
    paymentMethod,
    qrValue: `${bus.qrToken}:${Date.now()}`,
    paidAt: nowIso(),
    validUntil: futureIso(RIDE_TICKET_TTL_MS),
    status: "active",
  };

  store.tickets.push(ticket);
  user.updatedAt = nowIso();
  createNotification(
    store,
    user.id,
    "Оплата проезда",
    `${relatedBus.routeNumber} • ${amount} ${store.appSettings.currencySymbol}`,
    "ticket",
  );
  writeStore(store);
  res.status(201).json(withTicketRelations(store, ticket));
});

app.post("/api/support", (req, res) => {
  const store = readStore();
  const user = findUserFromRequest(store, req);
  const message = `${req.body.message || ""}`.trim();
  if (!message) {
    res.status(400).json({ message: "Message is required" });
    return;
  }

  const entry = {
    id: id("support"),
    userId: user?.id || null,
    phoneNumber: user?.phoneNumber || normalizePhoneNumber(req.body.phoneNumber),
    subject: `${req.body.subject || "Support request"}`.trim(),
    message,
    status: "new",
    createdAt: nowIso(),
  };
  store.supportMessages.push(entry);
  if (user) {
    createNotification(store, user.id, "Support request", "Support request created.");
  }
  writeStore(store);
  res.status(201).json(entry);
});

app.get("/api/notifications", (req, res) => {
  const store = readStore();
  const user = findUserFromRequest(store, req);
  if (!user) {
    res.json([]);
    return;
  }

  writeStore(store);
  res.json(
    store.notifications
      .filter((item) => item.userId === user.id)
      .slice()
      .reverse(),
  );
});

app.patch("/api/notifications/:notificationId/read", (req, res) => {
  const context = requireUserContext(req, res);
  if (!context) {
    return;
  }

  const notification = context.store.notifications.find(
    (item) =>
      item.id === req.params.notificationId && item.userId === context.user.id,
  );
  if (!notification) {
    res.status(404).json({ message: "Notification not found" });
    return;
  }

  notification.read = true;
  writeStore(context.store);
  res.json(notification);
});
function ensureUser(store, phoneNumber, payload = {}) {
  const normalizedPhone = normalizePhoneNumber(phoneNumber);
  let user = store.users.find((item) => item.phoneNumber === normalizedPhone);

  if (!user) {
    user = migrateUser({
      id: id("user"),
      phoneNumber: normalizedPhone,
      fullName: payload.fullName || "Новый пользователь",
      cityName: payload.cityName || "",
      telegramChatId: payload.telegramChatId || "",
      createdAt: nowIso(),
      updatedAt: nowIso(),
      wallet: {
        balance: Number(store.appSettings.newUserBonusBalance || 0),
        cards: [],
        activeCardId: null,
      },
    });
    store.users.push(user);
    createNotification(store, user.id, "Добро пожаловать", "Аккаунт создан и готов к поездкам.");
  } else {
    if (payload.fullName) {
      user.fullName = payload.fullName;
    }
    if (payload.cityName) {
      user.cityName = payload.cityName;
    }
    if (payload.telegramChatId) {
      user.telegramChatId = payload.telegramChatId;
    }
    user.updatedAt = nowIso();
  }

  return user;
}

function serializeUser(user) {
  return {
    id: user.id,
    phoneNumber: user.phoneNumber,
    fullName: user.fullName,
    cityName: user.cityName,
    telegramChatId: user.telegramChatId,
    status: user.status,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
    settings: user.settings,
  };
}

function serializePublicConfig(store) {
  return {
    appName: store.appSettings.appName,
    supportPhone: store.appSettings.supportPhone,
    supportTelegram: store.appSettings.supportTelegram,
    loginDeliveryMode: store.appSettings.loginDeliveryMode,
    defaultLanguage: store.appSettings.defaultLanguage,
    availableLanguages: store.appSettings.availableLanguages,
    shareUrl: store.appSettings.shareUrl,
    currencySymbol: store.appSettings.currencySymbol,
    newUserBonusBalance: Number(store.appSettings.newUserBonusBalance || 0),
    minimumTopUpAmount: Number(store.appSettings.minimumTopUpAmount || 0),
    maintenanceMode: Boolean(store.appSettings.maintenanceMode),
    debugAuthCodeVisible: !IS_PROD,
  };
}

function serializeWallet(store, user) {
  return {
    balance: Number(user.wallet.balance || 0),
    cards: user.wallet.cards || [],
    activeCardId: user.wallet.activeCardId || null,
    transactions: store.walletTransactions
      .filter((item) => item.userId === user.id)
      .slice()
      .reverse(),
  };
}

function getCity(store, cityId) {
  return store.cities.find((item) => item.id === cityId) || null;
}

function getCityByName(store, cityName) {
  const normalizedName = `${cityName || ""}`.trim().toLowerCase();
  if (!normalizedName) {
    return null;
  }

  return (
    store.cities.find((item) => `${item.name || ""}`.trim().toLowerCase() === normalizedName) ||
    null
  );
}

function getTariff(store, tariffId) {
  return store.tariffs.find((item) => item.id === tariffId) || null;
}

function getBus(store, busId) {
  return store.buses.find((item) => item.id === busId) || null;
}

function withBusRelations(store, bus) {
  const tariff = getTariff(store, bus.tariffId);
  const city = getCity(store, bus.cityId);
  return {
    ...bus,
    cityName: city?.name || "",
    tariffName: tariff?.name || "",
    price: Number(tariff?.price || 0),
  };
}

function withTicketRelations(store, ticket) {
  const bus = getBus(store, ticket.busId);
  const city = getCity(store, ticket.cityId || bus?.cityId);
  const tariff = getTariff(store, bus?.tariffId);
  return {
    ...ticket,
    cityId: ticket.cityId || bus?.cityId || "",
    cityName: ticket.cityName || city?.name || "",
    busNumber: ticket.busNumber || bus?.number || "",
    routeNumber: ticket.routeNumber || bus?.routeNumber || "",
    tariffName: ticket.tariffName || tariff?.name || "",
    amount: Number(ticket.amount || tariff?.price || 0),
  };
}

function createNotification(store, userId, title, body, type = "system") {
  const notification = {
    id: id("notification"),
    userId,
    title,
    body,
    type,
    read: false,
    createdAt: nowIso(),
  };
  store.notifications.push(notification);
  return notification;
}

function createWalletTransaction(store, user, payload) {
  const transaction = {
    id: id("txn"),
    userId: user.id,
    type: payload.type,
    source: payload.source,
    description: payload.description || "",
    amount: Number(payload.amount || 0),
    balanceBefore: Number(payload.balanceBefore || 0),
    balanceAfter: Number(payload.balanceAfter || 0),
    meta: payload.meta || {},
    createdAt: nowIso(),
  };
  store.walletTransactions.push(transaction);
  return transaction;
}

function parseAuthToken(req) {
  const authorization = req.headers.authorization;
  if (typeof authorization === "string" && authorization.startsWith("Bearer ")) {
    return authorization.slice("Bearer ".length).trim();
  }
  const headerToken = req.headers["x-session-token"];
  return typeof headerToken === "string" ? headerToken : "";
}

function getSessionContext(req, store) {
  const token = parseAuthToken(req);
  if (!token) {
    return null;
  }

  store.sessions = store.sessions.filter(
    (item) => new Date(item.expiresAt).getTime() > Date.now(),
  );
  const session = store.sessions.find((item) => item.token === token);
  if (!session) {
    return null;
  }

  const user = store.users.find((item) => item.id === session.userId);
  if (!user) {
    return null;
  }

  session.lastSeenAt = nowIso();
  return { session, user };
}

function issueSession(store, user) {
  const session = {
    id: id("session"),
    token: crypto.randomBytes(24).toString("hex"),
    userId: user.id,
    createdAt: nowIso(),
    lastSeenAt: nowIso(),
    expiresAt: futureIso(SESSION_TTL_MS),
  };
  store.sessions.push(session);
  return session;
}

function requireUserContext(req, res) {
  const store = readStore();
  const context = getSessionContext(req, store);
  if (!context) {
    res.status(401).json({ message: "Unauthorized" });
    return null;
  }
  return { store, ...context };
}

function getAdminToken(req) {
  const headerToken = req.headers["x-admin-token"];
  if (typeof headerToken === "string" && headerToken.trim()) {
    return headerToken.trim();
  }
  if (typeof req.query.adminToken === "string" && req.query.adminToken.trim()) {
    return req.query.adminToken.trim();
  }
  return "";
}

function requireAdminContext(req, res) {
  const store = readStore();
  const token = getAdminToken(req);
  const admin = store.admins.find((item) => item.token === token);
  if (!admin) {
    res.status(401).json({ message: "Admin token required" });
    return null;
  }
  return { store, admin };
}

function resolveTelegramChatId(store, phoneNumber, explicitChatId) {
  const normalizedPhone = normalizePhoneNumber(phoneNumber);
  const user = store.users.find((item) => item.phoneNumber === normalizedPhone);
  return (
    explicitChatId ||
    user?.telegramChatId ||
    TELEGRAM_CHAT_MAP[normalizedPhone] ||
    TELEGRAM_DEFAULT_CHAT_ID ||
    ""
  );
}

async function sendTelegramCode(store, phoneNumber, code, explicitChatId) {
  const chatId = resolveTelegramChatId(store, phoneNumber, explicitChatId);
  const delivery = {
    id: id("delivery"),
    phoneNumber,
    chatId,
    status: "pending",
    messageText: `Avtobys login code for ${phoneNumber}: ${code}`,
    responseBody: "",
    error: "",
    createdAt: nowIso(),
  };

  if (!chatId) {
    delivery.status = "chat-not-configured";
    return delivery;
  }

  if (!TELEGRAM_BOT_TOKEN || typeof fetch !== "function") {
    delivery.status = TELEGRAM_BOT_TOKEN ? "fetch-unavailable" : "bot-not-configured";
    return delivery;
  }

  try {
    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: chatId,
          text: delivery.messageText,
        }),
      },
    );

    const responseText = await response.text();
    delivery.responseBody = responseText;
    delivery.status = response.ok ? "sent" : "failed";
    if (!response.ok) {
      delivery.error = `Telegram returned ${response.status}`;
    }
  } catch (error) {
    delivery.status = "failed";
    delivery.error = error instanceof Error ? error.message : "Unknown telegram error";
  }

  return delivery;
}

function serializeSummary(store) {
  return {
    cities: store.cities.length,
    tariffs: store.tariffs.length,
    buses: store.buses.length,
    tickets: store.tickets.length,
    users: store.users.length,
    sessions: store.sessions.length,
    walletTransactions: store.walletTransactions.length,
    supportMessages: store.supportMessages.length,
    telegramDeliveries: store.telegramDeliveries.length,
    totalWalletBalance: store.users.reduce(
      (sum, user) => sum + Number(user.wallet.balance || 0),
      0,
    ),
  };
}

function findUserFromRequest(store, req) {
  const auth = getSessionContext(req, store);
  if (auth) {
    return auth.user;
  }

  const phoneNumber =
    normalizePhoneNumber(req.query.phone) || normalizePhoneNumber(req.body.phoneNumber);
  return phoneNumber ? ensureUser(store, phoneNumber) : null;
}

app.get("/api/admin/summary", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json({
    ...serializeSummary(context.store),
    admin: {
      id: context.admin.id,
      name: context.admin.name,
    },
  });
});

app.get("/api/admin/users", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json(
    context.store.users.map((user) => ({
      ...serializeUser(user),
      wallet: serializeWallet(context.store, user),
    })),
  );
});

app.patch("/api/admin/users/:userId", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  const user = context.store.users.find((item) => item.id === req.params.userId);
  if (!user) {
    res.status(404).json({ message: "User not found" });
    return;
  }

  if (typeof req.body.fullName === "string" && req.body.fullName.trim()) {
    user.fullName = req.body.fullName.trim();
  }
  if (typeof req.body.cityName === "string") {
    user.cityName = req.body.cityName.trim();
  }
  if (typeof req.body.status === "string" && req.body.status.trim()) {
    user.status = req.body.status.trim();
  }
  if (typeof req.body.telegramChatId === "string") {
    user.telegramChatId = req.body.telegramChatId.trim();
  }
  if (req.body.balance !== undefined) {
    user.wallet.balance = Number(req.body.balance || 0);
  }
  user.updatedAt = nowIso();
  writeStore(context.store);
  res.json({
    ...serializeUser(user),
    wallet: serializeWallet(context.store, user),
  });
});

app.get("/api/admin/transactions", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json(context.store.walletTransactions.slice().reverse());
});

app.get("/api/admin/tickets", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json(
    context.store.tickets
      .slice()
      .reverse()
      .map((item) => withTicketRelations(context.store, item)),
  );
});

app.get("/api/admin/auth-codes", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json(context.store.authCodes.slice().reverse());
});

app.get("/api/admin/deliveries", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json(context.store.telegramDeliveries.slice().reverse());
});

app.get("/api/admin/support", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json(context.store.supportMessages.slice().reverse());
});

app.get("/api/admin/app-settings", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  res.json(context.store.appSettings);
});

app.patch("/api/admin/app-settings", (req, res) => {
  const context = requireAdminContext(req, res);
  if (!context) {
    return;
  }

  context.store.appSettings = {
    ...context.store.appSettings,
    ...(req.body || {}),
  };
  writeStore(context.store);
  res.json(context.store.appSettings);
});

app.get("*", (req, res) => {
  if (req.path.startsWith("/api/")) {
    res.status(404).json({ message: "Not found" });
    return;
  }
  res.sendFile(path.join(publicDir, "index.html"));
});

app.listen(PORT, () => {
  console.log(`Avtobys backend listening on http://localhost:${PORT}`);
});
