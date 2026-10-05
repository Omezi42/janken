# 開発時の落とし穴(Pitfalls)

実装・検証で踏んだもの(砂時計PVPで踏んだもののうち、このプロジェクトにも当てはまるものを含む)。
**コードやシーンを触る前に一度読む。**新しく踏んだ穴はここへ足す(Architecture.md には書かない)。

### 検証の抜け

- **新しい `class_name` を持つスクリプトを追加した直後は `godot --headless --path . --import` を1度実行する。**
  `.godot/global_script_class_cache.cfg` へ登録されず、`--script` 起動が「Could not find type」で失敗する。
  `.godot/` はgit管理外のため、clone・pull直後も同じ。登録が古いとテストはコンパイルに失敗したまま**終了せずに固まる**。
  `check.sh` は足りない `class_name` を見つけると自動で `--import` する
- **`run/main_scene` が未設定のまま起動すると、エラーを出したあと終了せずに固まる。**`check.sh` は未設定の間スモークを飛ばす
- **`run_tests.gd` が読まないスクリプト(UIなど)のパースエラーは検出できない。**UIを触ったら起動スモークまで回す
- **GUIのクリックはヘッドレスでは届かない**(`push_input` しても `gui_get_hovered_control()` は none のまま)。押下の確認は非ヘッドレスで行う
- **`--headless` では実際のピクセルが得られない。**スクリーンショットは通常起動で撮る。
  短い演出を撮るときは `Engine.time_scale` を0.2程度へ落とす(保存のコストで撮り逃すため)
- **エクスポート済みpckに対してもテストを回す**
  (`godot --headless --main-pack build/web/index.pck --script res://tools/tests/run_tests.gd`)。
  `.tres` が `.tres.remap` になることによる差はこれでしか出ない

### データとコードの境目

- **`.tres` が保存する enum は整数。**途中へ値を挿入すると既存データが丸ごとずれる。新しい値は必ず末尾へ足す
- **`.tres` から `load()` した Resource を書き換えない。**同じインスタンスが返るため、全体へ変更が残る。対戦中の状態は別オブジェクトで持つ
- **`@export` の配列は `PackedStringArray` ではなく `Array[String]` にする。**エクスポート時の変換で中身が落ちる(書き出した版でだけ空になる)

### GDScript

- **型付き配列(`Array[String]`)を要求する関数へ untyped の `Array` を渡すと、実行時に関数ごと呼ばれない。**コンパイルは通る
- **ラムダは外側のローカル変数を値でキャプチャする。**外側へ代入しても伝わらない。`Array` / `Dictionary` でラップして要素へ代入する
- **シグナルの引数の数と受け手の引数の数がずれていても `connect()` は通る。**emit のたびにエラーが出て受け手が呼ばれないだけ
- **static だけのクラスに `reload()` など `Script` の組み込みメソッドと同名の関数を作らない。**`GDScript.reload()` が呼ばれ static var が初期化される
- **`var x := ProjectSettings.get_setting(...)` は Variant 推論の警告でコンパイルが落ちる。**`var x: Variant = ...` と明示する
- **`class_name` を持つ2つのスクリプトが、互いの const を const から参照してはいけない。**読み込みが循環して起動したまま固まる

### Godotの挙動

- **`set_anchors_preset()` は今の矩形を保つよう offset を計算し直す。**生成直後(サイズ0)のノードへ使うと0サイズで固定される。`anchor_*` へ直接代入する
- **`Control._draw()` は自分の子より背面に描かれる。**後から `add_child()` した子ほど手前。モーダル・暗幕は最後の子へ置く
- **`Label.autowrap_mode` は `size` より先に立てる。**コンテナ内で折り返す Label には `custom_minimum_size.x` を与える
- **`MOUSE_FILTER_PASS` はイベントを背面の兄弟ではなく親へ渡す。**全面に敷いたコンテナより前の子が押せなくなる
- **`.tscn` はテキストとして直接編集しない。**`tools/godot_apply_patch.gd` 経由で更新する。ルートにスクリプトを持つシーンを再生成するときは `root.set_script()` を忘れない

### Web版・オンライン

- **Web版で `AudioServer.add_bus()` を使ってはいけない。**Web版だけ全く鳴らなくなる。バスは `AudioServer.bus_count` を増やして足す
- **Web版は裏のタブへ回すとメインループごと止まる**(タイマーも `await` も進まない)。オンラインの心拍・ポーリングは
  「止まっている間に相手側から状態を消される」前提で書く。端末どうしの時刻比較は時計のずれで壊れるため、古さの判定はサーバー時刻同士で行う
- **通信失敗を「データが無い」と取り違えない。**空の応答を土台に書き戻すと既存データを上書きする。成功コードを確かめてから書く

### 触ってはいけないもの

- **`user://` 配下の実データに触らない。**テストで扱う場合は「控える → 上書き → 検証 → 戻す」の往復にする
