const cors = require("cors");
const crypto = require("crypto");
const dotenv = require("dotenv");
const express = require("express");
const path = require("path");

dotenv.config({ path: path.join(__dirname, ".env") });
if (process.env.AVTOBYS_MEMORY_DB === "1") {
  delete process.env.DATABASE_URL;
}

const {
  getClient,
  initDatabase,
  maybeOne,
  many,
  query,
  transaction,
} = require("./db");

const app = express();
const PORT = Number(process.env.PORT || 4000);
const publicDir = path.join(__dirname, "public");

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const AUTH_CODE_TTL_MS = 5 * 60 * 1000;
const TELEGRAM_BIND_TTL_MS = 15 * 60 * 1000;
const RIDE_TICKET_TTL_MS = 45 * 60 * 1000;
const DEFAULT_ADMIN_TOKEN = readEnvString("ADMIN_TOKEN", "avtobys-admin-dev");
const TELEGRAM_BOT_TOKEN = readEnvString("TELEGRAM_BOT_TOKEN");
const TELEGRAM_BOT_USERNAME = readEnvString("TELEGRAM_BOT_USERNAME")
  .replace(/^@+/, "")
  .trim();
const TELEGRAM_CHAT_MAP = safeJsonObject(process.env.TELEGRAM_CHAT_MAP_JSON);
const IS_PROD = process.env.NODE_ENV === "production";
const TELEGRAM_POLLING = readEnvString("TELEGRAM_POLLING").toLowerCase() === "true";

let telegramPollingOffset = 0;
let telegramPollingStarted = false;

app.use(cors());
app.use(express.json({ limit: "1mb" }));
app.use(express.static(publicDir));

function nowIso() {
  return new Date().toISOString();
}

function futureIso(ms) {
  return new Date(Date.now() + ms).toISOString();
}

function id(prefix) {
  return `${prefix}-${Date.now()}-${crypto.randomBytes(3).toString("hex")}`;
}

