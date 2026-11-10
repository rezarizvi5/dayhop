import { useState } from "react";
import { Modal, Pressable, Text, TextInput, View } from "react-native";
import { useApp } from "../data/store";
import { colors, styles } from "./theme";

export function Gate({ visible, onClose, onSuccess }: { visible: boolean; onClose: () => void; onSuccess: () => void }) {
  const checkPin = useApp((s) => s.checkPin);
  const [pin, setPin] = useState("");
  const [message, setMessage] = useState<string | null>(null);

  function submit(next: string) {
    const result = checkPin(next);
    if (result.ok) {
      setPin("");
      setMessage(null);
      onSuccess();
      return;
    }
    setPin("");
    setMessage(result.message ?? "That PIN does not match.");
  }

  return (
    <Modal visible={visible} animationType="fade" transparent onRequestClose={onClose}>
      <View style={{ flex: 1, backgroundColor: "rgba(11,12,14,0.45)", justifyContent: "center", padding: 24 }}>
        <View style={[styles.card, { gap: 12 }]}>
          <Text style={styles.h2}>Parent gate</Text>
          <Text style={styles.body}>Enter the 4-digit PIN.</Text>
          <TextInput
            value={pin}
            onChangeText={(value) => {
              const next = value.replace(/\D/g, "").slice(0, 4);
              setPin(next);
              if (next.length === 4) submit(next);
            }}
            keyboardType="number-pad"
            secureTextEntry
            maxLength={4}
            accessibilityLabel="PIN"
            style={styles.input}
          />
          <Text accessibilityLiveRegion="polite" style={styles.muted}>{message ?? " "}</Text>
          <Pressable style={styles.secondary} onPress={onClose} accessibilityRole="button">
            <Text style={styles.secondaryText}>Close</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

export function speak(text: string, enabled: boolean) {
  if (!enabled || typeof window === "undefined" || !window.speechSynthesis) return;
  window.speechSynthesis.cancel();
  window.speechSynthesis.speak(new SpeechSynthesisUtterance(text));
}

export const gateColors = colors;
