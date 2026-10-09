class_name Matchmaker
extends RefCounted
## 相手を見つけ、部屋に2人そろうまでつなぐ(GameDesign 4章、Architecture 3.1節)。
## ランダムマッチは待ち行列 → 部屋、合言葉は部屋へ直接。poll() を毎フレーム呼ぶ。

## net は部屋につながったまま渡す。以降は OnlineMatch が受ける。
signal matched(net: NetClient, opponent: String)
signal failed(reason: Reason)

enum Reason { UNREACHABLE, FULL }

const LOBBY_PATH := "/lobby"
const ROOM_PATH := "/room/"
const PASSCODE_ROOM_PREFIX := "p"

var _server_url: String
var _player_name: String
var _config: OnlineConfig
var _net: NetClient


func _init(server_url: String, player_name: String, config: OnlineConfig) -> void:
	_server_url = server_url
	_player_name = player_name
	_config = config


func find_random() -> void:
	_connect(LOBBY_PATH, _on_lobby_message, Callable())


func join_passcode(passcode: String) -> void:
	_enter_room(PASSCODE_ROOM_PREFIX + passcode)


func poll() -> void:
	if _net != null:
		_net.poll()


func cancel() -> void:
	if _net != null:
		_net.close()
		_net = null


func _connect(path: String, on_message: Callable, on_opened: Callable) -> void:
	var net := NetClient.new()
	_net = net
	net.message.connect(on_message)
	net.closed.connect(_on_closed.bind(net))
	if on_opened.is_valid():
		net.opened.connect(on_opened)
	if not net.open(_server_url + path):
		_fail(Reason.UNREACHABLE)


func _enter_room(room: String) -> void:
	_connect(ROOM_PATH + room, _on_room_message, _on_room_opened)


func _on_lobby_message(data: Dictionary) -> void:
	if data.get("t") == "matched":
		var lobby := _net
		_net = null
		lobby.close()
		_enter_room(str(data.get("room", "")))


func _on_room_opened() -> void:
	_net.send({"t": "hello", "name": _player_name})
	_net.start_clock_sync(_config.clock_sync_samples)


func _on_room_message(data: Dictionary) -> void:
	match data.get("t"):
		"match":
			var net := _net
			_net = null
			net.message.disconnect(_on_room_message)
			matched.emit(net, str(data.get("opponent", "")))
		"full":
			_fail(Reason.FULL)


## 渡し終えた・取り替えた接続が切れても知らせない。
func _on_closed(net: NetClient) -> void:
	if net == _net:
		_fail(Reason.UNREACHABLE)


func _fail(reason: Reason) -> void:
	cancel()
	failed.emit(reason)
