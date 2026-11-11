// Pure text helpers for review-ai (no I/O, unit-tested in text_test.ts).

export const MAX_DRAFT = 900;

/** Removes quotes/markdown and caps the text at a sentence boundary. */
export function cleanDraft(raw: string, max = MAX_DRAFT): string {
  let text = raw
    .replace(/\*\*|__|^#+\s*/gm, "")
    .replace(/^["«“\s]+|["»”\s]+$/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (text.length <= max) return text;
  text = text.slice(0, max);
  const lastStop = Math.max(
    text.lastIndexOf(". "),
    text.lastIndexOf("! "),
    text.lastIndexOf("? "),
    text.endsWith(".") ? text.length - 1 : -1,
  );
  return lastStop > max / 2 ? text.slice(0, lastStop + 1) : text.trimEnd();
}

export interface SummaryJson {
  summary: string;
  strengths: string[];
  weaknesses: string[];
}

export function parseSummary(raw: string): SummaryJson {
  const cleaned = raw.replace(/^```(?:json)?\s*|\s*```$/g, "").trim();
  const parsed = JSON.parse(cleaned);
  const list = (value: unknown) =>
    Array.isArray(value)
      ? value
        .filter((v): v is string => typeof v === "string" && v.trim() !== "")
        .map((v) => v.trim())
        .slice(0, 4)
      : [];
  const summary = typeof parsed.summary === "string"
    ? parsed.summary.trim()
    : "";
  if (!summary) throw new Error("summary missing");
  return {
    summary,
    strengths: list(parsed.strengths),
    weaknesses: list(parsed.weaknesses),
  };
}
