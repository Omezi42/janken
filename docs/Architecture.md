# Architecture(実装設計)

いまの構成だけを書く。大きくなったら節ごとに `docs/arch/NN_*.md` へ分け、このファイルは索引にする。

## 1章 ディレクトリ

| パス | 中身 |
|---|---|
| `scripts/` | ゲームのスクリプト。ロジック(`scripts/logic/` 想定)とUIを分ける |
| `scenes/` | `.tscn`。直接編集せず `tools/godot_apply_patch.gd` 経由で更新する |
| `assets/` | 手のイラスト・背景などの画像 |
| `docs/` | 仕様・設計・落とし穴・TODO |
| `tools/check.sh` | 検証の一括実行(gdformat → gdlint → ヘッドレステスト → 起動スモーク) |
| `tools/tests/run_tests.gd` | ヘッドレステストの入口 |
| `tools/godot_apply_patch.gd` | JSONのパッチで `.tscn` を編集する |
| `.agents/skills/headless-godot/` | ヘッドレスGodot運用の手順集(CLI・シーン編集・テスト・書き出し) |
| `gdlintrc` | gdlint の設定(既定値。`max-file-lines` 1000) |

## 2章 設計の方針

- じゃんけんの判定とラウンド進行は通信層に依存しないクラスに置き、ヘッドレステストで直接叩けるようにする(通信なしで仕様を検証できるため)。
- 勝敗に関わる判定はクライアントだけで確定させない(相手の手を見てから出す不正を防ぐため)。通信方式・サーバー構成は未決(`TODO.md`)。
