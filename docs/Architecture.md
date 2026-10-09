# Architecture(実装設計)

いまの構成だけを書く。大きくなったら節ごとに `docs/arch/NN_*.md` へ分け、このファイルは索引にする。

## 1章 ディレクトリ

| パス | 中身 |
|---|---|
| `scripts/logic/` | 通信にもUIにも依存しないゲームロジック(4章) |
| `scripts/data/` | Resource の定義(5章) |
| `scripts/net/` | 通信(3章)。ロジック層を使い、表示層には依存しない |
| `scripts/ui/` | 表示・入力・画面の流れ(6章) |
| `data/` | Resource の初期値(`.tres`) |
| `scenes/` | `.tscn`。直接編集せず `tools/godot_apply_patch.gd` 経由で更新する |
| `server/` | Cloudflare Workers + Durable Objects のサーバー(TypeScript。3章) |
| `docs/` | 仕様・設計・落とし穴・TODO |
| `tools/check.sh` | 検証の一括実行(gdformat → gdlint → ヘッドレステスト → 起動スモーク) |
| `tools/tests/run_tests.gd` | ヘッドレステストの入口 |
| `tools/godot_apply_patch.gd` | JSONのパッチで `.tscn` を編集する |
| `tools/export_rules.gd` | `.tres` からサーバー用のルール `server/src/rules.json` と、判定一致テストの答え `server/test/judge_fixture.json` を書き出す(3.3節) |
| `tools/online_match_test.gd` | ローカルのサーバーへ2クライアントをつなぎ、ボット同士で試合を通す(3.4節) |
| `tools/bot_match.gd` | 画面なしでボット同士の試合・リプレイを回し、ラウンドごとの手と記録の文字列を出す(4.1節) |
| `.agents/skills/headless-godot/` | ヘッドレスGodot運用の手順集(CLI・シーン編集・テスト・書き出し) |
| `gdlintrc` | gdlint の設定(既定値。`max-file-lines` 1000) |

## 2章 設計の方針

- じゃんけんの判定とラウンド進行は通信層に依存しないクラスに置き、ヘッドレステストで直接叩けるようにする(通信なしで仕様を検証できるため)。
- 勝敗に関わる判定はクライアントだけで確定させず、サーバーが「ぽん」の時刻に持っている両者の手で判定する。
- 縦向きのみ: 基準解像度 720×1280、stretch mode `canvas_items`、aspect `keep_width`(縦に長い端末では上下へ広げ、横長のウィンドウでは左右に余白を付けるため)。
- 数値は `.tres` に置く(5章)。

## 3章 通信(Cloudflare)

- サーバーは Cloudflare Workers + Durable Objects(`server/`、TypeScript)。クライアントとは `WebSocketPeer` でつなぎ、JSON のテキストを送り合う(ブラウザから使え、サーバーから相手の手や結果を即時に送れるため)。
- 部屋は Durable Object 1つで、2人の接続・両者の曲がり具合・試合の進行を持つ。判定はすべて部屋が行い、クライアントは結果を表示するだけ。
- ゲーム本体(Web 書き出し)は Cloudflare Pages で配信する。

### 3.1 経路とマッチング

| 経路 | 行き先 |
|---|---|
| `/lobby` | 待ち行列の Durable Object(`idFromName("lobby")` の1つ) |
| `/room/<部屋名>` | 部屋の Durable Object(`idFromName(部屋名)`)。合言葉は `p` + 4桁、ランダムマッチは `r` + UUID |

- **ランダムマッチ**: `/lobby` につないで待つ。2人そろうと、待ち行列が新しい部屋名を両者へ送って切る。クライアントはその部屋へつなぎ直す。
- **合言葉**: `/room/p<4桁>` へ直接つなぐ。3人目には `full` を送って切る。
- 部屋は試合が終わる(または誰かが切れる)と両者の接続を切り、空に戻る。「もう一度」は同じ経路でつなぎ直すだけ。

### 3.2 メッセージ

`t` が種類。`mine` / `theirs` は受け取る側から見た自分・相手の曲がり具合(5要素、0〜100)。時刻はサーバーの UNIX ミリ秒。

