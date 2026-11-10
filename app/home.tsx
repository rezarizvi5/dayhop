import { Pressable, ScrollView, Text, View } from "react-native";
import { router } from "expo-router";
import { characterFor, useApp } from "../src/data/store";
import { styles } from "../src/ui/theme";

export default function Home() {
  const state = useApp();
  const today = state.today();
  const pending = state.runs.filter((run) => run.status === "pending_approval").length;
  const requested = state.redemptions.filter((item) => item.status === "requested").length;

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.pad}>
      <Text style={styles.h1}>{state.householdName || "Household"}</Text>
      <Text style={styles.muted}>Routine day {today} · {state.timeZone}</Text>
      {(pending > 0 || requested > 0) && (
        <Pressable style={styles.card} onPress={() => router.push("/inbox")} accessibilityRole="button">
          <Text style={styles.body}>{pending} runs waiting. {requested} reward requests.</Text>
        </Pressable>
      )}
      {state.kids.filter((kid) => !kid.archivedAt).map((kid) => {
        const runs = state.runs.filter((run) => run.kidId === kid.id && run.routineDate === today);
        const routines = state.routines.filter((routine) => routine.kidIds.includes(kid.id) && !routine.archivedAt);
        const done = runs.filter((run) => run.status === "completed" || run.status === "approved" || run.status === "pending_approval").length;
        const character = characterFor(kid.characterId);
        return (
          <View key={kid.id} style={styles.card}>
            <Text style={styles.h2}>{kid.nickname}</Text>
            <Text style={styles.body}>{character.name} · {kid.starsBalance} stars · streak {kid.streakCurrent}</Text>
            <Text style={styles.muted}>{done} of {routines.length} finished today</Text>
          </View>
        );
      })}
      <Pressable
        style={styles.primary}
        onPress={() => {
          const first = state.kids.find((kid) => !kid.archivedAt);
          if (!first) return;
          state.enterKidMode(first.id);
          router.replace("/kid");
        }}
        accessibilityRole="button"
      >
        <Text style={styles.primaryText}>Start Kid Mode</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => router.push("/edit")} accessibilityRole="button">
        <Text style={styles.secondaryText}>Add a routine</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => router.push("/inbox")} accessibilityRole="button">
        <Text style={styles.secondaryText}>Open approvals</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => router.push("/rewards")} accessibilityRole="button">
        <Text style={styles.secondaryText}>Open rewards</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={() => router.push("/settings")} accessibilityRole="button">
        <Text style={styles.secondaryText}>Open settings</Text>
      </Pressable>
    </ScrollView>
  );
}
