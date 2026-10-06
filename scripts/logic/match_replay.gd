class_name MatchReplay
extends RefCounted
## MatchRecord を LocalMatch へ流し込んで試合を再現する(Architecture 4.1節)。ボットも人の入力も使わない。

var _match: LocalMatch
var _record: MatchRecord
var _cursor := 0


func _init(local_match: LocalMatch, record: MatchRecord) -> void:
	_match = local_match
	_record = record


func start() -> void:
	_cursor = 0
	_match.start(_record.seed)


func tick() -> void:
	while _cursor < _record.size() and _record.ticks[_cursor] <= _match.tick_count:
		_match.push_flip(_record.slots[_cursor])
		_cursor += 1
	_match.tick()


func is_finished() -> bool:
	return _match.phase == LocalMatch.Phase.OVER
