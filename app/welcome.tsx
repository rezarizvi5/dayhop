import { useState } from "react";
import { Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { router } from "expo-router";
import { ACCENTS, AGE_BANDS, CHARACTERS, TEMPLATES } from "../src/data/templates";
import { useApp } from "../src/data/store";
import { styles } from "../src/ui/theme";

const SLIDES = [
  "A parent sets a morning, after-school or bedtime routine once.",
  "The child taps each step in Kid Mode and earns stars.",
  "You approve from your phone. Kids never get an account.",
];

export default function Welcome() {
  const state = useApp();
  const [slide, setSlide] = useState(0);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState(state.householdName);
  const [nickname, setNickname] = useState("");
  const [band, setBand] = useState<(typeof AGE_BANDS)[number]>("5-6");
  const [characterId, setCharacterId] = useState("pip");
  const [accent, setAccent] = useState(ACCENTS[0]);
  const [pin, setPin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [kidId, setKidId] = useState<string | undefined>(state.kids[0]?.id);

  function nextFromSlide() {
    if (slide < 2) setSlide(slide + 1);
    else state.setOnboard(1);
  }

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.pad}>
      {state.onboardStep === 0 && (
        <View style={{ gap: 16 }}>
          <Text style={styles.h1}>Routine app for parents</Text>
          <Text style={styles.body}>{SLIDES[slide]}</Text>
          <Pressable style={styles.primary} onPress={nextFromSlide} accessibilityRole="button">
            <Text style={styles.primaryText}>{slide < 2 ? "Next screen" : "Continue"}</Text>
          </Pressable>
          <Pressable onPress={() => state.setOnboard(1)} accessibilityRole="button">
            <Text style={styles.muted}>Skip the intro</Text>
          </Pressable>
          <Pressable
            style={styles.secondary}
            onPress={() => {
              state.loadSample();
              router.replace("/home");
            }}
            accessibilityRole="button"
          >
            <Text style={styles.secondaryText}>Preview Maya's morning</Text>
          </Pressable>
        </View>
      )}

      {state.onboardStep === 1 && (
        <View style={{ gap: 12 }}>
          <Text style={styles.h2}>Sign in</Text>
          <Text style={styles.body}>Apple and Google sign-in run in the iOS development build. This browser session uses email.</Text>
          <TextInput style={styles.input} autoCapitalize="none" autoComplete="email" value={email} onChangeText={setEmail} placeholder="Email" accessibilityLabel="Email" />
          <TextInput style={styles.input} secureTextEntry value={password} onChangeText={setPassword} placeholder="Password, 10 characters" accessibilityLabel="Password" />
          {error ? <Text style={styles.muted}>{error}</Text> : null}
          <Pressable
            style={styles.primary}
            onPress={() => {
              if (!email.includes("@") || password.length < 10) {
                setError("Use an email and a password of at least 10 characters.");
                return;
              }
              setError(null);
              state.setOnboard(2);
            }}
            accessibilityRole="button"
          >
            <Text style={styles.primaryText}>Continue with email</Text>
          </Pressable>
          <Pressable style={styles.secondary} onPress={() => setError("Google is unavailable in this browser. Use email.")} accessibilityRole="button">
            <Text style={styles.secondaryText}>Continue with Google</Text>
          </Pressable>
          <Pressable style={styles.secondary} onPress={() => setError("Sign in with Apple needs the iOS app.")} accessibilityRole="button">
            <Text style={styles.secondaryText}>Sign in with Apple</Text>
          </Pressable>
        </View>
      )}

      {state.onboardStep === 2 && (
        <View style={{ gap: 12 }}>
          <Text style={styles.h2}>Are you 18 or older?</Text>
          <Pressable style={styles.primary} onPress={() => state.confirmAdult(true)} accessibilityRole="button">
            <Text style={styles.primaryText}>I am 18 or older</Text>
          </Pressable>
          <Pressable style={styles.secondary} onPress={() => { state.confirmAdult(false); setError("DayHop is for adults setting up a household."); }} accessibilityRole="button">
            <Text style={styles.secondaryText}>I am not</Text>
          </Pressable>
          {error ? <Text style={styles.body}>{error}</Text> : null}
        </View>
      )}

      {state.onboardStep === 3 && (
        <View style={{ gap: 12 }}>
          <Text style={styles.h2}>Household</Text>
          <TextInput style={styles.input} value={name} onChangeText={setName} placeholder="Household name" accessibilityLabel="Household name" />
          <Pressable style={styles.primary} onPress={() => state.setHousehold(name || "Our house", Intl.DateTimeFormat().resolvedOptions().timeZone || "America/New_York")} accessibilityRole="button">
            <Text style={styles.primaryText}>Save household</Text>
          </Pressable>
        </View>
      )}

      {state.onboardStep === 4 && (
        <View style={{ gap: 12 }}>
          <Text style={styles.h2}>Parental consent</Text>
          <Text style={styles.body}>DayHop stores a nickname, an age band, a character, an accent colour and activity. No photo, birthdate or surname. Policy version {state.policyVersion}.</Text>
          <Pressable style={styles.primary} onPress={() => state.recordConsent()} accessibilityRole="button">
            <Text style={styles.primaryText}>I consent</Text>
          </Pressable>
        </View>
      )}

      {state.onboardStep === 5 && (
        <View style={{ gap: 12 }}>
          <Text style={styles.h2}>First kid</Text>
          <TextInput style={styles.input} value={nickname} onChangeText={setNickname} placeholder="Nickname" accessibilityLabel="Nickname" />
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
            {AGE_BANDS.map((item) => (
              <Pressable key={item} onPress={() => setBand(item)} style={[styles.secondary, band === item && styles.primary, { minWidth: 72 }]}>
                <Text style={band === item ? styles.primaryText : styles.secondaryText}>{item}</Text>
              </Pressable>
            ))}
          </View>
          <View style={{ flexDirection: "row", gap: 8 }}>
            {CHARACTERS.map((item) => (
              <Pressable key={item.id} onPress={() => setCharacterId(item.id)} style={[styles.secondary, { borderColor: item.color }]}>
                <Text style={styles.secondaryText}>{item.name}</Text>
              </Pressable>
            ))}
          </View>
          <View style={{ flexDirection: "row", gap: 8 }}>
            {ACCENTS.slice(0, 4).map((item) => (
              <Pressable key={item} accessibilityLabel={`Accent ${item}`} onPress={() => setAccent(item)} style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: item, borderWidth: accent === item ? 3 : 0, borderColor: "#0b0c0e" }} />
            ))}
          </View>
          {error ? <Text style={styles.muted}>{error}</Text> : null}
          <Pressable
            style={styles.primary}
            onPress={() => {
              const result = state.addKid({ nickname, ageBand: band, characterId, accent });
              if (!result.ok) {
                setError(result.error === "PLAN_REQUIRED" ? "The free plan holds 2 kids." : result.error ?? "Check the nickname.");
                return;
              }
              setKidId(result.id);
              setError(null);
            }}
            accessibilityRole="button"
          >
            <Text style={styles.primaryText}>Add kid</Text>
          </Pressable>
        </View>
      )}

      {state.onboardStep === 6 && (
        <View style={{ gap: 12 }}>
          <Text style={styles.h2}>Choose a routine</Text>
          {TEMPLATES.map((template) => (
            <Pressable
              key={template.id}
              style={styles.card}
              onPress={() => {
                const result = state.addRoutineFromTemplate(template.id, kidId ?? state.kids[0]?.id ?? "");
                if (!result.ok) setError(result.error ?? "Could not add that routine.");
              }}
              accessibilityRole="button"
            >
              <Text style={styles.h2}>{template.name}</Text>
              <Text style={styles.muted}>{template.steps.length} steps</Text>
            </Pressable>
          ))}
          {error ? <Text style={styles.muted}>{error}</Text> : null}
        </View>
      )}

      {state.onboardStep === 7 && (
        <View style={{ gap: 12 }}>
          <Text style={styles.h2}>Set a parent PIN</Text>
          <Text style={styles.body}>Four digits. 0000 and 1234 are rejected. The sample PIN in Preview is 2580.</Text>
          <TextInput style={styles.input} value={pin} onChangeText={setPin} keyboardType="number-pad" secureTextEntry maxLength={4} accessibilityLabel="New PIN" />
          {error ? <Text style={styles.muted}>{error}</Text> : null}
          <Pressable
            style={styles.primary}
            onPress={() => {
              const message = state.setPin(pin);
              if (message) setError(message);
              else router.replace("/home");
            }}
            accessibilityRole="button"
          >
            <Text style={styles.primaryText}>Save PIN</Text>
          </Pressable>
        </View>
      )}

      {state.onboardStep >= 8 && (
        <Pressable style={styles.primary} onPress={() => router.replace("/home")} accessibilityRole="button">
          <Text style={styles.primaryText}>Go to the household</Text>
        </Pressable>
      )}
    </ScrollView>
  );
}
