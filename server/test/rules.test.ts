import { test } from "node:test";
import assert from "node:assert/strict";
import fixture from "./judge_fixture.json" with { type: "json" };
import { cleanName, outcome, rules } from "../src/rules.ts";

test("GDScript の RoundRules と同じ勝敗を返す", () => {
  let mismatches = 0;
  for (const c of fixture.cases) {
    const got = outcome(c.mine, c.theirs);
    if (got !== c.outcome) {
      mismatches++;
      if (mismatches <= 5) console.error("mismatch", c, got);
    }
  }
  assert.equal(mismatches, 0);
  assert.ok(fixture.cases.length > 1000);
});

test("名前は制御文字を除いて最大文字数で切り、空なら既定の名前", () => {
  assert.equal(cleanName("あいうえおかきくけこ"), "あいうえおかきく");
  assert.equal(cleanName(" \n\t"), rules.fallbackName);
  assert.equal(cleanName(42), rules.fallbackName);
  assert.equal(cleanName("ab\u0000c"), "abc");
});
