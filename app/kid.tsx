import { useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { router } from "expo-router";
import { characterFor, useApp } from "../src/data/store";
import { isScheduled, TIME_ORDER } from "../src/domain";
import { Gate } from "../src/ui/Gate";
import { colors, styles } from "../src/ui/theme";

export default function KidHome() {
  const state = useApp();
  const [gate, setGate] = useState(false);
  const kids = state.kids.filter((kid) => !kid.archivedAt);
  const kid = kids.find((item) => item.id === state.activeKidId) ?? kids[0];
  const today = state.today();
  if (!kid) return null;
  const character = characterFor(kid.characterId);
  const routines = state.routines
    .filter((routine) => routine.kidIds.includes(kid.id) && !routine.archivedAt && isScheduled(routine.days, today))
    .sort((a, b) => TIME_ORDER[a.timeOfDay] - TIME_ORDER[b.timeOfDay]);
  const runs = state.runs.filter((run) => run.kidId === kid.id && run.routineDate === today);
  const allDone = routines.length > 0 && routines.every((routine) => {
    const run = runs.find((item) => item.routineId === routine.id);
    return run && ["completed", "approved", "pending_approval"].includes(run.status);
  });

  return (
    <ScrollView style={styles.screen} contentContainerStyle={[styles.pad, { paddingTop: 48 }]}>
      <View style={{ width: 88, height: 88, borderRadius: 44, backgroundColor: character.color, alignItems: "center", justifyContent: "center" }}>
        <Text style={{ color: "#fff", fontSize: 28, fontWeight: "500" }}>{character.name.slice(0, 1)}</Text>
      </View>
      <Text style={styles.h1}>Hi {kid.nickname}</Text>
      <Text style={styles.body}>{kid.starsBalance} stars · streak {kid.streakCurrent}</Text>
      {routines.length === 0 && <Text style={styles.body}>Nothing on the list today.</Text>}
      {allDone && <Text style={styles.body}>All finished for today.</Text>}
      {routines.map((routine) => {
        const run = runs.find((item) => item.routineId === routine.id);
        const label = run?.status === "pending_approval" ? "Waiting for a grown-up" : run?.status === "completed" || run?.status === "approved" ? "Finished" : "Open";
        return (
          <Pressable
            key={routine.id}
            style={styles.card}
            onPress={() => router.push({ pathname: "/play", params: { kidId: kid.id, routineId: routine.id } })}
            accessibilityRole="button"
            accessibilityLabel={`${routine.name}, ${label}`}
          >
            <Text style={styles.h2}>{routine.name}</Text>
            <Text style={styles.muted}>{label}</Text>
          </Pressable>
        );
      })}
      {state.rewards.filter((reward) => !reward.archivedAt).length > 0 && (
        <Pressable style={styles.secondary} onPress={() => router.push({ pathname: "/rewards", params: { kid: "1" } })} accessibilityRole="button">
          <Text style={styles.secondaryText}>See rewards</Text>
        </Pressable>
      )}
      {kids.length > 1 && (
        <View style={{ flexDirection: "row", gap: 8, flexWrap: "wrap" }}>
          {kids.map((item) => (
            <Pressable key={item.id} style={styles.secondary} onPress={() => state.enterKidMode(item.id)} accessibilityRole="button">
              <Text style={styles.secondaryText}>{item.nickname}</Text>
            </Pressable>
          ))}
        </View>
      )}
      <Pressable style={[styles.secondary, { borderColor: colors.ink }]} onPress={() => setGate(true)} accessibilityRole="button">
        <Text style={styles.secondaryText}>Leave Kid Mode</Text>
      </Pressable>
      <Gate
        visible={gate}
        onClose={() => setGate(false)}
        onSuccess={() => {
          state.exitKidMode();
          setGate(false);
          router.replace("/home");
        }}
      />
    </ScrollView>
  );
}
