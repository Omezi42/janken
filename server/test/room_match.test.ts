import { test } from "node:test";
import assert from "node:assert/strict";
import { RoomMatch, type Message } from "../src/room_match.ts";
import { rules } from "../src/rules.ts";

type Sent = { player: number; message: Message };

const FINGERS = [0, 1, 2, 3, 4];
const MS = 1000;
const JUDGE_MS = rules.callSegmentSeconds.reduce((a, b) => a + b, 0) * MS;
// 動かせる量の上限に引っかからない間隔。
const MOVE_GAP_MS = 200;

function setup() {
  const sent: Sent[] = [];
  const state = { finished: 0 };
  let seed = 1;
  const random = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const room = new RoomMatch(
    { send: (player, message) => sent.push({ player, message }), finish: () => state.finished++ },
    random,
  );
  return { room, sent, state };
}

function last(sent: Sent[], player: number, t: string): Message | undefined {
  return sent.filter((s) => s.player === player && s.message.t === t).at(-1)?.message;
}

function roundAt(sent: Sent[]): number {
  return last(sent, 0, "round")!.at as number;
}

function startMatch(room: RoomMatch, now: number) {
  assert.equal(room.join(), 0);
  assert.equal(room.join(), 1);
  room.receive(0, { t: "hello", name: "あ" }, now);
  room.receive(1, { t: "hello", name: "い" }, now);
}

// 0 をパー、1 をグーにする。
function playPaperVsRock(room: RoomMatch, at: number) {
  for (const f of FINGERS) {
    room.receive(0, { t: "move", f, c: 0 }, at + MOVE_GAP_MS * f + 1);
    room.receive(1, { t: "move", f, c: rules.curlMax }, at + MOVE_GAP_MS * f + 1);
  }
}

test("3人目は入れない", () => {
  const { room } = setup();
  startMatch(room, 0);
  assert.equal(room.join(), null);
});

test("2人そろうと相手の名前と最初のラウンドを送る", () => {
  const { room, sent } = setup();
  startMatch(room, MS);
  assert.equal(last(sent, 0, "match")?.opponent, "い");
  assert.equal(last(sent, 1, "match")?.opponent, "あ");
  assert.equal(roundAt(sent), MS + rules.matchStartDelaySeconds * MS);
  assert.deepEqual(last(sent, 0, "round")!.mine, last(sent, 1, "round")!.theirs);
});

test("掛け声の間だけ動かせ、ぽんの時刻に部屋の手で判定する", () => {
  const { room, sent } = setup();
  startMatch(room, 0);
  const at = roundAt(sent);
  room.receive(0, { t: "move", f: 0, c: 50 }, at - 1);
  assert.equal(last(sent, 1, "move"), undefined, "掛け声の前は受け入れない");
  room.advance(at);
  playPaperVsRock(room, at);
  room.advance(at + JUDGE_MS - 1);
  assert.equal(last(sent, 0, "judged"), undefined, "ぽんの区間の終わりまでは判定しない");
  room.advance(at + JUDGE_MS);
  const j0 = last(sent, 0, "judged")!;
  const j1 = last(sent, 1, "judged")!;
  assert.equal(j0.outcome, "win");
  assert.equal(j1.outcome, "lose");
  assert.deepEqual(j0.wins, [1, 0]);
  assert.deepEqual(j1.wins, [0, 1]);
  room.receive(0, { t: "move", f: 0, c: rules.curlMax }, at + JUDGE_MS + 1);
  assert.equal(room.curls[0][0], 0, "判定の後は受け入れない");
  assert.equal(roundAt(sent), at + JUDGE_MS + rules.resultDisplaySeconds * MS);
});

test("一度に動かせる量を超えた分は途中まで", () => {
  const { room, sent } = setup();
  startMatch(room, 0);
  const at = roundAt(sent);
  room.advance(at);
  const before = [...room.curls[0]];
  for (const f of FINGERS) room.receive(0, { t: "move", f, c: rules.curlMax - before[f] }, at);
  const moved = room.curls[0].reduce((s, c, f) => s + Math.abs(c - before[f]), 0);
  assert.equal(moved, rules.moveBurst);
  assert.ok(last(sent, 1, "move"));
});

test("勝ち数に届いたら終わる", () => {
  const { room, sent, state } = setup();
  startMatch(room, 0);
  for (let round = 0; round < rules.winsToFinish * 2 && room.phase !== "over"; round++) {
    const at = roundAt(sent);
    room.advance(at);
    playPaperVsRock(room, at);
    room.advance(at + JUDGE_MS);
  }
  assert.equal(room.phase, "over");
  assert.deepEqual(room.wins, [rules.winsToFinish, 0]);
  assert.equal(state.finished, 1);
});

test("試合中に切れたら相手に left を送って終わる。始まる前なら席を空けるだけ", () => {
  const a = setup();
  startMatch(a.room, 0);
  a.room.leave(1, 10);
  assert.ok(last(a.sent, 0, "left"));
  assert.equal(a.state.finished, 1);
  const b = setup();
  assert.equal(b.room.join(), 0);
  b.room.leave(0, 0);
  assert.equal(b.state.finished, 0);
  assert.ok(b.room.isEmpty());
});

test("ping に部屋の時刻を返す", () => {
  const { room, sent } = setup();
  room.join();
  room.receive(0, { t: "ping", id: 3 }, 1234);
  assert.deepEqual(last(sent, 0, "pong"), { t: "pong", id: 3, now: 1234 });
});
