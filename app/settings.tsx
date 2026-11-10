import { useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { router } from "expo-router";
import { useApp } from "../src/data/store";
import { Gate } from "../src/ui/Gate";
import { styles } from "../src/ui/theme";

export default function Settings() {
  const state = useApp();
  const [gate, setGate] = useState(false);
  const [after, setAfter] = useState<"export" | "delete" | "plus" | null>(null);
  const [dump, setDump] = useState<string | null>(null);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.pad}>
      <Text style={styles.h1}>Settings</Text>
      <Text style={styles.body}>{state.householdName}</Text>
      <Text style={styles.muted}>{state.timeZone} · plan {state.plan}</Text>
      <Text style={styles.body}>Sound is {state.soundOn ? "on" : "off"}. Read-aloud is {state.readAloud ? "on" : "off"}.</Text>
      <Pressable style={styles.secondary} onPress={() => useApp.setState({ soundOn: !state.soundOn })} accessibilityRole="button">
        <Text style={styles.secondaryText}>Toggle sound</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => useApp.setState({ readAloud: !state.readAloud })} accessibilityRole="button">
        <Text style={styles.secondaryText}>Toggle read-aloud</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => { setAfter("plus"); setGate(true); }} accessibilityRole="button">
        <Text style={styles.secondaryText}>See Plus</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => { setAfter("export"); setGate(true); }} accessibilityRole="button">
        <Text style={styles.secondaryText}>Export data</Text>
      </Pressable>
      {dump ? <Text style={styles.muted}>{dump.slice(0, 400)}</Text> : null}
      {state.kids.map((kid) => (
        <Pressable key={kid.id} style={styles.secondary} onPress={() => state.deleteKid(kid.id)} accessibilityRole="button">
          <Text style={styles.secondaryText}>Delete {kid.nickname}</Text>
        </Pressable>
      ))}
      <Pressable style={styles.secondary} onPress={() => { setAfter("delete"); setGate(true); }} accessibilityRole="button">
        <Text style={styles.secondaryText}>Delete account</Text>
      </Pressable>
      <Text style={styles.muted}>Deleting the account does not cancel an Apple subscription. Support: hello@dayhop.example</Text>
      <Text style={styles.muted}>Guided Access on iOS can lock the device to Kid Mode. Turn it on in Settings, Accessibility, Guided Access.</Text>
      <Gate
        visible={gate}
        onClose={() => setGate(false)}
        onSuccess={() => {
          setGate(false);
          if (after === "export") setDump(state.exportData());
          if (after === "plus") router.push("/paywall");
          if (after === "delete") {
            state.deleteAccount();
            router.replace("/welcome");
          }
        }}
      />
    </ScrollView>
  );
}
