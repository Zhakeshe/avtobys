import { Platform } from "react-native";

export type CityDto = {
  id: string;
  name: string;
};

export type TariffDto = {
  id: string;
  cityId: string;
  name: string;
  price: number;
};

export type BusDto = {
  id: string;
  cityId: string;
  cityName: string;
  number: string;
  validatorName?: string;
  routeNumber: string;
  tariffId: string;
  tariffName: string;
  price: number;
  bluetoothEnabled: boolean;
  qrToken: string;
};

export type TicketDto = {
  id: string;
  phoneNumber: string;
  cityId: string;
  cityName: string;
  busId: string;
  busNumber: string;
  routeNumber: string;
  tariffName: string;
  amount: number;
  paymentMethod: string;
  qrValue: string;
  paidAt: string;
  validUntil: string;
};

export type WalletCardDto = {
  id: string;
  holderName: string;
  number: string;
  cardType: "bank" | "transport";
  balance?: number;
  addedAt?: string;
};

export type WalletTransactionDto = {
  id: string;
  type: string;
  source: string;
  description: string;
  amount: number;
  balanceBefore: number;
  balanceAfter: number;
  createdAt: string;
};

export type WalletDto = {
  balance: number;
  cards: WalletCardDto[];
  activeCardId: string | null;
  transactions: WalletTransactionDto[];
};

export type UserDto = {
  id: string;
  phoneNumber: string;
  fullName: string;
  cityName: string;
  telegramChatId: string;
  status: string;
  createdAt: string;
  updatedAt: string;
  rideAccessEnabled: boolean;
  trialRidesRemaining: number;
  accessRequestedAt?: string | null;
  accessNote?: string;
  settings: {
    language: string;
    notificationsEnabled: boolean;
    appTheme: string;
  };
};

export type PublicConfigDto = {
  appName: string;
  supportPhone: string;
  supportTelegram: string;
  accessRequestTelegram: string;
  loginDeliveryMode: string;
  defaultLanguage: string;
  availableLanguages: string[];
  shareUrl: string;
  currencySymbol: string;
  newUserBonusBalance: number;
  minimumTopUpAmount: number;
  maintenanceMode: boolean;
  debugAuthCodeVisible: boolean;
  trialRideCount: number;
};

export type AuthRequestDto = {
  ok: boolean;
  phoneNumber: string;
  expiresAt: string;
  debugCode?: string;
  supportTelegram?: string;
  delivery?: {
    status: string;
    chatId?: string;
  };
};

export type AuthSessionDto = {
  token: string;
  user: UserDto;
  wallet: WalletDto;
  config: PublicConfigDto;
};

export type ApiRequestError = Error & {
  code?: string;
  supportTelegram?: string;
  status?: number;
};

type RequestOptions = RequestInit & {
  omitAuth?: boolean;
};

const API_BASE =
  process.env.EXPO_PUBLIC_API_URL ||
  (Platform.OS === "android"
    ? "http://10.0.2.2:4000/api"
    : "http://localhost:4000/api");

let apiSessionToken = "";

export function setApiSessionToken(token: string | null) {
  apiSessionToken = token ?? "";
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const headers = new Headers(options.headers ?? {});
  if (!headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  if (!options.omitAuth && apiSessionToken) {
    headers.set("Authorization", `Bearer ${apiSessionToken}`);
  }

  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  const text = await response.text();
  const data = text ? (JSON.parse(text) as unknown) : null;

  if (!response.ok) {
    const message =
      data && typeof data === "object" && "message" in data && typeof data.message === "string"
        ? data.message
        : `Request failed: ${response.status}`;
    const error = Object.assign(new Error(message), {
      code:
        data && typeof data === "object" && "code" in data && typeof data.code === "string"
          ? data.code
          : undefined,
      supportTelegram:
        data &&
        typeof data === "object" &&
        "supportTelegram" in data &&
        typeof data.supportTelegram === "string"
          ? data.supportTelegram
          : undefined,
      status: response.status,
    }) as ApiRequestError;
    throw error;
  }

  return data as T;
}

export function getPublicConfig() {
  return request<PublicConfigDto>("/config/public", { omitAuth: true });
}

export function requestAuthCode(input: {
  phoneNumber: string;
  cityName?: string;
}) {
  return request<AuthRequestDto>("/auth/request-code", {
    method: "POST",
    omitAuth: true,
    body: JSON.stringify(input),
  });
}

export function verifyAuthCode(input: {
  phoneNumber: string;
  code: string;
  cityName?: string;
}) {
  return request<AuthSessionDto>("/auth/verify-code", {
    method: "POST",
    omitAuth: true,
    body: JSON.stringify(input),
  });
}

export function getAuthSession() {
  return request<AuthSessionDto>("/auth/me");
}

export function logoutAuth() {
  return request<{ ok: boolean }>("/auth/logout", {
    method: "POST",
  });
}

export function updateProfile(input: {
  fullName?: string;
  cityName?: string;
  telegramChatId?: string;
}) {
  return request<UserDto>("/me", {
    method: "PATCH",
    body: JSON.stringify(input),
  });
}

export function getWallet() {
  return request<WalletDto>("/wallet");
}

export function addWalletCard(input: {
  holderName: string;
  number: string;
  cardType: "bank" | "transport";
}) {
  return request<WalletCardDto>("/wallet/cards", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function activateWalletCard(cardId: string) {
  return request<{ ok: boolean; activeCardId: string }>(`/wallet/cards/${cardId}/activate`, {
    method: "POST",
  });
}

export function topUpWallet(input: {
  amount: number;
  cardId?: string | null;
  targetType?: "wallet" | "transport";
  transportCardId?: string | null;
}) {
  return request<WalletDto>("/wallet/top-up", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function requestRideAccess(input?: { phoneNumber?: string; cityName?: string }) {
  return request<{ ok: boolean; telegramUsername: string; message: string }>("/access/request", {
    method: "POST",
    body: JSON.stringify(input || {}),
  });
}

export function getCities() {
  return request<CityDto[]>("/cities", { omitAuth: true });
}

export function getTariffs(cityId: string) {
  return request<TariffDto[]>(`/tariffs?cityId=${cityId}`, { omitAuth: true });
}

export function getBuses(
  cityId: string,
  options?: {
    number?: string;
    qrToken?: string;
  },
) {
  const params = new URLSearchParams();
  if (cityId) {
    params.set("cityId", cityId);
  }
  if (options?.number) {
    params.set("number", options.number);
  }
  if (options?.qrToken) {
    params.set("qrToken", options.qrToken);
  }
  return request<BusDto[]>(`/buses?${params.toString()}`, { omitAuth: true });
}

export function addBus(input: {
  cityId: string;
  tariffId: string;
  number: string;
  routeNumber: string;
}) {
  return request<BusDto>("/buses", {
    method: "POST",
    omitAuth: true,
    body: JSON.stringify({ ...input, bluetoothEnabled: true }),
  });
}

export function getTickets(phoneNumber?: string) {
  const suffix = phoneNumber ? `?phone=${encodeURIComponent(phoneNumber)}` : "";
  return request<TicketDto[]>(`/tickets${suffix}`);
}

export function createTicket(input: {
  phoneNumber?: string;
  busId: string;
  paymentMethod?: string;
  cityId?: string;
  cityName?: string;
}) {
  return request<TicketDto>("/tickets", {
    method: "POST",
    body: JSON.stringify(input),
  });
}
