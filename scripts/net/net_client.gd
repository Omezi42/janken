class_name NetClient
extends RefCounted
## WebSocketPeer の薄い包み(Architecture 4.2節)。JSON のテキストを送り合う。
## start_clock_sync() で ping を送り、往復の一番短い回からサーバー時刻と手元の時刻の差を出す。

signal opened
signal message(data: Dictionary)
signal closed

const PING := "ping"
const PONG := "pong"

var _socket := WebSocketPeer.new()
var _was_open := false
var _is_closed := false
## サーバー時刻 - 手元の時刻(ミリ秒)。
var _offset_msec := 0.0
var _best_round_trip := INF
var _pings_left := 0
var _ping_id := 0
var _ping_sent_at := 0


func open(url: String) -> bool:
	return _socket.connect_to_url(url) == OK


func close() -> void:
	_socket.close()


func is_open() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func send(data: Dictionary) -> void:
	if is_open():
		_socket.send_text(JSON.stringify(data))


func start_clock_sync(samples: int) -> void:
	_pings_left = samples
	_send_ping()


## サーバー時刻(UNIX ミリ秒)を Time.get_ticks_msec() の時刻へ直す。
func to_local_msec(server_msec: float) -> float:
	return server_msec - _offset_msec


## 毎フレーム呼ぶ。切れても、それまでに届いていたメッセージを先に知らせる。
func poll() -> void:
	if _is_closed:
		return
	_socket.poll()
	var ready_state := _socket.get_ready_state()
	if ready_state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		opened.emit()
	while _socket.get_available_packet_count() > 0:
		var data: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
		if data is Dictionary:
			_handle(data)
	if ready_state == WebSocketPeer.STATE_CLOSED:
		_is_closed = true
		closed.emit()


func _handle(data: Dictionary) -> void:
	if data.get("t") != PONG:
		message.emit(data)
		return
	if int(data.get("id", -1)) != _ping_id:
		return
	var now := Time.get_ticks_msec()
	var round_trip := now - _ping_sent_at
	if round_trip < _best_round_trip:
		_best_round_trip = round_trip
		_offset_msec = float(data.get("now", 0)) - (_ping_sent_at + round_trip / 2.0)
	_send_ping()


func _send_ping() -> void:
	if _pings_left <= 0:
		return
	_pings_left -= 1
	_ping_id += 1
	_ping_sent_at = Time.get_ticks_msec()
	send({"t": PING, "id": _ping_id})
