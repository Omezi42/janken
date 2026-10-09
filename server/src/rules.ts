// 判定のロジック(GameDesign 2.1〜2.3節)。scripts/logic/hand_shape_judge.gd・round_rules.gd と同じ答えを返す。
// 数値は tools/export_rules.gd が書き出した rules.json から読む(Architecture 3.3節)。
import rules from "./rules.json" with { type: "json" };

export { rules };

export type FingerState = "extended" | "curled" | "half";
export type Outcome = "win" | "lose" | "draw";
type Shape = "rock" | "scissors" | "paper" | "named" | "foul";
type Series = "rock" | "scissors" | "paper";

const FINGER_COUNT = 5;
// HandTypes.Series の並び。
const SERIES_ORDER: Series[] = ["rock", "scissors", "paper"];
const SCISSORS_STATES: FingerState[] = ["curled", "extended", "extended", "curled", "curled"];

type Condition = { kind: string; value: number };
const conditions: Record<string, Condition> = rules.conditions;

export function stateOf(curl: number): FingerState {
  const ratio = curl / rules.curlMax;
  if (ratio < rules.extendedBelow) return "extended";
  if (ratio > rules.curledAbove) return "curled";
  return "half";
}

export function statesOf(curls: number[]): FingerState[] {
  return curls.map(stateOf);
}

function count(states: FingerState[], state: FingerState): number {
  return states.filter((s) => s === state).length;
}

function shapeOf(states: FingerState[]): Shape {
  if (states.includes("half")) return "foul";
  if (count(states, "curled") === states.length) return "rock";
  if (count(states, "extended") === states.length) return "paper";
  if (states.every((s, i) => s === SCISSORS_STATES[i])) return "scissors";
  return "named";
}

function isOriginal(shape: Shape): boolean {
  return shape === "rock" || shape === "scissors" || shape === "paper";
}

function seriesOf(states: FingerState[]): Series {
  const extended = count(states, "extended");
  if (extended >= rules.paperMinExtended) return "paper";
  if (extended >= rules.scissorsMinExtended) return "scissors";
  return "rock";
}

function keyOf(states: FingerState[]): string {
  return states.map((s) => (s === "curled" ? rules.curledMark : rules.extendedMark)).join("");
}

// 反則でない手 mine の勝ち条件を、反則でない相手の手 theirs が満たすか。
function beats(mine: FingerState[], theirs: FingerState[]): boolean {
  const condition = conditions[keyOf(mine)];
  if (condition === undefined) return false;
  const theirShape = shapeOf(theirs);
  switch (condition.kind) {
    case "SERIES":
      return seriesOf(theirs) === SERIES_ORDER[condition.value];
    case "ORIGINAL":
      return isOriginal(theirShape);
    case "NAMED":
      return theirShape === "named";
    case "FINGER_CURLED":
      return theirs[condition.value] === "curled";
    case "FINGER_EXTENDED":
      return theirs[condition.value] === "extended";
    case "FEWER_EXTENDED":
      return count(theirs, "extended") < condition.value;
  }
  throw new Error(`知らない勝ち条件: ${condition.kind}`);
}

// mine から見た勝敗。
export function outcome(mineCurls: number[], theirCurls: number[]): Outcome {
  const mine = statesOf(mineCurls);
  const theirs = statesOf(theirCurls);
  const myFoul = shapeOf(mine) === "foul";
  const theirFoul = shapeOf(theirs) === "foul";
  if (myFoul || theirFoul) {
    if (myFoul === theirFoul) return "draw";
    return myFoul ? "lose" : "win";
  }
  const iWin = beats(mine, theirs);
  const theyWin = beats(theirs, mine);
  if (iWin === theyWin) return "draw";
  return iWin ? "win" : "lose";
}

// 初期配置(GameDesign 6.3節)。各指を半々で伸びきり・曲がりきり。
export function randomPose(random: () => number): number[] {
  return Array.from({ length: FINGER_COUNT }, () => (random() < 0.5 ? rules.curlMax : 0));
}

export function isFinger(value: unknown): value is number {
  return Number.isInteger(value) && (value as number) >= 0 && (value as number) < FINGER_COUNT;
}

export function clampCurl(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  return Math.min(Math.max(Math.round(value), 0), rules.curlMax);
}

// hello.name を整える(制御文字を除き、最大文字数で切る。空なら既定の名前)。
export function cleanName(value: unknown): string {
  const text = typeof value === "string" ? value : "";
  const chars = Array.from(text.replace(/\p{C}/gu, "").trim()).slice(0, rules.nameMaxLength);
  return chars.length > 0 ? chars.join("") : rules.fallbackName;
}