function readEnvString(name, fallback = "") {
  const value = process.env[name];
  if (typeof value !== "string") {
    return fallback;
  }
  const normalized = value.trim();
  return normalized || fallback;
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

function safeJsonArray(value, fallback = []) {
  try {
    const parsed = JSON.parse(value || "[]");
    return Array.isArray(parsed) ? parsed : fallback;
  } catch {
    return fallback;
  }
}

function safeJsonParse(value, fallback = {}) {
  try {
    return JSON.parse(value || "{}");
  } catch {
    return fallback;
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

function toNumber(value) {
  const amount = Number(value);
  return Number.isFinite(amount) ? amount : 0;
}

async function withClient(callback) {
  const client = await getClient();
  try {
    return await callback(client);
  } finally {
    client.release();
  }
}

async function getAppSettings(client) {
  const row = await maybeOne("SELECT * FROM app_settings WHERE singleton_id = 1", [], client);
  return mapAppSettings(row);
}

function mapAppSettings(row) {
  return {
    appName: row.app_name,
    supportPhone: row.support_phone,
    supportTelegram: row.support_telegram,
    accessRequestTelegram: row.access_request_telegram,
    loginDeliveryMode: row.login_delivery_mode,
    defaultLanguage: row.default_language,
    availableLanguages: safeJsonArray(row.available_languages_json, ["Русский", "Қазақша"]),
    shareUrl: row.share_url,
    currencySymbol: row.currency_symbol,
    newUserBonusBalance: toNumber(row.new_user_bonus_balance),
    minimumTopUpAmount: toNumber(row.minimum_top_up_amount),
    trialRideCount: Number(row.trial_ride_count || 0),
    maintenanceMode: Boolean(row.maintenance_mode),
  };
}

function serializePublicConfig(settings) {
  return {
    appName: settings.appName,
    supportPhone: settings.supportPhone,
    supportTelegram: settings.supportTelegram,
    accessRequestTelegram: settings.accessRequestTelegram,
    telegramBotUsername: TELEGRAM_BOT_USERNAME ? `@${TELEGRAM_BOT_USERNAME}` : "",
    loginDeliveryMode: settings.loginDeliveryMode,
    defaultLanguage: settings.defaultLanguage,
    availableLanguages: settings.availableLanguages,
    shareUrl: settings.shareUrl,
    currencySymbol: settings.currencySymbol,
    newUserBonusBalance: settings.newUserBonusBalance,
    minimumTopUpAmount: settings.minimumTopUpAmount,
    maintenanceMode: settings.maintenanceMode,
    debugAuthCodeVisible: !IS_PROD,
    trialRideCount: settings.trialRideCount,
  };
}

function serializeUser(row) {
  return {
    id: row.id,
    phoneNumber: row.phone_number,
    fullName: row.full_name,
    cityName: row.city_name,
    telegramChatId: row.telegram_chat_id,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    rideAccessEnabled: Boolean(row.ride_access_enabled),
    trialRidesRemaining: Number(row.trial_rides_remaining || 0),
    accessRequestedAt: row.access_requested_at,
    accessNote: row.access_note || "",
    settings: {
      language: row.settings_language,
      notificationsEnabled: Boolean(row.settings_notifications_enabled),
      appTheme: row.settings_app_theme,
    },
  };
}

async function loadWallet(client, userId) {
  const walletRow = await maybeOne(
    "SELECT * FROM wallets WHERE user_id = $1",
    [userId],
    client,
  );

  if (!walletRow) {
    return {
      balance: 0,
      cards: [],
      activeCardId: null,
      transactions: [],
    };
  }

  const [bankCards, transportCards, transactions] = await Promise.all([
    many("SELECT * FROM bank_cards WHERE user_id = $1 ORDER BY created_at DESC", [userId], client),
    many("SELECT * FROM transport_cards WHERE user_id = $1 ORDER BY created_at DESC", [userId], client),
    many(
      "SELECT * FROM wallet_transactions WHERE user_id = $1 ORDER BY created_at DESC",
      [userId],
      client,
    ),
  ]);

  const cards = [
    ...bankCards.map((item) => ({
      id: item.id,
      holderName: item.holder_name,
      number: item.number,
      cardType: "bank",
      addedAt: item.created_at,
    })),
    ...transportCards.map((item) => ({
      id: item.id,
      holderName: item.holder_name,
      number: item.number,
      cardType: "transport",
      balance: toNumber(item.balance),
      addedAt: item.created_at,
    })),
  ].sort((left, right) => {
    const leftTime = new Date(left.addedAt || 0).getTime();
    const rightTime = new Date(right.addedAt || 0).getTime();
    return rightTime - leftTime;
  });

  return {
    balance: toNumber(walletRow.balance),
    cards,
    activeCardId: walletRow.active_card_id || null,
    transactions: transactions.map((item) => ({
      id: item.id,
      type: item.type,
      source: item.source,
      description: item.description,
      amount: toNumber(item.amount),
      balanceBefore: toNumber(item.balance_before),
      balanceAfter: toNumber(item.balance_after),
      meta: safeJsonParse(item.meta_json),
      createdAt: item.created_at,
    })),
  };
}

async function createNotification(client, userId, title, body, type = "system") {
  await client.query(
    `
    INSERT INTO notifications (id, user_id, title, body, type, is_read, created_at)
    VALUES ($1, $2, $3, $4, $5, FALSE, CURRENT_TIMESTAMP)
    `,
    [id("notification"), userId, title, body, type],
  );
}

async function createWalletTransaction(client, userId, payload) {
  await client.query(
    `
    INSERT INTO wallet_transactions (
      id,
      user_id,
      type,
      source,
      description,
      amount,
      balance_before,
      balance_after,
      meta_json,
      created_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, CURRENT_TIMESTAMP)
    `,
    [
      id("txn"),
      userId,
      payload.type,
      payload.source,
      payload.description || "",
      payload.amount,
      payload.balanceBefore,
      payload.balanceAfter,
      JSON.stringify(payload.meta || {}),
    ],
  );
}

async function getCity(client, cityId) {
  return maybeOne("SELECT * FROM cities WHERE id = $1", [cityId], client);
}

async function getCityByName(client, cityName) {
  const normalized = `${cityName || ""}`.trim().toLowerCase();
  if (!normalized) {
    return null;
  }
  return maybeOne(
    "SELECT * FROM cities WHERE LOWER(TRIM(name)) = $1",
    [normalized],
    client,
  );
}

async function getTariff(client, tariffId) {
  return maybeOne("SELECT * FROM tariffs WHERE id = $1", [tariffId], client);
}

async function getBus(client, busId) {
  return maybeOne("SELECT * FROM buses WHERE id = $1", [busId], client);
}

async function fetchBuses(client, options = {}) {
  const conditions = [];
  const params = [];

  if (options.cityId) {
    params.push(options.cityId);
    conditions.push(`b.city_id = $${params.length}`);
  }
  if (options.number) {
    params.push(`%${normalizeTransportValue(options.number)}%`);
    conditions.push(
      `(UPPER(b.number) LIKE $${params.length} OR UPPER(b.validator_name) LIKE $${params.length})`,
    );
  }
  if (options.qrToken) {
    params.push(options.qrToken.trim());
    conditions.push(`(b.qr_token = $${params.length} OR UPPER(b.number) = UPPER($${params.length}))`);
  }
  if (options.bluetoothOnly) {
    conditions.push("b.bluetooth_enabled = TRUE");
  }

  const whereClause = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

  const rows = await many(
    `
    SELECT
      b.*,
      c.name AS city_name,
      t.name AS tariff_name,
      t.price AS tariff_price
    FROM buses b
    INNER JOIN cities c ON c.id = b.city_id
    INNER JOIN tariffs t ON t.id = b.tariff_id
    ${whereClause}
    ORDER BY c.name ASC, b.route_number ASC, b.number ASC
    `,
    params,
    client,
  );

  return rows.map(serializeBusRow);
}

function serializeBusRow(row) {
  return {
    id: row.id,
    cityId: row.city_id,
    cityName: row.city_name || "",
    number: row.number,
    validatorName: row.validator_name,
    routeNumber: row.route_number,
    tariffId: row.tariff_id,
    tariffName: row.tariff_name || "",
    price: toNumber(row.tariff_price),
    bluetoothEnabled: Boolean(row.bluetooth_enabled),
    qrToken: row.qr_token,
  };
}

function serializeTicketRow(row) {
  return {
    id: row.id,
    phoneNumber: row.phone_number,
    cityId: row.city_id,
    cityName: row.city_name,
    busId: row.bus_id,
    busNumber: row.bus_number,
    routeNumber: row.route_number,
    tariffName: row.tariff_name,
    amount: toNumber(row.amount),
    paymentMethod: row.payment_method,
    accessMode: row.access_mode,
    qrValue: row.qr_value,
    paidAt: row.paid_at,
    validUntil: row.valid_until,
    status: row.status,
  };
}

async function ensureUser(client, phoneNumber, payload = {}) {
  const normalizedPhone = normalizePhoneNumber(phoneNumber);
  let user = await maybeOne(
    "SELECT * FROM users WHERE phone_number = $1",
    [normalizedPhone],
    client,
  );

  if (!user) {
    const settings = await getAppSettings(client);
    const userId = id("user");
    await client.query(
      `
      INSERT INTO users (
        id,
        phone_number,
        full_name,
        city_name,
        telegram_chat_id,
        status,
        ride_access_enabled,
        trial_rides_remaining,
        access_note,
        settings_language,
        settings_notifications_enabled,
        settings_app_theme,
        created_at,
        updated_at
      ) VALUES ($1, $2, $3, $4, $5, 'active', FALSE, $6, '', $7, TRUE, 'light', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      `,
      [
        userId,
        normalizedPhone,
        payload.fullName || "Новый пользователь",
        payload.cityName || "",
        "",
        settings.trialRideCount,
        settings.defaultLanguage,
      ],
    );
    await client.query(
      `
      INSERT INTO wallets (id, user_id, balance, active_card_id, created_at, updated_at)
      VALUES ($1, $2, $3, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      `,
      [id("wallet"), userId, settings.newUserBonusBalance],
    );
    await createNotification(
      client,
      userId,
      "Добро пожаловать",
      "Аккаунт создан. Доступны 2 бесплатные пробные поездки.",
      "system",
    );
    user = await maybeOne("SELECT * FROM users WHERE id = $1", [userId], client);
  } else {
    const nextFullName =
      typeof payload.fullName === "string" && payload.fullName.trim()
        ? payload.fullName.trim()
        : user.full_name;
    const nextCityName =
      Object.prototype.hasOwnProperty.call(payload, "cityName")
        ? `${payload.cityName || ""}`.trim()
        : user.city_name;
    await client.query(
      `
      UPDATE users
      SET full_name = $2,
          city_name = $3,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
      `,
      [user.id, nextFullName, nextCityName],
    );
    user = await maybeOne("SELECT * FROM users WHERE id = $1", [user.id], client);
  }

  return user;
}

async function issueSession(client, userId) {
  const session = {
    id: id("session"),
    token: crypto.randomBytes(24).toString("hex"),
    userId,
    createdAt: nowIso(),
    lastSeenAt: nowIso(),
    expiresAt: futureIso(SESSION_TTL_MS),
  };

  await client.query(
    `
    INSERT INTO sessions (id, token, user_id, created_at, last_seen_at, expires_at)
    VALUES ($1, $2, $3, $4, $5, $6)
    `,
    [
      session.id,
      session.token,
      session.userId,
      session.createdAt,
      session.lastSeenAt,
      session.expiresAt,
    ],
  );

  return session;
}

function parseAuthToken(req) {
  const authorization = req.headers.authorization;
  if (typeof authorization === "string" && authorization.startsWith("Bearer ")) {
    return authorization.slice("Bearer ".length).trim();
  }
  const headerToken = req.headers["x-session-token"];
  return typeof headerToken === "string" ? headerToken.trim() : "";
}

async function getSessionContext(req, client) {
  const token = parseAuthToken(req);
  if (!token) {
    return null;
  }

  const currentTimestamp = nowIso();
  await client.query("DELETE FROM sessions WHERE expires_at <= $1", [currentTimestamp]);

  const row = await maybeOne(
    `
    SELECT
      s.id AS session_id,
      s.token AS session_token,
      s.user_id AS session_user_id,
      s.created_at AS session_created_at,
      s.last_seen_at AS session_last_seen_at,
      s.expires_at AS session_expires_at,
      u.*
    FROM sessions s
    INNER JOIN users u ON u.id = s.user_id
    WHERE s.token = $1
      AND s.expires_at > $2
    `,
    [token, currentTimestamp],
    client,
  );

  if (!row) {
    return null;
  }

  await client.query(
    "UPDATE sessions SET last_seen_at = CURRENT_TIMESTAMP WHERE id = $1",
    [row.session_id],
  );

  return {
    session: {
      id: row.session_id,
      token: row.session_token,
      userId: row.session_user_id,
      createdAt: row.session_created_at,
      lastSeenAt: row.session_last_seen_at,
      expiresAt: row.session_expires_at,
    },
    user: row,
  };
}

async function requireUserContext(req, res, client) {
  const context = await getSessionContext(req, client);
  if (!context) {
    res.status(401).json({ message: "Unauthorized" });
    return null;
  }
  return context;
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

async function requireAdminContext(req, res, client) {
  const token = getAdminToken(req);
  if (!token) {
    res.status(401).json({ message: "Admin token required" });
    return null;
  }

  const admin = await maybeOne("SELECT * FROM admins WHERE token = $1", [token], client);
  if (!admin) {
    res.status(401).json({ message: "Admin token required" });
    return null;
  }

  return { admin };
}

async function resolveTelegramChatId(client, phoneNumber) {
  const normalizedPhone = normalizePhoneNumber(phoneNumber);
  const user = await maybeOne(
    "SELECT telegram_chat_id FROM users WHERE phone_number = $1",
    [normalizedPhone],
    client,
  );
  const boundChatId = `${user?.telegram_chat_id || ""}`.trim();
  if (boundChatId) {
    return boundChatId;
  }
  const mappedChatId = `${TELEGRAM_CHAT_MAP[normalizedPhone] || ""}`.trim();
  if (mappedChatId) {
    return mappedChatId;
  }
  return "";
}

function buildTelegramStartCommand(token) {
  return `/start ${token}`;
}

function buildTelegramDeepLink(token) {
  return TELEGRAM_BOT_USERNAME
    ? `https://t.me/${TELEGRAM_BOT_USERNAME}?start=${encodeURIComponent(token)}`
    : "";
}

function serializeTelegramBindToken(bindToken) {
  const token = bindToken.token || "";
  const botUsername = TELEGRAM_BOT_USERNAME ? `@${TELEGRAM_BOT_USERNAME}` : "";
  const command = buildTelegramStartCommand(token);
  return {
    token,
    botUsername,
    deepLink: buildTelegramDeepLink(token),
    command,
    expiresAt: bindToken.expires_at || bindToken.expiresAt || futureIso(TELEGRAM_BIND_TTL_MS),
    instructions: botUsername
      ? `Open ${botUsername} and send ${command}.`
      : `Open your Telegram bot and send ${command}.`,
  };
}

async function createTelegramBindToken(client, user) {
  const bindToken = {
    id: id("bind"),
    userId: user.id,
    phoneNumber: user.phone_number,
    token: crypto.randomBytes(12).toString("hex"),
    status: "pending",
    chatId: "",
    createdAt: nowIso(),
    expiresAt: futureIso(TELEGRAM_BIND_TTL_MS),
  };

  await client.query(
    "UPDATE telegram_bind_tokens SET status = 'expired' WHERE user_id = $1 AND status = 'pending'",
    [user.id],
  );
  await client.query(
    `
    INSERT INTO telegram_bind_tokens (
      id,
      user_id,
      phone_number,
      token,
      status,
      chat_id,
      created_at,
      expires_at,
      used_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NULL)
    `,
    [
      bindToken.id,
      bindToken.userId,
      bindToken.phoneNumber,
      bindToken.token,
      bindToken.status,
      bindToken.chatId,
      bindToken.createdAt,
      bindToken.expiresAt,
    ],
  );

  return serializeTelegramBindToken(bindToken);
}

async function getTelegramBindStatus(client, phoneNumber) {
  const normalizedPhone = normalizePhoneNumber(phoneNumber);
  if (!normalizedPhone) {
    return {
      phoneNumber: "",
      isBound: false,
      telegramChatId: "",
      botUsername: TELEGRAM_BOT_USERNAME ? `@${TELEGRAM_BOT_USERNAME}` : "",
    };
  }

  const user = await maybeOne(
    "SELECT phone_number, telegram_chat_id FROM users WHERE phone_number = $1",
    [normalizedPhone],
    client,
  );

  return {
    phoneNumber: normalizedPhone,
    isBound: Boolean(user?.telegram_chat_id),
    telegramChatId: user?.telegram_chat_id || "",
    botUsername: TELEGRAM_BOT_USERNAME ? `@${TELEGRAM_BOT_USERNAME}` : "",
  };
}

function parseTelegramStartToken(text) {
  const match = `${text || ""}`.trim().match(/^\/start(?:@\w+)?(?:\s+(.+))?$/i);
  return match?.[1]?.trim() || "";
}

async function sendTelegramMessage(chatId, text) {
  if (!chatId) {
    return {
      status: "chat-not-configured",
      responseBody: "",
      error: "Telegram chat is not configured",
    };
  }

  if (!TELEGRAM_BOT_TOKEN || typeof fetch !== "function") {
    return {
      status: TELEGRAM_BOT_TOKEN ? "fetch-unavailable" : "bot-not-configured",
      responseBody: "",
      error: "Telegram bot is not configured",
    };
  }

  try {
    const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        disable_web_page_preview: true,
      }),
    });
    const responseText = await response.text();
    return response.ok
      ? {
          status: "sent",
          responseBody: responseText,
          error: "",
        }
      : {
          status: "failed",
          responseBody: responseText,
          error: `Telegram returned ${response.status}`,
        };
  } catch (error) {
    return {
      status: "failed",
      responseBody: "",
      error: error instanceof Error ? error.message : "Unknown telegram error",
    };
  }
}

