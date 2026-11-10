import { Redirect } from "expo-router";
import { useApp } from "../src/data/store";

export default function Index() {
  const onboardStep = useApp((s) => s.onboardStep);
  const pinHash = useApp((s) => s.pinHash);
  const kidMode = useApp((s) => s.kidMode);
  const deleted = useApp((s) => s.deleted);
  if (deleted || onboardStep < 8 || !pinHash) return <Redirect href="/welcome" />;
  if (kidMode) return <Redirect href="/kid" />;
  return <Redirect href="/home" />;
}
