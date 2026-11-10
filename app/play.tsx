import { useEffect, useRef, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { characterFor, useApp } from "../src/data/store";
import { isPreReader } from "../src/data/templates";
import { speak } from "../src/ui/Gate";
import { colors, styles } from "../src/ui/theme";

export default function Play() {
  const { kidId, routineId } = useLocalSearchParams<{ kidId: string; routineId: string }>();
  const state = useApp();
  const kid = state.kids.find((item) => item.id === kidId);
  const routine = state.routines.find((item) => item.id === routineId);
  const today = state.today();
  const run = state.runs.find((item) => item.kidId === kidId && item.routineId === routineId && item.routineDate === today);
  const [message, setMessage] = useState<string | null>(null);
  const [oops, setOops] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const steps = run?.steps ?? routine?.steps ?? [];
  const character = characterFor(kid?.characterId ?? "pip");

  useEffect(() => () => {
    if (timer.current) clearTimeout(timer.current);
  }, []);

  if (!kid || !routine) return <Text style={styles.body}>That routine is missing.</Text>;

  const current = steps.find((step) => !run?.completions[step.id] || run.completions[step.id].undoneAt);
  const finished = run && ["completed", "approved", "pending_approval"].includes(run.status);

  function done(stepId: string) {
    const result = state.completeStep({ completionId: `${Date.now().toString(36)}-${stepId}`, kidId: kid!.id, routineId: routine!.id, stepId });
    setMessage(result.message ?? null);
    if (result.ok) {
      setOops(stepId);
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => setOops(null), 8000);
      const title = steps.find((step) => step.id === stepId)?.title ?? "";
      if (state.readAloud && isPreReader(kid!.ageBand)) speak(title, true);
    }
  }

  return (
    <ScrollView style={styles.screen} contentContainerStyle={[styles.pad, { paddingTop: 48, gap: 20 }]}>
      <Text style={[styles.muted, { color: character.color }]}>{character.name}</Text>
      <Text style={styles.h1}>{routine.name}</Text>
      {finished && run?.status === "pending_approval" && <Text style={styles.body}>{character.name} is waiting for a grown-up.</Text>}
      {finished && run?.status !== "pending_approval" && <Text style={styles.body}>Finished.</Text>}
      {!finished && current && (
        <View style={[styles.card, { gap: 16, minHeight: 280, justifyContent: "center" }]}>
          <Text style={{ fontSize: 28, lineHeight: 34, fontWeight: "500", color: colors.ink }}>{current.title}</Text>
          <Text style={styles.muted}>{current.stars} star{current.stars === 1 ? "" : "s"}</Text>
          <Pressable style={styles.kidButton} onPress={() => done(current.id)} accessibilityRole="button" accessibilityLabel={`Done, ${current.title}`}>
            <Text style={styles.kidButtonText}>Done</Text>
          </Pressable>
          {isPreReader(kid.ageBand) && (
            <Pressable onPress={() => speak(current.title, state.readAloud)} accessibilityRole="button">
              <Text style={styles.muted}>Read aloud</Text>
            </Pressable>
          )}
        </View>
      )}
      {oops && run && (
        <Pressable style={styles.secondary} onPress={() => { state.undoStep(run.id, oops); setOops(null); }} accessibilityRole="button">
          <Text style={styles.secondaryText}>Oops</Text>
        </Pressable>
      )}
      {message ? <Text style={styles.body}>{message}</Text> : null}
      <View style={{ flexDirection: "row", gap: 8 }}>
        {steps.map((step) => {
          const completion = run?.completions[step.id];
          const on = completion && !completion.undoneAt;
          return <View key={step.id} accessibilityLabel={on ? `${step.title} done` : step.title} style={{ width: 14, height: 14, borderRadius: 7, backgroundColor: on ? colors.accent : colors.line }} />;
        })}
      </View>
      <Pressable onPress={() => router.back()} accessibilityRole="button">
        <Text style={styles.muted}>Back to today</Text>
      </Pressable>
    </ScrollView>
  );
}
