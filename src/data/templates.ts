export interface TemplateStep {
  title: string;
  iconKey: string;
  stars: number;
}

export interface RoutineTemplate {
  id: string;
  name: string;
  timeOfDay: "morning" | "afternoon" | "evening" | "custom";
  days: number;
  bonusStars: number;
  steps: TemplateStep[];
}

const weekday = 1 | 2 | 4 | 8 | 16;
const allWeek = 127;

export const TEMPLATES: RoutineTemplate[] = [
  {
    id: "morning",
    name: "Morning",
    timeOfDay: "morning",
    days: weekday,
    bonusStars: 3,
    steps: [
      ["Get up and make bed", "bed"],
      ["Brush teeth", "toothbrush"],
      ["Get dressed", "shirt"],
      ["Eat breakfast", "bowl"],
      ["Pack school bag", "bag"],
      ["Shoes on", "shoe"],
    ].map(([title, iconKey]) => ({ title, iconKey, stars: 1 })),
  },
  {
    id: "after-school",
    name: "After School",
    timeOfDay: "afternoon",
    days: weekday,
    bonusStars: 3,
    steps: [
      ["Unpack bag", "bag"],
      ["Snack and water", "apple"],
      ["Homework or reading", "book"],
      ["Tidy up", "basket"],
    ].map(([title, iconKey]) => ({ title, iconKey, stars: 1 })),
  },
  {
    id: "bedtime",
    name: "Bedtime",
    timeOfDay: "evening",
    days: allWeek,
    bonusStars: 3,
    steps: [
      ["Tidy toys", "blocks"],
      ["Bath or wash", "bath"],
      ["Pajamas on", "moon"],
      ["Brush teeth", "toothbrush"],
      ["Read a book", "book"],
      ["Lights out", "moon"],
    ].map(([title, iconKey]) => ({ title, iconKey, stars: 1 })),
  },
  {
    id: "chores",
    name: "Chores starter",
    timeOfDay: "custom",
    days: 32 | 64,
    bonusStars: 3,
    steps: [
      ["Set the table", "plate"],
      ["Feed the pet", "paw"],
      ["Put laundry away", "shirt"],
      ["Tidy your room", "basket"],
      ["Take out the trash", "bin"],
    ].map(([title, iconKey]) => ({ title, iconKey, stars: 1 })),
  },
];

export const CHARACTERS = [
  { id: "pip", name: "Pip", color: "#1f2de6" },
  { id: "bo", name: "Bo", color: "#d4552a" },
  { id: "juniper", name: "Juniper", color: "#2f7d4a" },
] as const;

export const ACCENTS = ["#1f2de6", "#d4552a", "#2f7d4a", "#b45309", "#0f6e8c", "#7a3e12", "#3f4c6b", "#8a3d55"];

export const AGE_BANDS = ["3-4", "5-6", "7-8", "9-10", "11+"] as const;

export function isPreReader(band: string): boolean {
  return band === "3-4" || band === "5-6";
}

const ICON_WORDS: Record<string, string[]> = {
  bed: ["bed", "sleep", "wake"],
  toothbrush: ["teeth", "brush", "hygiene"],
  shirt: ["clothes", "dress", "laundry"],
  bowl: ["breakfast", "food", "eat"],
  bag: ["school", "pack", "bag"],
  shoe: ["shoes", "feet"],
  apple: ["snack", "water", "food"],
  book: ["read", "homework", "book"],
  basket: ["tidy", "toys", "room"],
  bath: ["bath", "wash"],
  moon: ["bedtime", "pajamas", "lights"],
  plate: ["table", "meal"],
  paw: ["pet", "feed"],
  bin: ["trash", "chores"],
  hands: ["wash", "soap"],
  sun: ["morning", "outside"],
};

export const ICONS = Object.entries(ICON_WORDS).map(([key, words]) => ({ key, words }));