async function sendTelegramCode(client, settings, phoneNumber, code) {
  const chatId = await resolveTelegramChatId(client, phoneNumber);
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
    delivery.error = `Bind Telegram or write to ${settings.accessRequestTelegram}`;
    return delivery;
  }

  const messageResult = await sendTelegramMessage(chatId, delivery.messageText);
  delivery.status = messageResult.status;
  delivery.responseBody = messageResult.responseBody;
  delivery.error = messageResult.error;

  return delivery;
}

async function storeTelegramDelivery(client, delivery) {
  await client.query(
    `
    INSERT INTO telegram_deliveries (
      id,
      phone_number,
      chat_id,
      status,
      message_text,
      response_body,
      error,
      created_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    `,
    [
      delivery.id,
      delivery.phoneNumber,
      delivery.chatId || "",
      delivery.status,
      delivery.messageText,
      delivery.responseBody || "",
      delivery.error || "",
      delivery.createdAt,
    ],
  );
}

async function handleTelegramUpdate(update) {
  const message = update?.message || update?.edited_message;
  const chatId = message?.chat?.id != null ? `${message.chat.id}` : "";
  const text = typeof message?.text === "string" ? message.text.trim() : "";
  const token = parseTelegramStartToken(text);

  if (!chatId || !text.startsWith("/start")) {
    return { ok: true, ignored: true };
  }

  const result = await transaction(async (client) => {
    if (!token) {
      return {
        phoneNumber: "",
        replyText: "Open Avtobys, request a Telegram bind link, then send the /start token here.",
      };
    }

    const bindToken = await maybeOne(
      `
      SELECT *
      FROM telegram_bind_tokens
      WHERE token = $1
        AND status = 'pending'
        AND expires_at > $2
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [token, nowIso()],
      client,
    );

    if (!bindToken) {
      return {
        phoneNumber: "",
        replyText: "Bind token is invalid or expired. Request a new Telegram link in Avtobys.",
      };
    }

    const user = await maybeOne("SELECT * FROM users WHERE id = $1", [bindToken.user_id], client);
    if (!user) {
      return {
        phoneNumber: bindToken.phone_number || "",
        replyText: "Account was not found. Request a new Telegram link in Avtobys.",
      };
    }

    const existingOwner = await maybeOne(
      `
      SELECT id, phone_number
      FROM users
      WHERE telegram_chat_id = $1
        AND id <> $2
      LIMIT 1
      `,
      [chatId, user.id],
      client,
    );
    if (existingOwner) {
      await client.query(
        `
        UPDATE telegram_bind_tokens
        SET status = 'expired',
            chat_id = $2,
            used_at = $3
        WHERE id = $1
        `,
        [bindToken.id, chatId, nowIso()],
      );
      return {
        phoneNumber: bindToken.phone_number || "",
        replyText: `This Telegram chat is already connected to ${existingOwner.phone_number}. Use that phone number to sign in.`,
      };
    }

    await client.query(
      `
      UPDATE users
      SET telegram_chat_id = $2,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
      `,
      [user.id, chatId],
    );
    await client.query(
      `
      UPDATE telegram_bind_tokens
      SET status = 'used',
          chat_id = $2,
          used_at = $3
      WHERE id = $1
      `,
      [bindToken.id, chatId, nowIso()],
    );
    await client.query(
      `
      UPDATE telegram_bind_tokens
      SET status = 'expired'
      WHERE user_id = $1
        AND status = 'pending'
        AND id <> $2
      `,
      [user.id, bindToken.id],
    );
    await createNotification(
      client,
      user.id,
      "Telegram connected",
      "Login codes will now be delivered to your Telegram chat.",
      "system",
    );
    console.log(`Telegram chat bound for ${bindToken.phone_number || user.phone_number} -> ${chatId}`);

    return {
      phoneNumber: bindToken.phone_number || user.phone_number || "",
      replyText: `Telegram is connected to ${bindToken.phone_number || user.phone_number}. New login codes will arrive in this chat.`,
    };
  });

  const delivery = await sendTelegramMessage(chatId, result.replyText);
  await withClient((client) =>
    storeTelegramDelivery(client, {
      id: id("delivery"),
      phoneNumber: result.phoneNumber,
      chatId,
      status: delivery.status,
      messageText: result.replyText,
      responseBody: delivery.responseBody || "",
      error: delivery.error || "",
      createdAt: nowIso(),
    }),
  );

  return { ok: true, ignored: false, status: delivery.status };
}

async function pollTelegramUpdatesOnce() {
  if (!TELEGRAM_BOT_TOKEN || typeof fetch !== "function") {
    return;
  }

  try {
    const query = new URLSearchParams({
      timeout: "25",
    });
    if (telegramPollingOffset > 0) {
      query.set("offset", `${telegramPollingOffset}`);
    }

    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?${query.toString()}`,
    );
    const responseText = await response.text();
    if (!response.ok) {
      console.error("Telegram polling HTTP error", response.status, responseText);
      return;
    }

    const payload = safeJsonParse(responseText, {});
    const updates = Array.isArray(payload.result) ? payload.result : [];
    for (const update of updates) {
      if (typeof update?.update_id === "number") {
        telegramPollingOffset = Math.max(telegramPollingOffset, update.update_id + 1);
      }
      await handleTelegramUpdate(update);
    }
  } catch (error) {
    console.error("Telegram polling failed", error);
  }
}

function scheduleTelegramPolling(delayMs = 0) {
  if (!telegramPollingStarted) {
    return;
  }

  setTimeout(async () => {
    if (!telegramPollingStarted) {
      return;
    }
    await pollTelegramUpdatesOnce();
    scheduleTelegramPolling(1000);
  }, delayMs);
}

function startTelegramPolling() {
  if (!TELEGRAM_POLLING || telegramPollingStarted) {
    return;
  }

  if (!TELEGRAM_BOT_TOKEN || typeof fetch !== "function") {
    console.warn("Telegram polling requested but bot token/fetch is unavailable.");
    return;
  }

  telegramPollingStarted = true;
  console.log("Telegram polling enabled. Webhook is not required.");
  scheduleTelegramPolling();
}

async function getSummary(client) {
  const [
    cities,
    tariffs,
    buses,
    tickets,
    users,
    sessions,
    walletTransactions,
    supportMessages,
    telegramDeliveries,
    totalWalletBalance,
    usersWithRideAccess,
    pendingAccessRequests,
  ] = await Promise.all([
    maybeOne("SELECT COUNT(*)::int AS count FROM cities", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM tariffs", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM buses", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM tickets", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM users", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM sessions", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM wallet_transactions", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM support_messages", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM telegram_deliveries", [], client),
    maybeOne("SELECT COALESCE(SUM(balance), 0)::numeric AS total FROM wallets", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM users WHERE ride_access_enabled = TRUE", [], client),
    maybeOne("SELECT COUNT(*)::int AS count FROM users WHERE access_requested_at IS NOT NULL", [], client),
  ]);

  return {
    cities: cities?.count || 0,
    tariffs: tariffs?.count || 0,
    buses: buses?.count || 0,
    tickets: tickets?.count || 0,
    users: users?.count || 0,
    sessions: sessions?.count || 0,
    walletTransactions: walletTransactions?.count || 0,
    supportMessages: supportMessages?.count || 0,
    telegramDeliveries: telegramDeliveries?.count || 0,
    totalWalletBalance: toNumber(totalWalletBalance?.total),
    usersWithRideAccess: usersWithRideAccess?.count || 0,
    pendingAccessRequests: pendingAccessRequests?.count || 0,
  };
}

async function findUserFromRequest(client, req) {
  const auth = await getSessionContext(req, client);
  if (auth) {
    return auth.user;
  }

  const phoneNumber =
    normalizePhoneNumber(req.query.phone) || normalizePhoneNumber(req.body.phoneNumber);

  if (!phoneNumber) {
    return null;
  }

  return ensureUser(client, phoneNumber);
}

async function fetchTicketsForUser(client, options = {}) {
  const conditions = [];
  const params = [];

  if (options.userId) {
    params.push(options.userId);
    conditions.push(`user_id = $${params.length}`);
  }
  if (options.phoneNumber) {
    params.push(normalizePhoneNumber(options.phoneNumber));
    conditions.push(`phone_number = $${params.length}`);
  }

  const whereClause = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const rows = await many(
    `SELECT * FROM tickets ${whereClause} ORDER BY paid_at DESC`,
    params,
    client,
  );
  return rows.map(serializeTicketRow);
}

app.get("/api/health", async (_req, res) => {
  try {
    const summary = await withClient((client) => getSummary(client));
    res.json({
      ok: true,
      now: nowIso(),
      ...summary,
    });
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Health failed" });
  }
});

app.get("/api/config/public", async (_req, res) => {
  try {
    const config = await withClient(async (client) => serializePublicConfig(await getAppSettings(client)));
    res.json(config);
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Config failed" });
  }
});

app.get("/api/summary", async (_req, res) => {
  try {
    res.json(await withClient((client) => getSummary(client)));
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Summary failed" });
  }
});

app.post("/api/auth/request-code", async (req, res) => {
  try {
    const phoneNumber = normalizePhoneNumber(req.body.phoneNumber);
    if (!phoneNumber) {
      res.status(400).json({ message: "Phone number is required" });
      return;
    }

    const result = await transaction(async (client) => {
      const settings = await getAppSettings(client);
      const user = await ensureUser(client, phoneNumber, {
        fullName: req.body.fullName,
        cityName: req.body.cityName,
      });
      const telegramBind = !user.telegram_chat_id
        ? await createTelegramBindToken(client, user)
        : null;

      const code = createLoginCode();
      const delivery = await sendTelegramCode(
        client,
        settings,
        phoneNumber,
        code,
      );

      await client.query(
        "UPDATE auth_codes SET status = 'expired' WHERE phone_number = $1 AND status = 'pending'",
        [phoneNumber],
      );
      await storeTelegramDelivery(client, delivery);
      await client.query(
        `
        INSERT INTO auth_codes (
          id,
          phone_number,
          code,
          status,
          attempts,
          created_at,
          expires_at,
          delivery_id,
          support_telegram
        ) VALUES ($1, $2, $3, 'pending', 0, $4, $5, $6, $7)
        `,
        [
          id("auth"),
          phoneNumber,
          code,
          nowIso(),
          futureIso(AUTH_CODE_TTL_MS),
          delivery.id,
          settings.accessRequestTelegram,
        ],
      );

      return {
        ok: true,
        phoneNumber,
        expiresAt: futureIso(AUTH_CODE_TTL_MS),
        delivery: {
          status: delivery.status,
          chatId: delivery.chatId || undefined,
          error: delivery.error || undefined,
        },
        telegramBind,
        debugCode: IS_PROD ? undefined : code,
        supportTelegram: settings.accessRequestTelegram,
      };
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({
      message: error instanceof Error ? error.message : "Failed to request code",
    });
  }
});

app.post("/api/telegram/bind-token", async (req, res) => {
  try {
    const payload = await transaction(async (client) => {
      const sessionContext = await getSessionContext(req, client);
      let user = sessionContext?.user || null;
      if (!user) {
        const phoneNumber = normalizePhoneNumber(req.body.phoneNumber);
        if (!phoneNumber) {
          throw new Error("Phone number is required");
        }
        user = await ensureUser(client, phoneNumber, {
          fullName: req.body.fullName,
          cityName: req.body.cityName,
        });
      }
      const settings = await getAppSettings(client);
      return {
        ...await createTelegramBindToken(client, user),
        supportTelegram: settings.accessRequestTelegram,
      };
    });

    res.json(payload);
  } catch (error) {
    res.status(400).json({
      message: error instanceof Error ? error.message : "Failed to create Telegram bind token",
    });
  }
});

app.get("/api/telegram/bind-status", async (req, res) => {
  try {
    const payload = await withClient(async (client) => {
      const sessionContext = await getSessionContext(req, client);
      const phoneNumber = sessionContext?.user?.phone_number || normalizePhoneNumber(req.query.phone);
      return getTelegramBindStatus(client, phoneNumber);
    });

    res.json(payload);
  } catch (error) {
    res.status(400).json({
      message: error instanceof Error ? error.message : "Failed to load Telegram bind status",
    });
  }
});

app.post("/api/telegram/webhook", async (req, res) => {
  try {
    await handleTelegramUpdate(req.body);
    res.json({ ok: true });
  } catch (error) {
    console.error("Telegram webhook failed", error);
    res.json({ ok: true });
  }
});

app.post("/api/auth/verify-code", async (req, res) => {
  try {
    const phoneNumber = normalizePhoneNumber(req.body.phoneNumber);
    const code = `${req.body.code || ""}`.trim();
    if (!phoneNumber || !code) {
      res.status(400).json({ message: "Phone number and code are required" });
      return;
    }

    const payload = await transaction(async (client) => {
      const currentTimestamp = nowIso();
      const authCode = await maybeOne(
        `
        SELECT *
        FROM auth_codes
        WHERE phone_number = $1
          AND code = $2
          AND status = 'pending'
          AND expires_at > $3
        ORDER BY created_at DESC
        LIMIT 1
        `,
        [phoneNumber, code, currentTimestamp],
        client,
      );

      if (!authCode) {
        throw new Error("Invalid or expired code");
      }

      await client.query("UPDATE auth_codes SET status = 'used' WHERE id = $1", [authCode.id]);

      const user = await ensureUser(client, phoneNumber, {
        cityName: req.body.cityName,
        fullName: req.body.fullName,
      });
      const session = await issueSession(client, user.id);
      const settings = await getAppSettings(client);
      const wallet = await loadWallet(client, user.id);

      return {
        token: session.token,
        user: serializeUser(user),
        wallet,
        config: serializePublicConfig(settings),
      };
    });

    res.json(payload);
  } catch (error) {
    res.status(400).json({
      message: error instanceof Error ? error.message : "Failed to verify code",
    });
  }
});

app.get("/api/auth/debug-last-code", async (req, res) => {
  if (IS_PROD) {
    res.status(404).json({ message: "Not available" });
    return;
  }

  try {
    const phoneNumber = normalizePhoneNumber(req.query.phone);
    const latest = await withClient((client) =>
      maybeOne(
        `
        SELECT * FROM auth_codes
        WHERE phone_number = $1
        ORDER BY created_at DESC
        LIMIT 1
        `,
        [phoneNumber],
        client,
      ),
    );

    res.json({
      phoneNumber,
      code: latest?.code || null,
      status: latest?.status || null,
      expiresAt: latest?.expires_at || null,
    });
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Debug failed" });
  }
});

app.get("/api/auth/me", async (req, res) => {
  try {
    const result = await withClient(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }
      const settings = await getAppSettings(client);
      const wallet = await loadWallet(client, context.user.id);
      return {
        token: parseAuthToken(req),
        user: serializeUser(context.user),
        wallet,
        config: serializePublicConfig(settings),
      };
    });

    if (result) {
      res.json(result);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Session failed" });
  }
});

app.post("/api/auth/logout", async (req, res) => {
  try {
    const token = parseAuthToken(req);
    if (token) {
      await query("DELETE FROM sessions WHERE token = $1", [token]);
    }
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Logout failed" });
  }
});

app.get("/api/me", async (req, res) => {
  try {
    const user = await withClient(async (client) => {
      const context = await requireUserContext(req, res, client);
      return context ? serializeUser(context.user) : null;
    });
    if (user) {
      res.json(user);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Profile failed" });
  }
});

app.patch("/api/me", async (req, res) => {
  try {
    const payload = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      const user = await ensureUser(client, context.user.phone_number, {
        fullName: req.body.fullName,
        cityName: req.body.cityName,
      });

      return serializeUser(user);
    });

    if (payload) {
      res.json(payload);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Update failed" });
  }
});

app.get("/api/settings", async (req, res) => {
  try {
    const payload = await withClient(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }
      const settings = await getAppSettings(client);
      return {
        ...serializeUser(context.user).settings,
        cityName: context.user.city_name,
        supportPhone: settings.supportPhone,
        supportTelegram: settings.supportTelegram,
        accessRequestTelegram: settings.accessRequestTelegram,
        rideAccessEnabled: Boolean(context.user.ride_access_enabled),
        trialRidesRemaining: Number(context.user.trial_rides_remaining || 0),
        accessRequestedAt: context.user.access_requested_at,
      };
    });

    if (payload) {
      res.json(payload);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Settings failed" });
  }
});

app.patch("/api/settings", async (req, res) => {
  try {
    const payload = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      const user = context.user;
      const language =
        typeof req.body.language === "string" && req.body.language.trim()
          ? req.body.language.trim()
          : user.settings_language;
      const notificationsEnabled =
        typeof req.body.notificationsEnabled === "boolean"
          ? req.body.notificationsEnabled
          : user.settings_notifications_enabled;
      const appTheme =
        typeof req.body.appTheme === "string" && req.body.appTheme.trim()
          ? req.body.appTheme.trim()
          : user.settings_app_theme;
      const cityName =
        typeof req.body.cityName === "string" ? req.body.cityName.trim() : user.city_name;

      await client.query(
        `
        UPDATE users
        SET settings_language = $2,
            settings_notifications_enabled = $3,
            settings_app_theme = $4,
            city_name = $5,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
        `,
        [user.id, language, notificationsEnabled, appTheme, cityName],
      );

      const nextUser = await maybeOne("SELECT * FROM users WHERE id = $1", [user.id], client);
      const settings = await getAppSettings(client);

      return {
        ...serializeUser(nextUser).settings,
        cityName: nextUser.city_name,
        supportPhone: settings.supportPhone,
        supportTelegram: settings.supportTelegram,
        accessRequestTelegram: settings.accessRequestTelegram,
        rideAccessEnabled: Boolean(nextUser.ride_access_enabled),
        trialRidesRemaining: Number(nextUser.trial_rides_remaining || 0),
        accessRequestedAt: nextUser.access_requested_at,
      };
    });

    if (payload) {
      res.json(payload);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Settings update failed" });
  }
});

app.post("/api/access/request", async (req, res) => {
  try {
    const result = await transaction(async (client) => {
      const context = await getSessionContext(req, client);
      const user =
        context?.user ||
        (req.body.phoneNumber
          ? await ensureUser(client, normalizePhoneNumber(req.body.phoneNumber), {
              cityName: req.body.cityName,
            })
          : null);

      if (!user) {
        throw new Error("Authentication or phone number is required");
      }

      const settings = await getAppSettings(client);
      await client.query(
        `
        UPDATE users
        SET access_requested_at = CURRENT_TIMESTAMP,
            access_note = $2,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
        `,
        [user.id, `Write to ${settings.accessRequestTelegram} to enable bus payments.`],
      );
      await client.query(
        `
        INSERT INTO support_messages (
          id,
          user_id,
          phone_number,
          subject,
          message,
          status,
          kind,
          created_at
        ) VALUES ($1, $2, $3, $4, $5, 'new', 'access', CURRENT_TIMESTAMP)
        `,
        [
          id("support"),
          user.id,
          user.phone_number,
          "Ride access request",
          `User requested ride access. Telegram: ${settings.accessRequestTelegram}`,
        ],
      );
      await createNotification(
        client,
        user.id,
        "Запрос доступа отправлен",
        `Для активации напишите в Telegram ${settings.accessRequestTelegram}.`,
        "access",
      );

      return {
        ok: true,
        telegramUsername: settings.accessRequestTelegram,
        message: `Write to ${settings.accessRequestTelegram} for access activation`,
      };
    });

    res.json(result);
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Access request failed" });
  }
});

app.get("/api/wallet", async (req, res) => {
  try {
    const wallet = await withClient(async (client) => {
      const context = await requireUserContext(req, res, client);
      return context ? loadWallet(client, context.user.id) : null;
    });
    if (wallet) {
      res.json(wallet);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Wallet failed" });
  }
});

app.get("/api/wallet/cards", async (req, res) => {
  try {
    const cards = await withClient(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }
      const wallet = await loadWallet(client, context.user.id);
      return wallet.cards;
    });

    if (cards) {
      res.json(cards);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Cards failed" });
  }
});

app.post("/api/wallet/cards", async (req, res) => {
  try {
    const card = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      const holderName = `${req.body.holderName || ""}`.trim();
      const number = normalizeCardNumber(req.body.number);
      const cardType = req.body.cardType === "transport" ? "transport" : "bank";
      const minLength = cardType === "transport" ? 6 : 12;

      if (!holderName || number.length < minLength) {
        throw new Error("Card payload is invalid");
      }

      const nextId = id(cardType === "transport" ? "transport-card" : "bank-card");
      if (cardType === "transport") {
        await client.query(
          `
          INSERT INTO transport_cards (
            id,
            user_id,
            holder_name,
            number,
            balance,
            created_at,
            updated_at
          ) VALUES ($1, $2, $3, $4, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          `,
          [nextId, context.user.id, holderName, number],
        );
      } else {
        await client.query(
          `
          INSERT INTO bank_cards (
            id,
            user_id,
            holder_name,
            number,
            created_at,
            updated_at
          ) VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          `,
          [nextId, context.user.id, holderName, number],
        );
      }

      await client.query(
        `
        UPDATE wallets
        SET active_card_id = $2,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $1
        `,
        [context.user.id, nextId],
      );

      const wallet = await loadWallet(client, context.user.id);
      return wallet.cards.find((item) => item.id === nextId) || null;
    });

    if (card) {
      res.status(201).json(card);
    }
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Card create failed" });
  }
});

