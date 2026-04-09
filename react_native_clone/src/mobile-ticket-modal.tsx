import React from "react";
import { MaterialIcons } from "@expo/vector-icons";
import QRCode from "react-native-qrcode-svg";
import { Modal, Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from "react-native";

import type { TicketDto } from "./api";
import { colors, shadow } from "./theme";

export type TicketModalLabels = {
  transportCaption: string;
  ticketTitle: string;
};

function TicketStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={styles.statValue} numberOfLines={3}>
        {value}
      </Text>
    </View>
  );
}

export function TicketModal({
  ticket,
  onClose,
  labels,
}: {
  ticket: TicketDto | null;
  onClose: () => void;
  labels: TicketModalLabels;
}) {
  const { width, height } = useWindowDimensions();
  const modalMaxWidth = Math.min(width - 32, 420);
  const qrSize = Math.max(120, Math.min(188, Math.round(modalMaxWidth - 56)));
  const transportFontSize = Math.min(28, Math.max(20, Math.round(modalMaxWidth * 0.068)));

  return (
    <Modal visible={Boolean(ticket)} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <ScrollView
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          contentContainerStyle={[
            styles.modalScrollContent,
            { minHeight: height * 0.92, paddingVertical: Math.max(12, height * 0.02) },
          ]}
        >
          {ticket ? (
            <View style={[styles.ticketModal, { width: "100%", maxWidth: modalMaxWidth }]}>
              <Pressable style={styles.modalClose} onPress={onClose}>
                <MaterialIcons name="close" size={20} color={colors.textSecondary} />
              </Pressable>
              <Text style={styles.transportTitle}>{labels.transportCaption}</Text>
              <Text style={[styles.transportNumber, { fontSize: transportFontSize }]}>{ticket.busNumber}</Text>
              <View style={styles.qrWrap}>
                <QRCode value={ticket.qrValue} size={qrSize} />
              </View>
              <Text style={styles.modalMainTitle}>{labels.ticketTitle}</Text>
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
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalBackdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.28)",
    justifyContent: "center",
  },
  modalScrollContent: {
    flexGrow: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 16,
  },
  ticketModal: {
    borderRadius: 28,
    backgroundColor: "#FFFFFF",
    padding: 20,
    ...shadow,
  },
  modalClose: { alignSelf: "flex-end", padding: 4, marginBottom: 4 },
  transportTitle: { textAlign: "center", fontSize: 15, color: colors.textSecondary },
  transportNumber: {
    textAlign: "center",
    fontWeight: "700",
    color: colors.textPrimary,
    marginTop: 4,
  },
  qrWrap: { alignItems: "center", marginVertical: 16 },
  modalMainTitle: { fontSize: 18, fontWeight: "700", color: colors.textPrimary, marginBottom: 12 },
  ticketGrid: { flexDirection: "row", flexWrap: "wrap", gap: 10, rowGap: 10 },
  stat: {
    flexGrow: 1,
    flexBasis: "46%",
    minWidth: 118,
    maxWidth: "100%",
  },
  statLabel: { fontSize: 13, color: colors.textSecondary },
  statValue: { marginTop: 4, fontSize: 15, fontWeight: "600", color: colors.textPrimary },
});
