const ALLOWED = /^[\p{L}\p{N} '\-]+$/u;
const FORBIDDEN = /[\u0000-\u001F\u007F\u202A-\u202E\u2066-\u2069]/u;

export function normalizeNickname(input: string): string {
  return input.normalize("NFC").trim().replace(/\s+/g, " ");
}

export function nicknameError(input: string): string | null {
  const value = normalizeNickname(input);
  if (value.length < 1 || value.length > 20) return "Use 1 to 20 characters.";
  if (FORBIDDEN.test(value)) return "That nickname has characters we cannot keep.";
  if (!ALLOWED.test(value)) return "Use letters, numbers, spaces, hyphen or apostrophe.";
  return null;
}
