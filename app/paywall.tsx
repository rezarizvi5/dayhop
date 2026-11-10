import { Pressable, ScrollView, Text } from "react-native";
import { useApp } from "../src/data/store";
import { styles } from "../src/ui/theme";

export default function Paywall() {
  const setPlan = useApp((s) => s.setPlan);
  const plan = useApp((s) => s.plan);
  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.pad}>
      <Text style={styles.h1}>Plus</Text>
      <Text style={styles.body}>$4.99 a month or $34.99 a year. 7-day trial. Billing starts when the trial ends unless you cancel. The subscription renews until you cancel it in Apple account settings.</Text>
      <Text style={styles.body}>Current plan: {plan}. This browser session stores the choice on the device. The App Store purchase, Restore Purchases and the RevenueCat webhook need the iOS build.</Text>
      <Pressable style={styles.primary} onPress={() => setPlan("plus")} accessibilityRole="button">
        <Text style={styles.primaryText}>Start the 7-day trial</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => setPlan("free")} accessibilityRole="button">
        <Text style={styles.secondaryText}>Use the free plan</Text>
      </Pressable>
      <Text style={styles.muted}>Terms and privacy live at dayhop.example until the real URLs are set.</Text>
    </ScrollView>
  );
}