| 向き | `t` | 中身 | いつ |
|---|---|---|---|
| C→S | `hello` | `name` | 部屋につないだ直後 |
| C→S | `ping` | `id` | 部屋につないだ直後に数回(時計合わせ) |
| C→S | `move` | `f`(指)・`c`(曲がり具合) | 掛け声の間、自分の指を動かすたび |
| S→C | `pong` | `id`・`now` | `ping` への返事 |
| S→C | `matched` | `room` | 待ち行列: 相手が見つかった |
| S→C | `full` | | 合言葉の部屋がふさがっている |
| S→C | `match` | `opponent`(相手の名前) | 部屋に2人そろった |
| S→C | `round` | `at`(掛け声の始まり)・`mine`・`theirs`(初期配置) | 試合開始時と、各判定の直後(次のラウンドの予定) |
| S→C | `move` | `f`・`c` | 相手が指を動かした(部屋が受け入れた値) |
| S→C | `called` | `mine`・`theirs` | 手の名前を呼ぶ区間の始まり。名前はクライアントが曲がり具合から付ける |
| S→C | `judged` | `mine`・`theirs`・`outcome`(`win`/`lose`/`draw`)・`wins`(`[自分, 相手]`) | 「ぽん」の区間の終わり |
| S→C | `left` | | 試合中に相手が切れた(受け取った側の不戦勝) |

- **時刻**: 部屋は `round.at` から `MatchConfig` の区間の秒数を足して、名前を呼ぶ時刻と判定の時刻を出し、`setTimeout` で動く(tick を回し続けないため)。
  次のラウンドの `at` は判定の時刻 + 結果の表示時間。最初のラウンドは2人そろってから `match_start_delay_seconds` 後。
- **時計合わせ**: クライアントは `ping` の往復が一番短かった回から、サーバー時刻と手元の時刻の差を出し、`at` を手元の時刻へ直して掛け声を進める。
- **手の同期**: 自分の手は手元ですぐ動かして `move` を送る(操作の遅延を無くすため)。部屋は掛け声の間だけ受け入れ、相手へ中継する。
- **不正対策**: 部屋はプレイヤーごとに、曲がり具合を動かせる量をトークンバケツ(毎秒 `move_rate_per_second` 回復、上限 `move_burst`)で制限し、
  足りない分は途中までしか動かさない(改造クライアントが一瞬で完璧な形を送るのを防ぐ)。手元の形とずれても、判定の瞬間に `judged` の形へ揃う。
- **効果**: サーバーは効果を扱わない(効果の表が空のため)。`tools/export_rules.gd` は効果の表に行があると失敗する(表へ戻すときにサーバーも直すため)。
- **名前**: 部屋は `hello.name` を `name_max_length` 文字に切り、空なら既定の名前にする。

### 3.3 ルールの共有

- サーバーは `.tres` を読めないため、`tools/export_rules.gd` が判定に要る値(勝ち数・掛け声の秒数・名前を呼ぶ区間・結果の表示時間・閾値・系統の区切り・勝ち条件・通信の数値)を
  `server/src/rules.json` へ書き出す。手の名前はサーバーに要らない(曲がり具合を送ってクライアントが名前を付けるため)。
- 判定のロジック(指の状態・形・系統・勝ち条件・勝敗)だけは `server/src/rules.ts` に GDScript と同じものを書く。
  `export_rules.gd` が乱数の曲がり具合の組と `RoundRules` の勝敗を `server/test/judge_fixture.json` へ書き出し、`node --test` で TypeScript の答えと突き合わせる。
- 両方の JSON は生成物だが commit する(`wrangler` と `node --test` が Godot なしで動くように)。`check.sh` が毎回作り直す。

### 3.4 検証

- `server/src/room_match.ts`(部屋の試合の進行。時刻を引数で受け、送るメッセージを返すだけ)は `node --test` で直接確かめる。Durable Object はそれに接続と `setTimeout` を足すだけ。
- `tools/online_match_test.gd` は `wrangler dev` に2クライアント(`OnlineMatch` + `HandBot`)をつなぎ、ランダムマッチで1試合を通す(両者の結果が裏返しで一致し、
  `judged` の形を手元の `RoundRules` で判定しても同じ勝敗になること)。合言葉では3人目が `full` になること、試合中に切れたら相手に `left` が届くことを確かめる。
- `check.sh` は `server/` `scripts/net/` `scripts/logic/` `data/` に変更があるとき(または `--all`)、`wrangler dev` を立ててこのテストを回す。

## 4章 ロジック層(オフラインでテストする)

