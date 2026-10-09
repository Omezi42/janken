// 部屋1つの試合の進行(Architecture 3.2節)。時刻は引数で受け、送るものはコールバックへ渡すだけ(node --test で直接確かめるため)。
import { clampCurl, cleanName, isFinger, outcome, randomPose, rules, type Outcome } from "./rules.ts";

export const PLAYER_COUNT = 2;
const MS_PER_SECOND = 1000;
const FLIPPED: Record<Outcome, Outcome> = { win: "lose", lose: "win", draw: "draw" };

export type Message = Record<string, unknown>;
export type RoomCallbacks = {
  send: (player: number, message: Message) => void;
  // 試合が終わった・切れた。部屋は両者の接続を切って空に戻る。
  finish: () => void;
};

type Phase = "waiting" | "announced" | "calling" | "over";

type Bucket = { tokens: number; at: number };

function secondsToMs(seconds: number): number {
  return Math.round(seconds * MS_PER_SECOND);
}

function sum(values: number[]): number {
  return values.reduce((a, b) => a + b, 0);
}

const JUDGE_OFFSET_MS = secondsToMs(sum(rules.callSegmentSeconds));
const RESULT_MS = secondsToMs(rules.resultDisplaySeconds);
const START_DELAY_MS = secondsToMs(rules.matchStartDelaySeconds);

export class RoomMatch {
  phase: Phase = "waiting";
  wins = [0, 0];
  curls: number[][] = [[], []];
  private names: (string | null)[] = [null, null];
  private joined = [false, false];
  private roundAt = 0;
  private nextPoses: number[][] = [[], []];
  private buckets: Bucket[] = [];
  private callbacks: RoomCallbacks;
  private random: () => number;

  constructor(callbacks: RoomCallbacks, random: () => number) {
    this.callbacks = callbacks;
    this.random = random;
  }

  // 空いている席の番号。ふさがっていれば null。
  join(): number | null {
    if (this.phase !== "waiting") return null;
    const player = this.joined.indexOf(false);
    if (player < 0) return null;
    this.joined[player] = true;
    return player;
  }

  isEmpty(): boolean {
    return !this.joined.includes(true);
  }

  receive(player: number, message: Message, now: number): void {
    this.advance(now);
    switch (message.t) {
      case "ping":
        this.callbacks.send(player, { t: "pong", id: message.id, now });
        break;
      case "hello":
        this.hello(player, message.name, now);
        break;
      case "move":
        this.move(player, message.f, message.c, now);
        break;
    }
  }

  leave(player: number, now: number): void {
    this.advance(now);
    this.joined[player] = false;
    this.names[player] = null;
    if (this.phase === "waiting") return;
    if (this.phase !== "over") {
      this.callbacks.send(1 - player, { t: "left" });
      this.phase = "over";
    }
    this.callbacks.finish();
  }

  // 次に advance() を呼ぶべき時刻。無ければ null。
  nextWakeAt(): number | null {
    switch (this.phase) {
      case "announced":
        return this.roundAt;
      case "calling":
        return this.roundAt + JUDGE_OFFSET_MS;
    }
    return null;
  }

  advance(now: number): void {
    for (;;) {
      const wake = this.nextWakeAt();
      if (wake === null || now < wake) return;
      if (this.phase === "announced") {
        this.startRound();
      } else {
        this.judge();
      }
    }
  }

  private hello(player: number, name: unknown, now: number): void {
    if (this.phase !== "waiting" || this.names[player] !== null) return;
    this.names[player] = cleanName(name);
    if (this.names.includes(null)) return;
    for (let p = 0; p < PLAYER_COUNT; p++) {
      this.callbacks.send(p, { t: "match", opponent: this.names[1 - p] });
    }
    this.announceRound(now + START_DELAY_MS);
  }

  private announceRound(at: number): void {
    this.phase = "announced";
    this.roundAt = at;
    this.nextPoses = [randomPose(this.random), randomPose(this.random)];
    for (let p = 0; p < PLAYER_COUNT; p++) {
      this.callbacks.send(p, { t: "round", at, mine: this.nextPoses[p], theirs: this.nextPoses[1 - p] });
    }
  }

  private startRound(): void {
    this.phase = "calling";
    this.curls = this.nextPoses.map((pose) => [...pose]);
    this.buckets = this.curls.map(() => ({ tokens: rules.moveBurst, at: this.roundAt }));
  }

  // 掛け声の間だけ受け入れ、動かせる量の上限で途中までに抑えて相手へ中継する。
  private move(player: number, finger: unknown, curl: unknown, now: number): void {
    const target = clampCurl(curl);
    if (this.phase !== "calling" || !isFinger(finger) || target === null) return;
    const bucket = this.buckets[player];
    const refill = (rules.moveRatePerSecond * (now - bucket.at)) / MS_PER_SECOND;
    bucket.tokens = Math.min(rules.moveBurst, bucket.tokens + refill);
    bucket.at = now;
    const current = this.curls[player][finger];
    const allowed = Math.min(Math.abs(target - current), Math.floor(bucket.tokens));
    if (allowed <= 0) return;
    bucket.tokens -= allowed;
    const moved = current + Math.sign(target - current) * allowed;
    this.curls[player][finger] = moved;
    this.callbacks.send(1 - player, { t: "move", f: finger, c: moved });
  }

  private judge(): void {
    const first = outcome(this.curls[0], this.curls[1]);
    if (first !== "draw") this.wins[first === "win" ? 0 : 1]++;
    const outcomes = [first, FLIPPED[first]];
    for (let p = 0; p < PLAYER_COUNT; p++) {
      this.callbacks.send(p, {
        t: "judged",
        mine: this.curls[p],
        theirs: this.curls[1 - p],
        outcome: outcomes[p],
        wins: [this.wins[p], this.wins[1 - p]],
      });
    }
    if (this.wins.some((w) => w >= rules.winsToFinish)) {
      this.phase = "over";
      this.callbacks.finish();
      return;
    }
    this.announceRound(this.roundAt + JUDGE_OFFSET_MS + RESULT_MS);
  }
}
