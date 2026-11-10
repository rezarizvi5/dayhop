import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { colors } from "../src/ui/theme";

export default function RootLayout() {
  return (
    <>
      <StatusBar style="dark" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: colors.bg },
          headerShadowVisible: false,
          headerTintColor: colors.ink,
          contentStyle: { backgroundColor: colors.bg },
        }}
      >
        <Stack.Screen name="index" options={{ headerShown: false }} />
        <Stack.Screen name="welcome" options={{ title: "DayHop" }} />
        <Stack.Screen name="home" options={{ title: "Household" }} />
        <Stack.Screen name="kid" options={{ headerShown: false }} />
        <Stack.Screen name="play" options={{ headerShown: false }} />
        <Stack.Screen name="inbox" options={{ title: "Approvals" }} />
        <Stack.Screen name="rewards" options={{ title: "Rewards" }} />
        <Stack.Screen name="edit" options={{ title: "Routine" }} />
        <Stack.Screen name="settings" options={{ title: "Settings" }} />
        <Stack.Screen name="paywall" options={{ title: "Plus" }} />
      </Stack>
    </>
  );
}