| クラス | 責務 |
|---|---|
| `HandTypes` | 指・指の状態(伸び/曲がり/中途半端)・手の形(グー/チョキ/パー/名前付き/反則)・系統・勝ち条件の種類・勝敗・効果の種類の列挙 |
| `HandModel` | 5本の指の曲がり具合 `curls`(0〜`CURL_MAX` の整数。浮動小数を避けて記録・通信・リプレイを一致させるため)。`move(指, 曲がり具合)` で動かす。寝坊した指(`delay_ticks` が正)は予約し、`step()`(1tick)でその tick 数が経ってから動かす。`settled_curl(指)` は予約を済ませた後の曲がり具合。初期配置は `randomize_pose(rng)`、サーバーから受けた配置は `set_pose()`、ピストルは `set_curl()` |
| `HandShapeJudge` | 曲がり具合 → 指の状態(`HandRuleTable` の閾値)、指の状態 → 手の形・系統、曲がり具合 → 名前(反則は0.5で寄せて「ほぼ」「ゆるい」を付ける)、手の勝ち条件の文 |
| `RoundRules` | 2つの手の指の状態から勝敗(勝ち/負け/あいこ)を返す。反則を先に見て、残りは両者の勝ち条件(`HandRuleTable`)を満たすかで決める |
| `MatchState` | 勝利数と試合終了の判定 |
| `MatchSession` | `LocalMatch` と `OnlineMatch` の共通の型。シグナル(`round_started` / `call_segment_changed` / `hands_called` / `round_judged` / `match_finished`)・`RoundResult`・`Phase`・`hands` / `state` / `effects` / `judge`・`can_operate()` / `move()` / `tick()`・両者の名前 `player_names` を持つ(画面とボットがどちらの試合も同じに扱うため) |
| `ActiveEffects` | 掛かっている効果と残りラウンド数(モザイクを掛けられている手・寝坊している指・撃たれる手)。`trigger()` で発動、`end_round()` で1ラウンド減らす |
| `LocalMatch` | `MatchSession`。オフラインの1試合(プレイヤー0・1)。`start(seed)` と固定間隔の `tick()` だけで掛け声(手の名前を呼ぶ区間で `hands_called`)→ 判定と効果の発動 → 結果表示 → 次のラウンド(効果を初期配置・`delay_ticks` へ反映)を進め、シグナルで知らせる。入力は `move(プレイヤー, 指, 曲がり具合)` で受ける(4.1節)。判定に使う `judge` と `rules` を表示層へも見せる |
| `HandBot` | 開発用の仮の相手。ラウンドごとに勝ち条件を持つ手(本家を含む)から1つ選び、人と同じ `MatchSession.move()` で、食い違う指を1本ずつ、人がつかんで引く程度の時間を掛けて伸びきり・曲がりきりへ動かす。ときどき引き足りずに途中で離す(中途半端が残る)。「ぽん」の区間に入ると、ときどき相手の手に勝つ手のうち直す指が一番少ない手へ組み替える(モザイク中は見ない)。`tick()` の直前に `think()` を呼ぶ。乱数は試合と別に持つ |
| `MatchRecord` | 1試合の記録(seed と tick ごとの指の動き)。`to_text()` / `from_text()` で1行の文字列と相互変換する |
| `MatchReplay` | `MatchRecord` を `LocalMatch` へ流し込んで試合を再現する |

指の状態は親指から小指の順の型無し `Array`(`HandTypes.FingerState`)、曲がり具合は `PackedInt32Array` で渡す(型付き配列の落とし穴を避けるため)。

### 4.1 決定論とリプレイ

seed と入力の列から試合を完全に再現できるようにする(不具合の再現・ボットの検証・リプレイのため)。

- **固定 tick**: `LocalMatch` は 60tick/秒の `tick()` だけで進む。実時間の delta は表示層が tick へ刻む。時間は tick 数で数える。
- **乱数**: 試合の乱数(初期配置・ピストルで撃つ指)は `start(seed)` で seed した `LocalMatch` 専用の RNG だけを使う。ボットは別の RNG を持つ。
- **入力**: `move()` は届いた順に溜めるだけ(同じ指が続いても全部残す)。次の `tick()` の頭で、プレイヤー×指(slot)を
  順に動かし、(tick, slot, 曲がり具合)を `record` へ残す。
- **リプレイ**: `MatchReplay` が記録の動きを `push_move()` で同じ tick に入れる。ボットも人の入力も動かさない
  (ボットを作り直しても古い記録が再現できるため)。
