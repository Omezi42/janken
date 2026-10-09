class_name OnlineConfig
extends Resource
## オンライン対戦の数値(GameDesign 4章・7章・9章、Architecture 3章)。サーバーへは tools/export_rules.gd で渡す。

## 既定のサーバー(起動引数 --server= で上書きする)。
@export var server_url: String
@export var name_max_length: int
## 名前が空のとき、prefix + suffixes のどれか(例: ななしのグー)。
@export var default_name_prefix: String
@export var default_name_suffixes: Array[String] = []
## ひとりで練習の相手の名前。
@export var bot_name: String
@export var passcode_length: int
## 部屋につないだ直後に ping を送る回数。往復の一番短い回で時計を合わせる。
@export var clock_sync_samples: int
## 2人そろってから最初の掛け声までの秒数(時計合わせの間)。
@export var match_start_delay_seconds: float
## 指を動かせる量の上限(曲がり具合の合計。トークンバケツの毎秒の回復と上限)。
@export var move_rate_per_second: int
@export var move_burst: int