app.patch("/api/wallet/cards/:cardId", async (req, res) => {
  try {
    const updated = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      const bankCard = await maybeOne(
        "SELECT * FROM bank_cards WHERE id = $1 AND user_id = $2",
        [req.params.cardId, context.user.id],
        client,
      );
      const transportCard = bankCard
        ? null
        : await maybeOne(
            "SELECT * FROM transport_cards WHERE id = $1 AND user_id = $2",
            [req.params.cardId, context.user.id],
            client,
          );

      const current = bankCard || transportCard;
      if (!current) {
        throw new Error("Card not found");
      }

      const nextHolderName =
        typeof req.body.holderName === "string" && req.body.holderName.trim()
          ? req.body.holderName.trim()
          : current.holder_name;
      const nextNumber =
        typeof req.body.number === "string" && req.body.number.trim()
          ? normalizeCardNumber(req.body.number)
          : current.number;

      if (bankCard) {
        await client.query(
          `
          UPDATE bank_cards
          SET holder_name = $2,
              number = $3,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = $1
          `,
          [bankCard.id, nextHolderName, nextNumber],
        );
      } else {
        await client.query(
          `
          UPDATE transport_cards
          SET holder_name = $2,
              number = $3,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = $1
          `,
          [transportCard.id, nextHolderName, nextNumber],
        );
      }

      const wallet = await loadWallet(client, context.user.id);
      return wallet.cards.find((item) => item.id === req.params.cardId) || null;
    });

    if (updated) {
      res.json(updated);
    }
  } catch (error) {
    res.status(404).json({ message: error instanceof Error ? error.message : "Card update failed" });
  }
});

