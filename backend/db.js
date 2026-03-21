const fs = require("fs");
const path = require("path");

const schemaPath = path.join(__dirname, "db", "schema.sql");
const schemaSql = fs.readFileSync(schemaPath, "utf8");

const DEFAULT_SETTINGS = {
  appName: "Avtobys MVP",
  supportPhone: "+7 700-255-56-19",
  supportTelegram: "@aqxrx",
  accessRequestTelegram: "@aqxrx",
  loginDeliveryMode: "telegram",
  defaultLanguage: "Русский",
  availableLanguages: ["Русский", "Қазақша"],
  shareUrl: "https://avtobys.local/app",
  currencySymbol: "₸",
  newUserBonusBalance: 3000,
  minimumTopUpAmount: 500,
  trialRideCount: 2,
  maintenanceMode: false,
};

const DEFAULT_CITIES = [
  { id: "aktau", name: "Актау" },
  { id: "astana", name: "Астана" },
  { id: "almaty", name: "Алматы" },
];

const DEFAULT_TARIFFS = [
  { id: "aktau-standard", cityId: "aktau", name: "Стандарт", price: 70 },
  { id: "aktau-student", cityId: "aktau", name: "Студент", price: 50 },
  { id: "astana-standard", cityId: "astana", name: "Стандарт", price: 80 },
  { id: "almaty-standard", cityId: "almaty", name: "Стандарт", price: 90 },
];

const DEFAULT_BUSES = [
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
];

let poolPromise = null;
let databaseInfo = null;

async function createPool() {
  if (poolPromise) {
    return poolPromise;
  }

  poolPromise = (async () => {
    if (process.env.DATABASE_URL) {
      const { Pool } = require("pg");
      const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_SSL === "true" ? { rejectUnauthorized: false } : undefined,
      });
      databaseInfo = {
        driver: "postgres",
        mode: "external",
      };
      return pool;
    }

    const { newDb } = require("pg-mem");
    const memoryDb = newDb({
      autoCreateForeignKeyIndices: true,
    });
    const adapter = memoryDb.adapters.createPg();
    databaseInfo = {
      driver: "pg-mem",
      mode: "memory",
    };
    return new adapter.Pool();
  })();

  return poolPromise;
}

async function getClient() {
  const pool = await createPool();
  return pool.connect();
}

async function query(text, params = []) {
  const pool = await createPool();
  return pool.query(text, params);
}

async function maybeOne(text, params = [], client = null) {
  const target = client || (await createPool());
  const result = await target.query(text, params);
  return result.rows[0] || null;
}

async function many(text, params = [], client = null) {
  const target = client || (await createPool());
  const result = await target.query(text, params);
  return result.rows;
}

async function transaction(callback) {
  const pool = await createPool();
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function initDatabase({ adminToken }) {
  const pool = await createPool();
  await pool.query(schemaSql);
  await seedDatabase(adminToken);
  return {
    ...databaseInfo,
    adminToken,
  };
}

async function seedDatabase(adminToken) {
  await transaction(async (client) => {
    const settings = await maybeOne("SELECT singleton_id FROM app_settings WHERE singleton_id = 1", [], client);
    if (!settings) {
      await client.query(
        `
        INSERT INTO app_settings (
          singleton_id,
          app_name,
          support_phone,
          support_telegram,
          access_request_telegram,
          login_delivery_mode,
          default_language,
          available_languages_json,
          share_url,
          currency_symbol,
          new_user_bonus_balance,
          minimum_top_up_amount,
          trial_ride_count,
          maintenance_mode
        ) VALUES (1, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        `,
        [
          DEFAULT_SETTINGS.appName,
          DEFAULT_SETTINGS.supportPhone,
          process.env.SUPPORT_TELEGRAM || DEFAULT_SETTINGS.supportTelegram,
          process.env.ACCESS_REQUEST_TELEGRAM || DEFAULT_SETTINGS.accessRequestTelegram,
          DEFAULT_SETTINGS.loginDeliveryMode,
          DEFAULT_SETTINGS.defaultLanguage,
          JSON.stringify(DEFAULT_SETTINGS.availableLanguages),
          DEFAULT_SETTINGS.shareUrl,
          DEFAULT_SETTINGS.currencySymbol,
          DEFAULT_SETTINGS.newUserBonusBalance,
          DEFAULT_SETTINGS.minimumTopUpAmount,
          DEFAULT_SETTINGS.trialRideCount,
          DEFAULT_SETTINGS.maintenanceMode,
        ],
      );
    }

    const admin = await maybeOne("SELECT id FROM admins WHERE token = $1", [adminToken], client);
    if (!admin) {
      await client.query(
        "INSERT INTO admins (id, name, token) VALUES ($1, $2, $3)",
        ["admin-dev", "Local Admin", adminToken],
      );
    }

    const cityCount = await maybeOne("SELECT COUNT(*)::int AS count FROM cities", [], client);
    if (!cityCount || cityCount.count === 0) {
      for (const city of DEFAULT_CITIES) {
        await client.query(
          "INSERT INTO cities (id, name) VALUES ($1, $2)",
          [city.id, city.name],
        );
      }
    }

    const tariffCount = await maybeOne("SELECT COUNT(*)::int AS count FROM tariffs", [], client);
    if (!tariffCount || tariffCount.count === 0) {
      for (const tariff of DEFAULT_TARIFFS) {
        await client.query(
          "INSERT INTO tariffs (id, city_id, name, price) VALUES ($1, $2, $3, $4)",
          [tariff.id, tariff.cityId, tariff.name, tariff.price],
        );
      }
    }

    const busCount = await maybeOne("SELECT COUNT(*)::int AS count FROM buses", [], client);
    if (!busCount || busCount.count === 0) {
      for (const bus of DEFAULT_BUSES) {
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
            qr_token
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          `,
          [
            bus.id,
            bus.cityId,
            bus.number,
            bus.routeNumber,
            bus.tariffId,
            bus.bluetoothEnabled,
            bus.validatorName,
            bus.qrToken,
          ],
        );
      }
    }
  });
}

module.exports = {
  DEFAULT_SETTINGS,
  getClient,
  initDatabase,
  query,
  maybeOne,
  many,
  transaction,
};
