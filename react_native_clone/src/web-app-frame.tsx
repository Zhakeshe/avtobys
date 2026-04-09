import type { ReactNode } from "react";
import { Platform, StyleSheet, useWindowDimensions, View } from "react-native";

const SHELL_MAX = 440;

/**
 * On web: full-viewport muted backdrop and a centered narrow column (phone-width)
 * so the Expo UI is usable on desktop. Native builds are unchanged.
 */
export function WebAppFrame({ children }: { children: ReactNode }) {
  const { width } = useWindowDimensions();

  if (Platform.OS !== "web") {
    return <>{children}</>;
  }

  const isWide = width > SHELL_MAX + 32;

  return (
    <View style={styles.webPage}>
      <View style={[styles.webShell, isWide && styles.webShellElevated]}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  webPage: {
    flex: 1,
    width: "100%",
    minHeight: "100vh" as unknown as number,
    alignItems: "center",
    backgroundColor: "#E6E9EF",
  },
  webShell: {
    flex: 1,
    width: "100%",
    maxWidth: SHELL_MAX,
    minHeight: "100vh" as unknown as number,
    backgroundColor: "#FFFFFF",
    overflow: "hidden",
  },
  webShellElevated: {
    boxShadow: "0 12px 48px rgba(15, 23, 42, 0.12)",
  },
});
