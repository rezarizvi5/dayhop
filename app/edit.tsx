import { useState } from "react";
import { Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { TEMPLATES } from "../src/data/templates";
import { useApp } from "../src/data/store";
import { styles } from "../src/ui/theme";

export default function EditRoutine() {
  const state = useApp();
  const kid = state.kids.find((item) => !item.archivedAt);
  const [message, setMessage] = useState<string | null>(null);
  const [name, setName] = useState("Custom");

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.pad}>
      <Text style={styles.h1}>Routines</Text>
      {state.routines.filter((routine) => !routine.archivedAt).map((routine) => (
        <View key={routine.id} style={styles.card}>
          <Text style={styles.h2}>{routine.name}</Text>
          <Text style={styles.muted}>{routine.steps.length} steps · version {routine.version}</Text>
          {routine.steps.map((step) => <Text key={step.id} style={styles.body}>{step.title}</Text>)}
        </View>
      ))}
      <Text style={styles.h2}>Templates</Text>
      {TEMPLATES.map((template) => (
        <Pressable
          key={template.id}
          style={styles.secondary}
          onPress={() => {
            if (!kid) return;
            const result = state.addRoutineFromTemplate(template.id, kid.id);
            setMessage(result.ok ? `Added ${template.name}.` : result.error === "PLAN_REQUIRED" ? "Free plan holds 3 routines per kid." : result.error ?? "");
          }}
          accessibilityRole="button"
        >
          <Text style={styles.secondaryText}>Add {template.name}</Text>
        </Pressable>
      ))}
      <TextInput style={styles.input} value={name} onChangeText={setName} accessibilityLabel="Custom routine name" />
      <Pressable
        style={styles.primary}
        onPress={() => {
          if (!kid) return;
          const result = state.saveRoutine({
            id: `custom-${Date.now().toString(36)}`,
            name,
            timeOfDay: "custom",
            days: 127,
            bonusStars: 3,
            requiresApproval: false,
            version: 0,
            kidIds: [kid.id],
            steps: [{ id: `s-${Date.now().toString(36)}`, title: "One step", iconKey: "sun", stars: 1, position: 0 }],
          }, 0);
          setMessage(result.ok ? "Custom routine saved." : result.error ?? "");
        }}
        accessibilityRole="button"
      >
        <Text style={styles.primaryText}>Save a custom routine</Text>
      </Pressable>
      {message ? <Text style={styles.body}>{message}</Text> : null}
    </ScrollView>
  );
}
