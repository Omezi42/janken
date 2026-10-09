// 入口と Durable Object(Architecture 3.1節)。試合の進行は room_match.ts。
import { DurableObject } from "cloudflare:workers";
import { RoomMatch, type Message } from "./room_match.ts";

type Env = {
  LOBBY: DurableObjectNamespace<Lobby>;
  ROOM: DurableObjectNamespace<Room>;
};

const LOBBY_NAME = "lobby";
// 合言葉は p + 数字、ランダムマッチは r + UUID。
const ROOM_NAME = /^(p\d{1,8}|r[0-9a-f-]{36})$/;
const ROOM_PREFIX = "/room/";
const NORMAL_CLOSE = 1000;

function isWebSocket(request: Request): boolean {
  return request.headers.get("Upgrade")?.toLowerCase() === "websocket";
}

function accept(): { client: WebSocket; server: WebSocket } {
  const [client, server] = Object.values(new WebSocketPair());
  server.accept();
  return { client, server };
}

function upgraded(client: WebSocket): Response {
  return new Response(null, { status: 101, webSocket: client });
}

function sendJson(socket: WebSocket, message: Message): void {
  try {
    socket.send(JSON.stringify(message));
  } catch {
    // 切れた接続へは送らない。close イベントで片付く。
  }
}

function parse(data: unknown): Message | null {
  if (typeof data !== "string") return null;
  try {
    const value = JSON.parse(data);
    return typeof value === "object" && value !== null ? value : null;
  } catch {
    return null;
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (!isWebSocket(request)) return new Response("janken server", { status: 200 });
    const path = new URL(request.url).pathname;
    if (path === "/" + LOBBY_NAME) {
      return env.LOBBY.get(env.LOBBY.idFromName(LOBBY_NAME)).fetch(request);
    }
    if (path.startsWith(ROOM_PREFIX)) {
      const name = path.slice(ROOM_PREFIX.length);
      if (ROOM_NAME.test(name)) return env.ROOM.get(env.ROOM.idFromName(name)).fetch(request);
    }
    return new Response("not found", { status: 404 });
  },
};

// 待っている人を2人ずつ組み、新しい部屋名を送って切る。
export class Lobby extends DurableObject<Env> {
  private waiting: WebSocket[] = [];

  async fetch(): Promise<Response> {
    const { client, server } = accept();
    server.addEventListener("close", () => this.remove(server));
    server.addEventListener("error", () => this.remove(server));
    this.waiting.push(server);
    while (this.waiting.length >= 2) {
      const pair = this.waiting.splice(0, 2);
      const room = "r" + crypto.randomUUID();
      for (const socket of pair) {
        sendJson(socket, { t: "matched", room });
        socket.close(NORMAL_CLOSE);
      }
    }
    return upgraded(client);
  }

  private remove(socket: WebSocket): void {
    this.waiting = this.waiting.filter((s) => s !== socket);
  }
}

// 2人の試合。RoomMatch に時刻を渡し、次に動く時刻へ setTimeout を掛ける。
export class Room extends DurableObject<Env> {
  private sockets: (WebSocket | null)[] = [null, null];
  private match = this.newMatch();
  private timer: ReturnType<typeof setTimeout> | null = null;

  async fetch(): Promise<Response> {
    const { client, server } = accept();
    const player = this.match.join();
    if (player === null) {
      sendJson(server, { t: "full" });
      server.close(NORMAL_CLOSE);
      return upgraded(client);
    }
    this.sockets[player] = server;
    server.addEventListener("message", (event) => {
      const message = parse(event.data);
      if (message !== null && this.sockets[player] === server) {
        this.match.receive(player, message, Date.now());
        this.schedule();
      }
    });
    const leave = () => {
      if (this.sockets[player] !== server) return;
      this.sockets[player] = null;
      this.match.leave(player, Date.now());
      this.schedule();
    };
    server.addEventListener("close", leave);
    server.addEventListener("error", leave);
    return upgraded(client);
  }

  private newMatch(): RoomMatch {
    return new RoomMatch(
      {
        send: (player, message) => {
          const socket = this.sockets[player];
          if (socket !== null) sendJson(socket, message);
        },
        finish: () => this.finish(),
      },
      Math.random,
    );
  }

  private schedule(): void {
    if (this.timer !== null) clearTimeout(this.timer);
    this.timer = null;
    const wake = this.match.nextWakeAt();
    if (wake === null) return;
    this.timer = setTimeout(() => {
      this.match.advance(Date.now());
      this.schedule();
    }, Math.max(0, wake - Date.now()));
  }

  private finish(): void {
    const sockets = this.sockets;
    this.sockets = [null, null];
    this.match = this.newMatch();
    for (const socket of sockets) socket?.close(NORMAL_CLOSE);
  }
}