app.delete("/api/wallet/cards/:cardId", async (req, res) => {
  try {
    const payload = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      await client.query("DELETE FROM bank_cards WHERE id = $1 AND user_id = $2", [req.params.cardId, context.user.id]);
      await client.query("DELETE FROM transport_cards WHERE id = $1 AND user_id = $2", [req.params.cardId, context.user.id]);

      const walletRow = await maybeOne("SELECT * FROM wallets WHERE user_id = $1", [context.user.id], client);
      let activeCardId = walletRow?.active_card_id || null;
      if (activeCardId === req.params.cardId) {
        const wallet = await loadWallet(client, context.user.id);
        activeCardId = wallet.cards[0]?.id || null;
        await client.query(
          `
          UPDATE wallets
          SET active_card_id = $2,
              updated_at = CURRENT_TIMESTAMP
          WHERE user_id = $1
          `,
          [context.user.id, activeCardId],
        );
      }

      return { ok: true, activeCardId };
    });

    if (payload) {
      res.json(payload);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Card delete failed" });
  }
});

app.post("/api/wallet/cards/:cardId/activate", async (req, res) => {
  try {
    const payload = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      const exists = await maybeOne(
        `
        SELECT id
        FROM (
          SELECT id FROM bank_cards WHERE user_id = $2
          UNION ALL
          SELECT id FROM transport_cards WHERE user_id = $2
        ) cards
        WHERE id = $1
        `,
        [req.params.cardId, context.user.id],
        client,
      );

      if (!exists) {
        throw new Error("Card not found");
      }

      await client.query(
        `
        UPDATE wallets
        SET active_card_id = $2,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $1
        `,
        [context.user.id, req.params.cardId],
      );

      return { ok: true, activeCardId: req.params.cardId };
    });

    if (payload) {
      res.json(payload);
    }
  } catch (error) {
    res.status(404).json({ message: error instanceof Error ? error.message : "Card activate failed" });
  }
});

app.post("/api/wallet/top-up", async (req, res) => {
  try {
    const wallet = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      const settings = await getAppSettings(client);
      const amount = parsePositiveAmount(req.body.amount);
      if (!amount || amount < settings.minimumTopUpAmount) {
        throw new Error(`Minimum top-up amount is ${settings.minimumTopUpAmount}`);
      }

      const targetType = req.body.targetType === "transport" ? "transport" : "wallet";
      const walletRow = await maybeOne("SELECT * FROM wallets WHERE user_id = $1", [context.user.id], client);

      if (targetType === "transport") {
        const targetCardId = req.body.transportCardId || req.body.cardId || walletRow?.active_card_id;
        const card = await maybeOne(
          "SELECT * FROM transport_cards WHERE id = $1 AND user_id = $2",
          [targetCardId, context.user.id],
          client,
        );
        if (!card) {
          throw new Error("Transport card not found");
        }

        const before = toNumber(card.balance);
        const after = before + amount;
        await client.query(
          `
          UPDATE transport_cards
          SET balance = $2,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = $1
          `,
          [card.id, after],
        );
        await createWalletTransaction(client, context.user.id, {
          type: "transport-topup",
          source: "transport-card",
          description: `Transport card top-up ${card.number}`,
          amount,
          balanceBefore: before,
          balanceAfter: after,
          meta: {
            cardId: card.id,
            targetType: "transport",
          },
        });
      } else {
        const before = toNumber(walletRow?.balance);
        const after = before + amount;
        await client.query(
          `
          UPDATE wallets
          SET balance = $2,
              updated_at = CURRENT_TIMESTAMP
          WHERE user_id = $1
          `,
          [context.user.id, after],
        );
        await createWalletTransaction(client, context.user.id, {
          type: "topup",
          source: req.body.source || "manual",
          description: req.body.description || "Wallet top-up",
          amount,
          balanceBefore: before,
          balanceAfter: after,
          meta: {
            cardId: req.body.cardId || walletRow?.active_card_id || null,
            targetType: "wallet",
          },
        });
      }

      return loadWallet(client, context.user.id);
    });

    if (wallet) {
      res.json(wallet);
    }
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Top-up failed" });
  }
});

app.get("/api/wallet/transactions", async (req, res) => {
  try {
    const transactions = await withClient(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }
      const wallet = await loadWallet(client, context.user.id);
      return wallet.transactions;
    });

    if (transactions) {
      res.json(transactions);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Transactions failed" });
  }
});

app.get("/api/cities", async (_req, res) => {
  try {
    const rows = await query("SELECT id, name FROM cities ORDER BY name ASC");
    res.json(rows.rows.map((item) => ({ id: item.id, name: item.name })));
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Cities failed" });
  }
});

