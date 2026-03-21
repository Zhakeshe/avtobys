export type WalletCardData = {
  id: string;
  holderName: string;
  number: string;
  cardType: "bank" | "transport";
  balance?: number;
};

export type WalletState = {
  balance: number;
  cards: WalletCardData[];
  activeCardId: string | null;
};

export const emptyWalletState: WalletState = {
  balance: 0,
  cards: [],
  activeCardId: null,
};

export function walletStorageKey(phoneNumber: string) {
  const normalized = phoneNumber.replace(/\D/g, "");
  return `wallet_state_${normalized}`;
}

export function normalizeCardNumber(value: string) {
  return value.replace(/\s+/g, "").toUpperCase();
}

export function maskCardNumber(value: string) {
  const normalized = normalizeCardNumber(value);
  const lastFour = normalized.slice(-4);
  return lastFour ? `•••• ${lastFour}` : "Стандарт";
}

export function formatBalance(value: number) {
  return value.toFixed(2).replace(".", ",");
}

export function hydrateWalletState(raw: unknown): WalletState {
  const state = (raw ?? emptyWalletState) as Partial<WalletState> & {
    cards?: Array<Partial<WalletCardData>>;
  };

  const cards: WalletCardData[] = (state.cards ?? []).map((card) => ({
    id: card.id ?? `${Date.now()}`,
    holderName: card.holderName ?? "Моя карта",
    number: card.number ?? "",
    cardType: card.cardType === "transport" ? "transport" : "bank",
    balance: typeof card.balance === "number" ? card.balance : 0,
  }));

  return {
    balance: typeof state.balance === "number" ? state.balance : 0,
    activeCardId: state.activeCardId ?? cards[0]?.id ?? null,
    cards,
  };
}

export function getActiveCard(walletState: WalletState) {
  return (
    walletState.cards.find((card) => card.id === walletState.activeCardId) ??
    walletState.cards[0] ??
    null
  );
}
