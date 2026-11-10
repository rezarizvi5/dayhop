import { Pressable, ScrollView, Text, View } from "react-native";
import { useApp } from "../src/data/store";
import { styles } from "../src/ui/theme";

export default function Inbox() {
  const state = useApp();
  const pending = state.runs.filter((run) => run.status === "pending_approval" || run.status === "reopened");
  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.pad}>
      <Text style={styles.h1}>Approvals</Text>
      {pending.length === 0 && <Text style={styles.body}>Nothing is waiting.</Text>}
      {pending.map((run) => {
        const kid = state.kids.find((item) => item.id === run.kidId);
        return (
          <View key={run.id} style={styles.card}>
            <Text style={styles.h2}>{kid?.nickname} · {run.steps.length} steps</Text>
            {run.steps.map((step) => (
              <Text key={step.id} style={styles.body}>{run.completions[step.id] && !run.completions[step.id].undoneAt ? "Done" : "Open"} · {step.title}</Text>
            ))}
            <Pressable style={styles.primary} onPress={() => state.approveRun(run.id, [])} accessibilityRole="button">
              <Text style={styles.primaryText}>Approve all</Text>
            </Pressable>
            <Pressable
              style={styles.secondary}
              onPress={() => state.approveRun(run.id, run.steps.map((step) => step.id))}
              accessibilityRole="button"
            >
              <Text style={styles.secondaryText}>Send back the steps</Text>
            </Pressable>
          </View>
        );
      })}
      <Text style={styles.h2}>Reward requests</Text>
      {state.redemptions.filter((item) => item.status === "requested").map((item) => (
        <View key={item.id} style={styles.card}>
          <Text style={styles.body}>{item.title} · {item.cost} stars</Text>
          <Pressable style={styles.primary} onPress={() => state.resolveRedemption(item.id, "fulfilled")} accessibilityRole="button">
            <Text style={styles.primaryText}>Fulfil</Text>
          </Pressable>
          <Pressable style={styles.secondary} onPress={() => state.resolveRedemption(item.id, "denied")} accessibilityRole="button">
            <Text style={styles.secondaryText}>Deny and refund</Text>
          </Pressable>
        </View>
      ))}
    </ScrollView>
  );
}