app.post("/api/cities", async (req, res) => {
  try {
    const name = `${req.body.name || ""}`.trim();
    if (!name) {
      res.status(400).json({ message: "City name is required" });
      return;
    }
    const city = await transaction(async (client) => {
      const nextId = req.body.id || id("city");
      await client.query("INSERT INTO cities (id, name) VALUES ($1, $2)", [nextId, name]);
      return { id: nextId, name };
    });
    res.status(201).json(city);
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "City create failed" });
  }
});

app.patch("/api/cities/:cityId", async (req, res) => {
  try {
    const name = `${req.body.name || ""}`.trim();
    if (!name) {
      res.status(400).json({ message: "City name is required" });
      return;
    }
    const city = await transaction(async (client) => {
      const current = await getCity(client, req.params.cityId);
      if (!current) {
        throw new Error("City not found");
      }
      await client.query("UPDATE cities SET name = $2 WHERE id = $1", [req.params.cityId, name]);
      return { id: req.params.cityId, name };
    });
    res.json(city);
  } catch (error) {
    res.status(404).json({ message: error instanceof Error ? error.message : "City update failed" });
  }
});

app.delete("/api/cities/:cityId", async (req, res) => {
  try {
    await query("DELETE FROM cities WHERE id = $1", [req.params.cityId]);
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "City delete failed" });
  }
});

app.get("/api/tariffs", async (req, res) => {
  try {
    const params = [];
    let whereClause = "";
    if (`${req.query.cityId || ""}`.trim()) {
      params.push(`${req.query.cityId}`.trim());
      whereClause = `WHERE city_id = $${params.length}`;
    }
    const rows = await many(
      `SELECT * FROM tariffs ${whereClause} ORDER BY name ASC`,
      params,
    );
    res.json(
      rows.map((item) => ({
        id: item.id,
        cityId: item.city_id,
        name: item.name,
        price: toNumber(item.price),
      })),
    );
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Tariffs failed" });
  }
});

app.post("/api/tariffs", async (req, res) => {
  try {
    const tariff = await transaction(async (client) => {
      const city = await getCity(client, req.body.cityId);
      if (!city) {
        throw new Error("City not found");
      }
      const nextId = req.body.id || id("tariff");
      const name = `${req.body.name || ""}`.trim();
      const price = parsePositiveAmount(req.body.price);
      if (!name || !price) {
        throw new Error("Tariff payload is invalid");
      }
      await client.query(
        "INSERT INTO tariffs (id, city_id, name, price) VALUES ($1, $2, $3, $4)",
        [nextId, req.body.cityId, name, price],
      );
      return { id: nextId, cityId: req.body.cityId, name, price };
    });
    res.status(201).json(tariff);
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Tariff create failed" });
  }
});

app.patch("/api/tariffs/:tariffId", async (req, res) => {
  try {
    const tariff = await transaction(async (client) => {
      const current = await getTariff(client, req.params.tariffId);
      if (!current) {
        throw new Error("Tariff not found");
      }
      const cityId =
        typeof req.body.cityId === "string" && (await getCity(client, req.body.cityId))
          ? req.body.cityId
          : current.city_id;
      const name =
        typeof req.body.name === "string" && req.body.name.trim()
          ? req.body.name.trim()
          : current.name;
      const price =
        req.body.price !== undefined ? parsePositiveAmount(req.body.price) : toNumber(current.price);
      if (!price) {
        throw new Error("Tariff price is invalid");
      }
      await client.query(
        `
        UPDATE tariffs
        SET city_id = $2,
            name = $3,
            price = $4,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
        `,
        [req.params.tariffId, cityId, name, price],
      );
      return { id: req.params.tariffId, cityId, name, price };
    });
    res.json(tariff);
  } catch (error) {
    res.status(404).json({ message: error instanceof Error ? error.message : "Tariff update failed" });
  }
});

app.delete("/api/tariffs/:tariffId", async (req, res) => {
  try {
    await query("DELETE FROM tariffs WHERE id = $1", [req.params.tariffId]);
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Tariff delete failed" });
  }
});

app.get("/api/buses", async (req, res) => {
  try {
    const buses = await withClient((client) =>
      fetchBuses(client, {
        cityId: `${req.query.cityId || ""}`.trim(),
        number: `${req.query.number || ""}`.trim(),
        qrToken: `${req.query.qrToken || ""}`.trim(),
        bluetoothOnly: req.query.bluetooth === "true",
      }),
    );
    res.json(buses);
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Buses failed" });
  }
});

app.post("/api/buses", async (req, res) => {
  try {
    const bus = await transaction(async (client) => {
      const city = await getCity(client, req.body.cityId);
      const tariff = await getTariff(client, req.body.tariffId);
      if (!city || !tariff) {
        throw new Error("City or tariff not found");
      }

      const nextBus = {
        id: req.body.id || id("bus"),
        cityId: req.body.cityId,
        number: normalizeTransportValue(req.body.number),
        routeNumber: `${req.body.routeNumber || ""}`.trim() || "№ 1",
        tariffId: req.body.tariffId,
        bluetoothEnabled: toBool(req.body.bluetoothEnabled, true),
        validatorName: normalizeTransportValue(req.body.validatorName || req.body.number),
        qrToken: `${req.body.qrToken || `qr-${Date.now()}`}`.trim(),
      };

      if (!nextBus.number) {
        throw new Error("Bus number is required");
      }

      await client.query(
        `
        INSERT INTO buses (
          id,
          city_id,
          number,
          route_number,
          tariff_id,
          bluetooth_enabled,
          validator_name,
          qr_token,
          created_at,
          updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        `,
        [
          nextBus.id,
          nextBus.cityId,
          nextBus.number,
          nextBus.routeNumber,
          nextBus.tariffId,
          nextBus.bluetoothEnabled,
          nextBus.validatorName,
          nextBus.qrToken,
        ],
      );

      return (await fetchBuses(client, { cityId: nextBus.cityId, number: nextBus.number }))
        .find((item) => item.id === nextBus.id);
    });

    res.status(201).json(bus);
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Bus create failed" });
  }
});

app.patch("/api/buses/:busId", async (req, res) => {
  try {
    const bus = await transaction(async (client) => {
      const current = await getBus(client, req.params.busId);
      if (!current) {
        throw new Error("Bus not found");
      }

      const cityId =
        typeof req.body.cityId === "string" && (await getCity(client, req.body.cityId))
          ? req.body.cityId
          : current.city_id;
      const tariffId =
        typeof req.body.tariffId === "string" && (await getTariff(client, req.body.tariffId))
          ? req.body.tariffId
          : current.tariff_id;

      const nextNumber =
        typeof req.body.number === "string" && req.body.number.trim()
          ? normalizeTransportValue(req.body.number)
          : current.number;
      const nextRouteNumber =
        typeof req.body.routeNumber === "string" && req.body.routeNumber.trim()
          ? req.body.routeNumber.trim()
          : current.route_number;
      const nextValidatorName =
        typeof req.body.validatorName === "string" && req.body.validatorName.trim()
          ? normalizeTransportValue(req.body.validatorName)
          : current.validator_name;
      const nextQrToken =
        typeof req.body.qrToken === "string" && req.body.qrToken.trim()
          ? req.body.qrToken.trim()
          : current.qr_token;

      await client.query(
        `
        UPDATE buses
        SET city_id = $2,
            number = $3,
            route_number = $4,
            tariff_id = $5,
            bluetooth_enabled = $6,
            validator_name = $7,
            qr_token = $8,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
        `,
        [
          req.params.busId,
          cityId,
          nextNumber,
          nextRouteNumber,
          tariffId,
          req.body.bluetoothEnabled !== undefined
            ? toBool(req.body.bluetoothEnabled, current.bluetooth_enabled)
            : current.bluetooth_enabled,
          nextValidatorName,
          nextQrToken,
        ],
      );

      return (await fetchBuses(client, { cityId, number: nextNumber }))
        .find((item) => item.id === req.params.busId);
    });

    res.json(bus);
  } catch (error) {
    res.status(404).json({ message: error instanceof Error ? error.message : "Bus update failed" });
  }
});

app.delete("/api/buses/:busId", async (req, res) => {
  try {
    await query("DELETE FROM buses WHERE id = $1", [req.params.busId]);
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Bus delete failed" });
  }
});

app.get("/api/tickets", async (req, res) => {
  try {
    const tickets = await withClient(async (client) => {
      const auth = await getSessionContext(req, client);
      const phoneNumber = normalizePhoneNumber(req.query.phone);
      if (auth) {
        return fetchTicketsForUser(client, { userId: auth.user.id });
      }
      if (phoneNumber) {
        return fetchTicketsForUser(client, { phoneNumber });
      }
      return fetchTicketsForUser(client);
    });
    res.json(tickets);
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Tickets failed" });
  }
});

