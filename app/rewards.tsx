import { useState } from "react";
import { Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { useApp } from "../src/data/store";
import { styles } from "../src/ui/theme";

export default function Rewards() {
  const kidMode = useLocalSearchParams<{ kid?: string }>().kid === "1";
  const state = useApp();
  const [title, setTitle] = useState("");
  const [cost, setCost] = useState("8");
  const [message, setMessage] = useState<string | null>(null);
  const kid = state.kids.find((item) => item.id === state.activeKidId) ?? state.kids[0];

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.pad}>
      <Text style={styles.h1}>Rewards</Text>
      {state.rewards.filter((reward) => !reward.archivedAt).map((reward) => (
        <View key={reward.id} style={styles.card}>
          <Text style={styles.h2}>{reward.title}</Text>
          <Text style={styles.body}>{reward.cost} stars</Text>
          {kidMode && kid && (
            <Pressable
              style={styles.kidButton}
              onPress={() => {
                const result = state.requestReward(`${Date.now().toString(36)}`, kid.id, reward.id);
                setMessage(result.message ?? (result.ok ? "Asked a grown-up." : null));
              }}
              accessibilityRole="button"
            >
              <Text style={styles.kidButtonText}>Ask for this</Text>
            </Pressable>
          )}
        </View>
      ))}
      {!kidMode && (
        <View style={{ gap: 8 }}>
          <TextInput style={styles.input} value={title} onChangeText={setTitle} placeholder="Reward title" accessibilityLabel="Reward title" />
          <TextInput style={styles.input} value={cost} onChangeText={setCost} keyboardType="number-pad" accessibilityLabel="Star cost" />
          {message ? <Text style={styles.muted}>{message}</Text> : null}
          <Pressable
            style={styles.primary}
            onPress={() => {
              const result = state.addReward({ title, iconKey: "book", cost: Number(cost) });
              setMessage(result.ok ? "Saved." : result.error === "PLAN_REQUIRED" ? "Rewards are a Plus feature." : result.error ?? "Could not save.");
              if (!result.ok && result.error === "PLAN_REQUIRED") return;
            }}
            accessibilityRole="button"
          >
            <Text style={styles.primaryText}>Add reward</Text>
          </Pressable>
        </View>
      )}
      {message && kidMode ? <Text style={styles.body}>{message}</Text> : null}
    </ScrollView>
  );
}
