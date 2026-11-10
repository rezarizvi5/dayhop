import { StyleSheet } from "react-native";

export const colors = {
  bg: "#eef0f3",
  surface: "#ffffff",
  ink: "#0b0c0e",
  muted: "#5d6470",
  accent: "#1f2de6",
  accentInk: "#ffffff",
  line: "#d5d8df",
};

export const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.bg },
  pad: { padding: 24, gap: 16 },
  h1: { fontSize: 34, lineHeight: 38, fontWeight: "500", color: colors.ink, letterSpacing: -0.8 },
  h2: { fontSize: 24, lineHeight: 30, fontWeight: "500", color: colors.ink },
  body: { fontSize: 16, lineHeight: 24, color: colors.ink },
  muted: { fontSize: 14, lineHeight: 20, color: colors.muted },
  card: { backgroundColor: colors.surface, borderRadius: 16, padding: 16, gap: 8, borderWidth: 1, borderColor: colors.line },
  primary: { backgroundColor: colors.accent, minHeight: 48, borderRadius: 12, alignItems: "center", justifyContent: "center", paddingHorizontal: 16 },
  primaryText: { color: colors.accentInk, fontSize: 16, fontWeight: "500" },
  secondary: { backgroundColor: colors.surface, minHeight: 48, borderRadius: 12, alignItems: "center", justifyContent: "center", paddingHorizontal: 16, borderWidth: 1, borderColor: colors.line },
  secondaryText: { color: colors.ink, fontSize: 16, fontWeight: "500" },
  input: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: 12, minHeight: 48, paddingHorizontal: 14, fontSize: 16, color: colors.ink },
  kidButton: { backgroundColor: colors.accent, minHeight: 72, borderRadius: 16, alignItems: "center", justifyContent: "center" },
  kidButtonText: { color: "#fff", fontSize: 22, fontWeight: "500" },
});