app.post("/api/tickets", async (req, res) => {
  try {
    const ticket = await transaction(async (client) => {
      const auth = await getSessionContext(req, client);
      const user =
        auth?.user ||
        (req.body.phoneNumber
          ? await ensureUser(client, normalizePhoneNumber(req.body.phoneNumber), {
              cityName: req.body.cityName,
            })
          : null);

      if (!user) {
        throw new Error("Authentication or phone number is required");
      }

      const bus = await getBus(client, req.body.busId);
      if (!bus) {
        throw new Error("Bus not found");
      }

      const relatedBus = (await fetchBuses(client, { cityId: bus.city_id, number: bus.number }))
        .find((item) => item.id === bus.id);
      const settings = await getAppSettings(client);
      const requestedCity =
        (await getCity(client, `${req.body.cityId || ""}`.trim())) ||
        (await getCityByName(client, req.body.cityName)) ||
        (await getCityByName(client, user.city_name)) ||
        (await getCity(client, bus.city_id));
      const wallet = await maybeOne("SELECT * FROM wallets WHERE user_id = $1", [user.id], client);
      const amount = toNumber(relatedBus?.price);
      let paymentMethod = `${req.body.paymentMethod || "wallet"}`.trim();
      let accessMode = "granted";

      if (!user.ride_access_enabled) {
        if (Number(user.trial_rides_remaining || 0) > 0) {
          await client.query(
            `
            UPDATE users
            SET trial_rides_remaining = trial_rides_remaining - 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1
            `,
            [user.id],
          );
          paymentMethod = "trial";
          accessMode = "trial";
        } else {
          const supportHandle = settings.accessRequestTelegram;
          throw Object.assign(new Error(`Ride access is locked. Write to ${supportHandle} for activation.`), {
            statusCode: 403,
            errorCode: "ACCESS_REQUIRED",
            supportTelegram: supportHandle,
          });
        }
      } else if (paymentMethod === "transport-card") {
        const targetCardId = req.body.cardId || wallet?.active_card_id;
        const transportCard = await maybeOne(
          "SELECT * FROM transport_cards WHERE id = $1 AND user_id = $2",
          [targetCardId, user.id],
          client,
        );
        if (!transportCard) {
          throw new Error("Active transport card not found");
        }
        const before = toNumber(transportCard.balance);
        if (before < amount) {
          throw new Error("Insufficient transport card balance");
        }
        const after = before - amount;
        await client.query(
          `
          UPDATE transport_cards
          SET balance = $2,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = $1
          `,
          [transportCard.id, after],
        );
        await createWalletTransaction(client, user.id, {
          type: "ride",
          source: "transport-card",
          description: `Ride payment for ${relatedBus.number}`,
          amount: -amount,
          balanceBefore: before,
          balanceAfter: after,
          meta: {
            cardId: transportCard.id,
            busId: bus.id,
            routeNumber: relatedBus.routeNumber,
          },
        });
        accessMode = "transport-card";
      } else if (paymentMethod === "wallet") {
        const before = toNumber(wallet?.balance);
        if (before < amount) {
          throw new Error("Insufficient wallet balance");
        }
        const after = before - amount;
        await client.query(
          `
          UPDATE wallets
          SET balance = $2,
              updated_at = CURRENT_TIMESTAMP
          WHERE user_id = $1
          `,
          [user.id, after],
        );
        await createWalletTransaction(client, user.id, {
          type: "ride",
          source: "wallet",
          description: `Ride payment for ${relatedBus.number}`,
          amount: -amount,
          balanceBefore: before,
          balanceAfter: after,
          meta: {
            busId: bus.id,
            routeNumber: relatedBus.routeNumber,
          },
        });
        accessMode = "wallet";
      }

      const nextTicket = {
        id: id("ticket"),
        userId: user.id,
        phoneNumber: user.phone_number,
        cityId: requestedCity?.id || bus.city_id,
        cityName: requestedCity?.name || user.city_name || relatedBus.cityName,
        busId: bus.id,
        busNumber: relatedBus.number,
        routeNumber: relatedBus.routeNumber,
        tariffName: relatedBus.tariffName,
        amount,
        paymentMethod,
        accessMode,
        qrValue: `${relatedBus.qrToken}:${Date.now()}`,
        paidAt: nowIso(),
        validUntil: futureIso(RIDE_TICKET_TTL_MS),
        status: "active",
      };

      await client.query(
        `
        INSERT INTO tickets (
          id,
          user_id,
          phone_number,
          city_id,
          city_name,
          bus_id,
          bus_number,
          route_number,
          tariff_name,
          amount,
          payment_method,
          access_mode,
          qr_value,
          paid_at,
          valid_until,
          status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
        `,
        [
          nextTicket.id,
          nextTicket.userId,
          nextTicket.phoneNumber,
          nextTicket.cityId,
          nextTicket.cityName,
          nextTicket.busId,
          nextTicket.busNumber,
          nextTicket.routeNumber,
          nextTicket.tariffName,
          nextTicket.amount,
          nextTicket.paymentMethod,
          nextTicket.accessMode,
          nextTicket.qrValue,
          nextTicket.paidAt,
          nextTicket.validUntil,
          nextTicket.status,
        ],
      );
      await createNotification(
        client,
        user.id,
        "Оплата проезда",
        `${relatedBus.routeNumber} • ${amount} ${settings.currencySymbol}`,
        "ticket",
      );

      return serializeTicketRow({
        id: nextTicket.id,
        phone_number: nextTicket.phoneNumber,
        city_id: nextTicket.cityId,
        city_name: nextTicket.cityName,
        bus_id: nextTicket.busId,
        bus_number: nextTicket.busNumber,
        route_number: nextTicket.routeNumber,
        tariff_name: nextTicket.tariffName,
        amount: nextTicket.amount,
        payment_method: nextTicket.paymentMethod,
        access_mode: nextTicket.accessMode,
        qr_value: nextTicket.qrValue,
        paid_at: nextTicket.paidAt,
        valid_until: nextTicket.validUntil,
        status: nextTicket.status,
      });
    });

    res.status(201).json(ticket);
  } catch (error) {
    const statusCode = error && typeof error === "object" && "statusCode" in error
      ? error.statusCode
      : 400;
    const payload = {
      message: error instanceof Error ? error.message : "Ticket create failed",
    };
    if (error && typeof error === "object" && "errorCode" in error) {
      payload.code = error.errorCode;
      payload.supportTelegram = error.supportTelegram;
    }
    res.status(statusCode).json(payload);
  }
});

app.post("/api/support", async (req, res) => {
  try {
    const payload = await transaction(async (client) => {
      const user = await findUserFromRequest(client, req);
      const message = `${req.body.message || ""}`.trim();
      if (!message) {
        throw new Error("Message is required");
      }

      const entry = {
        id: id("support"),
        userId: user?.id || null,
        phoneNumber: user?.phone_number || normalizePhoneNumber(req.body.phoneNumber),
        subject: `${req.body.subject || "Support request"}`.trim(),
        message,
        status: "new",
        kind: `${req.body.kind || "support"}`.trim(),
        createdAt: nowIso(),
      };

      await client.query(
        `
        INSERT INTO support_messages (
          id,
          user_id,
          phone_number,
          subject,
          message,
          status,
          kind,
          created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `,
        [
          entry.id,
          entry.userId,
          entry.phoneNumber,
          entry.subject,
          entry.message,
          entry.status,
          entry.kind,
          entry.createdAt,
        ],
      );

      if (user) {
        await createNotification(client, user.id, "Support request", "Support request created.", "support");
      }

      return entry;
    });

    res.status(201).json(payload);
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Support failed" });
  }
});

app.get("/api/notifications", async (req, res) => {
  try {
    const notifications = await withClient(async (client) => {
      const user = await findUserFromRequest(client, req);
      if (!user) {
        return [];
      }

      const rows = await many(
        `
        SELECT *
        FROM notifications
        WHERE user_id = $1
        ORDER BY created_at DESC
        `,
        [user.id],
        client,
      );

      return rows.map((item) => ({
        id: item.id,
        title: item.title,
        body: item.body,
        type: item.type,
        read: Boolean(item.is_read),
        createdAt: item.created_at,
      }));
    });

    res.json(notifications);
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Notifications failed" });
  }
});

app.patch("/api/notifications/:notificationId/read", async (req, res) => {
  try {
    const notification = await transaction(async (client) => {
      const context = await requireUserContext(req, res, client);
      if (!context) {
        return null;
      }

      const row = await maybeOne(
        `
        SELECT *
        FROM notifications
        WHERE id = $1
          AND user_id = $2
        `,
        [req.params.notificationId, context.user.id],
        client,
      );

      if (!row) {
        throw new Error("Notification not found");
      }

      await client.query("UPDATE notifications SET is_read = TRUE WHERE id = $1", [row.id]);
      return {
        id: row.id,
        title: row.title,
        body: row.body,
        type: row.type,
        read: true,
        createdAt: row.created_at,
      };
    });

    if (notification) {
      res.json(notification);
    }
  } catch (error) {
    res.status(404).json({ message: error instanceof Error ? error.message : "Notification update failed" });
  }
});

app.get("/api/admin/summary", async (req, res) => {
  try {
    const payload = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      return {
        ...(await getSummary(client)),
        admin: {
          id: context.admin.id,
          name: context.admin.name,
        },
      };
    });
    if (payload) {
      res.json(payload);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin summary failed" });
  }
});

app.get("/api/admin/users", async (req, res) => {
  try {
    const users = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }

      const rows = await many("SELECT * FROM users ORDER BY created_at DESC", [], client);
      return Promise.all(
        rows.map(async (row) => ({
          ...serializeUser(row),
          wallet: await loadWallet(client, row.id),
        })),
      );
    });

    if (users) {
      res.json(users);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin users failed" });
  }
});

