// Run with: node --test supabase/functions/review-ai/text_test.ts
//      or: deno test supabase/functions/review-ai/text_test.ts
import assert from "node:assert/strict";
import { test } from "node:test";

import { cleanDraft, MAX_DRAFT, parseSummary } from "./text.ts";

test("cleanDraft strips quotes, markdown and extra whitespace", () => {
  assert.equal(
    cleanDraft('"**Great** movie.\n\nLoved   the score."'),
    "Great movie. Loved the score.",
  );
  assert.equal(cleanDraft("« Superbe film. »"), "Superbe film.");
});

test("cleanDraft caps at a sentence boundary", () => {
  const sentence = "This is a sentence of moderate length. ";
  const long = sentence.repeat(40);
  const result = cleanDraft(long);
  assert.ok(result.length <= MAX_DRAFT, `length ${result.length}`);
  assert.ok(result.endsWith("."), result.slice(-20));
});

test("cleanDraft hard-cuts text without sentence breaks", () => {
  const result = cleanDraft("word ".repeat(400));
  assert.ok(result.length <= MAX_DRAFT);
});

test("parseSummary reads fenced JSON and drops empty points", () => {
  const parsed = parseSummary(
    '```json\n{"summary":" Loved overall. ","strengths":["Acting",""," Music "],"weaknesses":"none"}\n```',
  );
  assert.deepEqual(parsed, {
    summary: "Loved overall.",
    strengths: ["Acting", "Music"],
    weaknesses: [],
  });
});

test("parseSummary rejects a missing summary", () => {
  assert.throws(() => parseSummary('{"strengths":[]}'));
  assert.throws(() => parseSummary("not json"));
});