- **文字列**: `"JK<版>." + base64(deflate(var_to_bytes({seed, ticks, slots, curls})))`。1試合で1〜数KB。
  記録の形式を変えたら `MatchRecord.FORMAT_VERSION` を上げる。`.tres` の数値やロジックを変えると古い記録は別の試合になる。
- **検証**: `replay_tests.gd` がボット戦 → 文字列化 → 読み戻し → リプレイで、全ラウンドの手・勝利数・最後の指の状態・記録し直した文字列の一致を確かめる。
  `tools/bot_match.gd` で画面なしにボット同士を何試合でも回せる(`-- --matches=10 --seed=1`、`-- --replay=<文字列>`)。
- オンライン対戦は対象外(手の同期・判定はサーバーが持つ。3章)。

### 4.2 通信のクライアント(`scripts/net/`)

| クラス | 責務 |
|---|---|
| `NetClient` | `WebSocketPeer` の薄い包み。`open(url)`・`poll()`・`send(dict)`、受け取った JSON を `message` シグナルで、切れたら `closed` で知らせる。部屋では時計合わせ(`ping`)を行い、`to_local_msec(サーバー時刻)` を出す |
| `Matchmaker` | 待ち行列 → 部屋、または合言葉の部屋へつなぎ、`hello` を送って `match` を待つ。`matched(net, 相手の名前)` / `failed(理由)` を出す。`poll()` を毎フレーム呼ぶ |
| `OnlineMatch` | `MatchSession`。つながった `NetClient` を受け、`round` の時刻に掛け声を始め、`called` / `judged` を手元の区間が追いついてから知らせる。判定で両者の手を `judged` の形へ揃え、勝敗は `judged.outcome` を `MatchState` へ記録する。`left` で不戦勝、自分の接続が切れたら `connection_lost` |

時刻は `Time.get_ticks_msec()`(実時間)で進める。オンラインの試合は決定論・リプレイの対象外。

## 5章 データ(Resource)

| Resource | 中身 | 仕様 |
|---|---|---|
| `MatchConfig` | 勝利に必要な勝ち数、掛け声の各区間の秒数と文字、手の名前を呼ぶ区間の番号、結果の表示時間 | GameDesign 5章 |
| `HandNameTable` | 5本の指の状態パターン → 名前(グー・チョキ・パーを含む32通り)、反則の名前の付け方(「ほぼ」「ゆるい」・グニャグニャ) | GameDesign 2.4節 |
| `HandRuleTable` / `HandCondition` | 指の状態の閾値(伸び・曲がり)、系統の本数の区切り、指の状態パターン → 勝ち条件(種類・値・表示の文)、勝ち条件なしの表示の文 | GameDesign 2.1〜2.3節 |
| `OnlineConfig` | サーバーの URL、名前の最大文字数と既定の名前、ボットの名前、合言葉の桁数、時計合わせの回数、最初のラウンドまでの秒数、指を動かせる量の上限 | GameDesign 4章・9章 |
| `HandEffectTable` / `HandEffect` | 指の状態パターン → 効果(種類・続くラウンド数・結果表示の文)、寝坊した指の遅れ(秒)。寝坊する指はパターンの曲がった指から決める。`effect_of(states)` で引く | なし(表は空) |

- `data/hand_rule_table.tres` は本家の3行だけ、`data/hand_effect_table.tres` は空にしている(名前付きの手に勝ち条件・効果を持たせない仕様のため)。
  勝ち条件の種類と効果の仕組み(`HandCondition` の各種類・`ActiveEffects`・モザイク・寝坊・ピストル)はコードに残し、表へ行を足せば動く(後で戻せるようにするため)。
  それらのテストは `tools/tests/fixtures/` の表(名前付きの手の行を持つ)を読む。

サーバーへは `tools/export_rules.gd` で JSON にして渡す(3.3節)。

## 6章 表示・入力層

絵はすべてコードで描く(画像を使わない)。見た目の数値(大きさ・色・揺れ)は表示層の const に置き、ロジックへ渡さない。