app.patch("/api/admin/users/:userId", async (req, res) => {
  try {
    const payload = await transaction(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }

      const user = await maybeOne("SELECT * FROM users WHERE id = $1", [req.params.userId], client);
      if (!user) {
        throw new Error("User not found");
      }

      const nextFullName =
        typeof req.body.fullName === "string" && req.body.fullName.trim()
          ? req.body.fullName.trim()
          : user.full_name;
      const nextCityName =
        typeof req.body.cityName === "string" ? req.body.cityName.trim() : user.city_name;
      const nextStatus =
        typeof req.body.status === "string" && req.body.status.trim()
          ? req.body.status.trim()
          : user.status;
      const nextTelegramChatId =
        typeof req.body.telegramChatId === "string"
          ? req.body.telegramChatId.trim()
          : user.telegram_chat_id;
      if (nextTelegramChatId) {
        const existingOwner = await maybeOne(
          `
          SELECT phone_number
          FROM users
          WHERE telegram_chat_id = $1
            AND id <> $2
          LIMIT 1
          `,
          [nextTelegramChatId, user.id],
          client,
        );
        if (existingOwner) {
          throw new Error(
            `Telegram chat is already connected to ${existingOwner.phone_number}`,
          );
        }
      }
      const nextRideAccessEnabled =
        typeof req.body.rideAccessEnabled === "boolean"
          ? req.body.rideAccessEnabled
          : user.ride_access_enabled;
      const nextTrialRidesRemaining =
        req.body.trialRidesRemaining !== undefined
          ? Math.max(0, Number(req.body.trialRidesRemaining || 0))
          : Number(user.trial_rides_remaining || 0);
      const nextAccessNote =
        typeof req.body.accessNote === "string" ? req.body.accessNote.trim() : user.access_note;
      const nextAccessRequestedAt =
        nextRideAccessEnabled
          ? null
          : req.body.accessRequestedAt === null
            ? null
            : user.access_requested_at;

      await client.query(
        `
        UPDATE users
        SET full_name = $2,
            city_name = $3,
            status = $4,
            telegram_chat_id = $5,
            ride_access_enabled = $6,
            trial_rides_remaining = $7,
            access_note = $8,
            access_requested_at = $9,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
        `,
        [
          user.id,
          nextFullName,
          nextCityName,
          nextStatus,
          nextTelegramChatId,
          nextRideAccessEnabled,
          nextTrialRidesRemaining,
          nextAccessNote,
          nextAccessRequestedAt,
        ],
      );

      if (req.body.balance !== undefined) {
        await client.query(
          `
          UPDATE wallets
          SET balance = $2,
              updated_at = CURRENT_TIMESTAMP
          WHERE user_id = $1
          `,
          [user.id, toNumber(req.body.balance)],
        );
      }

      const nextUser = await maybeOne("SELECT * FROM users WHERE id = $1", [user.id], client);
      return {
        ...serializeUser(nextUser),
        wallet: await loadWallet(client, nextUser.id),
      };
    });

    if (payload) {
      res.json(payload);
    }
  } catch (error) {
    res.status(404).json({ message: error instanceof Error ? error.message : "Admin user update failed" });
  }
});

app.get("/api/admin/transactions", async (req, res) => {
  try {
    const transactions = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      const rows = await many(
        "SELECT * FROM wallet_transactions ORDER BY created_at DESC",
        [],
        client,
      );
      return rows.map((item) => ({
        id: item.id,
        userId: item.user_id,
        type: item.type,
        source: item.source,
        description: item.description,
        amount: toNumber(item.amount),
        balanceBefore: toNumber(item.balance_before),
        balanceAfter: toNumber(item.balance_after),
        meta: safeJsonParse(item.meta_json),
        createdAt: item.created_at,
      }));
    });

    if (transactions) {
      res.json(transactions);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin transactions failed" });
  }
});

app.get("/api/admin/tickets", async (req, res) => {
  try {
    const tickets = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      return fetchTicketsForUser(client);
    });

    if (tickets) {
      res.json(tickets);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin tickets failed" });
  }
});

app.get("/api/admin/auth-codes", async (req, res) => {
  try {
    const codes = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      const rows = await many("SELECT * FROM auth_codes ORDER BY created_at DESC", [], client);
      return rows.map((item) => ({
        id: item.id,
        phoneNumber: item.phone_number,
        code: item.code,
        status: item.status,
        attempts: item.attempts,
        createdAt: item.created_at,
        expiresAt: item.expires_at,
        deliveryId: item.delivery_id,
        supportTelegram: item.support_telegram,
      }));
    });
    if (codes) {
      res.json(codes);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin auth codes failed" });
  }
});

app.get("/api/admin/deliveries", async (req, res) => {
  try {
    const deliveries = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      const rows = await many("SELECT * FROM telegram_deliveries ORDER BY created_at DESC", [], client);
      return rows.map((item) => ({
        id: item.id,
        phoneNumber: item.phone_number,
        chatId: item.chat_id,
        status: item.status,
        messageText: item.message_text,
        responseBody: item.response_body,
        error: item.error,
        createdAt: item.created_at,
      }));
    });
    if (deliveries) {
      res.json(deliveries);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin deliveries failed" });
  }
});

app.get("/api/admin/support", async (req, res) => {
  try {
    const items = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      const rows = await many("SELECT * FROM support_messages ORDER BY created_at DESC", [], client);
      return rows.map((item) => ({
        id: item.id,
        userId: item.user_id,
        phoneNumber: item.phone_number,
        subject: item.subject,
        message: item.message,
        status: item.status,
        kind: item.kind,
        createdAt: item.created_at,
      }));
    });
    if (items) {
      res.json(items);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin support failed" });
  }
});

app.get("/api/admin/app-settings", async (req, res) => {
  try {
    const settings = await withClient(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      return getAppSettings(client);
    });
    if (settings) {
      res.json(settings);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin settings failed" });
  }
});

app.patch("/api/admin/app-settings", async (req, res) => {
  try {
    const settings = await transaction(async (client) => {
      const context = await requireAdminContext(req, res, client);
      if (!context) {
        return null;
      }
      const current = await getAppSettings(client);
      const next = {
        appName:
          typeof req.body.appName === "string" && req.body.appName.trim()
            ? req.body.appName.trim()
            : current.appName,
        supportPhone:
          typeof req.body.supportPhone === "string" && req.body.supportPhone.trim()
            ? req.body.supportPhone.trim()
            : current.supportPhone,
        supportTelegram:
          typeof req.body.supportTelegram === "string" && req.body.supportTelegram.trim()
            ? req.body.supportTelegram.trim()
            : current.supportTelegram,
        accessRequestTelegram:
          typeof req.body.accessRequestTelegram === "string" && req.body.accessRequestTelegram.trim()
            ? req.body.accessRequestTelegram.trim()
            : current.accessRequestTelegram,
        loginDeliveryMode:
          typeof req.body.loginDeliveryMode === "string" && req.body.loginDeliveryMode.trim()
            ? req.body.loginDeliveryMode.trim()
            : current.loginDeliveryMode,
        defaultLanguage:
          typeof req.body.defaultLanguage === "string" && req.body.defaultLanguage.trim()
            ? req.body.defaultLanguage.trim()
            : current.defaultLanguage,
        availableLanguages: Array.isArray(req.body.availableLanguages)
          ? req.body.availableLanguages
          : current.availableLanguages,
        shareUrl:
          typeof req.body.shareUrl === "string" && req.body.shareUrl.trim()
            ? req.body.shareUrl.trim()
            : current.shareUrl,
        currencySymbol:
          typeof req.body.currencySymbol === "string" && req.body.currencySymbol.trim()
            ? req.body.currencySymbol.trim()
            : current.currencySymbol,
        newUserBonusBalance:
          req.body.newUserBonusBalance !== undefined
            ? toNumber(req.body.newUserBonusBalance)
            : current.newUserBonusBalance,
        minimumTopUpAmount:
          req.body.minimumTopUpAmount !== undefined
            ? toNumber(req.body.minimumTopUpAmount)
            : current.minimumTopUpAmount,
        trialRideCount:
          req.body.trialRideCount !== undefined
            ? Math.max(0, Number(req.body.trialRideCount || 0))
            : current.trialRideCount,
        maintenanceMode:
          typeof req.body.maintenanceMode === "boolean"
            ? req.body.maintenanceMode
            : current.maintenanceMode,
      };

      await client.query(
        `
        UPDATE app_settings
        SET app_name = $2,
            support_phone = $3,
            support_telegram = $4,
            access_request_telegram = $5,
            login_delivery_mode = $6,
            default_language = $7,
            available_languages_json = $8,
            share_url = $9,
            currency_symbol = $10,
            new_user_bonus_balance = $11,
            minimum_top_up_amount = $12,
            trial_ride_count = $13,
            maintenance_mode = $14,
            updated_at = CURRENT_TIMESTAMP
        WHERE singleton_id = 1
        `,
        [
          1,
          next.appName,
          next.supportPhone,
          next.supportTelegram,
          next.accessRequestTelegram,
          next.loginDeliveryMode,
          next.defaultLanguage,
          JSON.stringify(next.availableLanguages),
          next.shareUrl,
          next.currencySymbol,
          next.newUserBonusBalance,
          next.minimumTopUpAmount,
          next.trialRideCount,
          next.maintenanceMode,
        ],
      );

      return next;
    });

    if (settings) {
      res.json(settings);
    }
  } catch (error) {
    res.status(500).json({ message: error instanceof Error ? error.message : "Admin settings update failed" });
  }
});

app.get("*", (req, res) => {
  if (req.path.startsWith("/api/")) {
    res.status(404).json({ message: "Not found" });
    return;
  }
  res.sendFile(path.join(publicDir, "index.html"));
});

async function startServer() {
  await initDatabase({ adminToken: DEFAULT_ADMIN_TOKEN });
  app.listen(PORT, () => {
    console.log(`Avtobys backend listening on http://localhost:${PORT}`);
    startTelegramPolling();
  });
}

startServer().catch((error) => {
  console.error("Failed to start backend", error);
  process.exit(1);
});
