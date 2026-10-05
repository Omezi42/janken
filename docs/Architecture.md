# Architecture(実装設計)

いまの構成だけを書く。大きくなったら節ごとに `docs/arch/NN_*.md` へ分け、このファイルは索引にする。

## 1章 ディレクトリ

| パス | 中身 |
|---|---|
| `scripts/` | ゲームのスクリプト。ロジック(`scripts/logic/` 想定)とUIを分ける |
| `scenes/` | `.tscn`。直接編集せず `tools/godot_apply_patch.gd` 経由で更新する |
| `assets/` | 手のイラスト・背景などの画像 |
| `server/` | Cloudflare Workers + Durable Objects のサーバー(TypeScript) |
| `docs/` | 仕様・設計・落とし穴・TODO |
| `tools/check.sh` | 検証の一括実行(gdformat → gdlint → ヘッドレステスト → 起動スモーク) |
| `tools/tests/run_tests.gd` | ヘッドレステストの入口 |
| `tools/godot_apply_patch.gd` | JSONのパッチで `.tscn` を編集する |
| `.agents/skills/headless-godot/` | ヘッドレスGodot運用の手順集(CLI・シーン編集・テスト・書き出し) |
| `gdlintrc` | gdlint の設定(既定値。`max-file-lines` 1000) |

## 2章 設計の方針

- じゃんけんの判定とラウンド進行は通信層に依存しないクラスに置き、ヘッドレステストで直接叩けるようにする(通信なしで仕様を検証できるため)。
- 勝敗に関わる判定はクライアントだけで確定させず、サーバーが両者の手を受け取ってから判定する(相手の手を見てから出す不正を防ぐため)。

## 3章 通信(Cloudflare)

- サーバーは Cloudflare Workers + Durable Objects。クライアント(Godot の Web 書き出し)とは `WebSocketPeer` でつなぐ(ブラウザから使え、サーバーから相手の手や結果を即時に送れるため)。
- **部屋 = Durable Object 1つ。**部屋が2人の接続・出した手・試合の進行を持ち、両者の手がそろってから判定して結果を2人へ送る。相手の手は結果と一緒に初めて送る。
- **合言葉**: 合言葉から部屋を引く(`idFromName`)。同じ合言葉の2人が同じ部屋に入る。
- **ランダムマッチ**: 待ち行列用の Durable Object 1つが待っている人を2人ずつ組み、新しい部屋のIDを両者へ返す。
- サーバーのコードは `server/`(TypeScript)に置く。判定ルールはクライアントとサーバーの両方に要るため、テストで両者の結果が一致することを確かめる。
- ゲーム本体(Web 書き出し)は Cloudflare Pages で配信する。