- `HandView`: `HandModel` を描画し、つかんで引いた指の曲がり具合が変わるたびに `finger_moved(指, 曲がり具合)` で知らせる(`HandModel` は直接動かさない。4.1節)。
  - つかむ: 押した位置から、いまの見た目の指(付け根から指先までの線分)への距離が一番近い指を、離すまでつかむ。
  - 引く: つかんだときの曲がり具合に、押した位置からの上下の移動(`PULL_DISTANCE` で 0.0〜1.0)を足す。
    つかんでいる間、その指の見た目はポインタに付いて動く。
  - ポインタは1つだけ(最初に押したマウスかタッチ)。タッチから作られたマウスの代わりのイベントは捨てる。
  - 入力の対応には演出を除いた手の位置を使う(拍で手が弾んでも、同じ位置なら同じ指をつかむため)。
  - 見た目の曲がり具合(0.0〜1.0)を指ごとに持ち、`HandModel` の曲がり具合へばねで追わせる(見た目だけ。ばねの数値は表示層の const)。
  - 中途半端な指は肌の色を変える。指の状態(`HandShapeJudge`)が変わった瞬間に火花を出す。
  - `facing_down` で上下を逆にして描く(相手の手)。演出は `reset_pose()`(ラウンド開始)・`beat()`(拍)・`show_result(勝敗)`(突き出し → 跳ねる/しぼむ/揺れる)で、
    Tween が `pose_offset` / `pose_scale` / `pose_tilt` / `modulate` を動かす。
  - `censored` ならモザイクで覆う。火花、つかんでいる指の光る縁(見た目だけ)を描く。
  - 指は付け根から指先までの直線に沿って太さの変わる管として描く。
- 相手の `HandView` は入力を受けず、受信した指の状態を表示するだけ。
- `App`(`scenes/main.tscn`、メインシーン): 画面を1つずつ子に置いて差し替える(GameDesign 9章)。プレイヤー名は `PlayerProfile`(`user://profile.cfg`)で読み書きする。
  開発用の起動引数があればタイトルを飛ばしてひとりで練習を始める。

| 画面 | 中身 |
|---|---|
| `TitleScreen` | 名前の入力欄(`LineEdit`)と「ランダムマッチ」「合言葉」「ひとりで練習」 |
| `PasscodeScreen` | 4つの枠とテンキー(0〜9・けす・けってい)、もどる |
| `WaitingScreen` | `Matchmaker` を回し、「さがしています…」と「やめる」。失敗は理由の文を出してタイトルへ |
| `BattleScreen` | 対戦(下記) |

- `BattleScreen`: 背景・両者の `HandView`・勝利数の星と名前・掛け声とランプ・結果と手の名前・効果の文・勝ち条件の札(`HandTag`)・「もう一度」「タイトルへ」を置く。
  `setup(session, bots)` で試合(`LocalMatch` か `OnlineMatch`)を受け取り、ボタンは `retry_requested` / `title_requested` で `App` へ返す。
  進行は試合が持ち、画面は実時間を tick へ刻んで回し(処理落ち時の追いつきは1フレーム8tickまで)、シグナルを受けて表示と演出(Tween)を変えるだけ。
  子ノードは `_ready()` でコードから組む(シーンにはルートだけを置く)。揺れは手と文字をまとめた入れ物を動かす。ひとりで練習では試合終了時に記録の文字列を標準出力へ出す。
  - 勝ち条件の札は毎フレーム両者の指の状態から決める。プレイヤーごとに直前の反則でない手の名前と勝ち条件の文を持ち、反則の間はそれを中途半端な指と同じ色で出す。
    光るかは `RoundRules.beats()`(両者とも反則でなく、相手にモザイクが掛かっていないときだけ)。札は名前のハンコとほぼ同じ所に置き、手の名前を呼ぶ区間は隠す。
- 演出用の部品(すべて入力を通す `MOUSE_FILTER_IGNORE`):

| クラス | 責務 |
|---|---|
| `BattleBackdrop` | 上下2色の背景と、判定の瞬間の集中線(`burst()`) |
| `UiStyle` | 画面で共通のボタン・文字・配置(`place()` は anchor へ直接入れる) |
| `ScreenFlash` | 画面全体を白く光らせて消す(`flash()`) |
| `StampLabel` | 文字を弾ませて出す(`pop()`)/ハンコのように押す(`stamp()`) |
| `BeatLamps` | 掛け声の区間の数だけのランプ |
| `WinStars` | 勝利に必要な数だけの星と、取った分の点灯 |
| `CensorTape` | 名前の上に貼る規制テープ(斜めの帯と文字) |
| `HandTag` | 手の名前(小)と勝ち条件の1行。光る(黄色・光った瞬間に弾む)/反則の間の色(中途半端な指と同じ)を描き分け、幅に収まらなければ小さくする |

- 開発用の起動引数(`godot --path . -- <引数>`): `--replay=<記録の文字列>` でその試合を再生、`--bot-vs-bot` で手前もボットにして観戦する。
