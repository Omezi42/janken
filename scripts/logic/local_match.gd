class_name LocalMatch
extends RefCounted
## オフラインの1試合(GameDesign 5章)。プレイヤーは 0(手前)と 1(奥)。
## 固定間隔の tick() だけで進む決定論的なシミュレーション。同じ seed と同じ入力からは必ず同じ試合になる。
## 入力は drag() で溜め、次の tick() の頭でステップ数へ丸めて適用し record へ残す(Architecture 4.1節)。

signal round_started
signal call_segment_changed(index: int)
## 手の名前を呼ぶ区間の始まり。call.outcome は使わない。
signal hands_called(call: RoundResult)
signal round_judged(result: RoundResult)
signal match_finished(winner: int)

enum Phase { CALLING, RESULT, OVER }

const TICKS_PER_SECOND := 60
const TICK_SECONDS := 1.0 / TICKS_PER_SECOND
const PLAYER_COUNT := 2


class RoundResult:
	var outcome: HandTypes.Outcome
	var my_shape: HandTypes.Shape
	var their_shape: HandTypes.Shape
	var my_name: String
	var their_name: String


var hands: Array[HandModel] = []
var state: MatchState
var phase := Phase.OVER
var record := MatchRecord.new()
## start() からの tick 数。記録の時刻に使う。
var tick_count := 0
var _match_config: MatchConfig
var _judge: HandShapeJudge
var _rng := RandomNumberGenerator.new()
var _phase_ticks := 0
var _segment := 0
## まだ適用していない曲がり具合の変化(ステップ単位)。並びは slot(プレイヤー × 指)。
var _pending_steps := PackedFloat64Array()


func _init(hand_config: HandConfig, match_config: MatchConfig, names: FoulNameTable) -> void:
	_match_config = match_config
	_judge = HandShapeJudge.new(hand_config, names)
	for player in PLAYER_COUNT:
		hands.append(HandModel.new(hand_config))
	_pending_steps.resize(PLAYER_COUNT * HandTypes.Finger.size())
	state = MatchState.new(match_config)


static func slot_of(player: int, finger: int) -> int:
	return player * HandTypes.Finger.size() + finger


func start(match_seed: int) -> void:
	_rng.seed = match_seed
	record = MatchRecord.new()
	record.seed = match_seed
	tick_count = 0
	state = MatchState.new(_match_config)
	_start_round()


func can_operate() -> bool:
	return phase == Phase.CALLING


## amount は曲がり具合の変化量(正で曲がる)。操作できない間は捨てる。
func drag(player: int, finger: HandTypes.Finger, amount: float) -> void:
	if can_operate():
		_pending_steps[slot_of(player, finger)] += amount * MatchRecord.STEPS_PER_CURL


## リプレイ用。記録されたステップ数をそのまま次の tick() へ渡す。
func push_steps(slot: int, step_count: int) -> void:
	if slot >= 0 and slot < _pending_steps.size():
		_pending_steps[slot] += step_count


func tick() -> void:
	match phase:
		Phase.CALLING:
			_apply_pending()
			_tick_call()
		Phase.RESULT:
			_phase_ticks += 1
			if _phase_seconds() >= _match_config.result_display_seconds:
				_end_result()
	tick_count += 1


func _end_result() -> void:
	if state.is_over():
		phase = Phase.OVER
		match_finished.emit(state.winner())
	else:
		_start_round()


func _start_round() -> void:
	for hand in hands:
		hand.randomize_pose(_rng)
	_pending_steps.fill(0.0)
	phase = Phase.CALLING
	_phase_ticks = 0
	round_started.emit()
	_enter_segment(0)


func _apply_pending() -> void:
	for slot in _pending_steps.size():
		var step_count := roundi(_pending_steps[slot])
		if step_count == 0:
			continue
		_pending_steps[slot] -= step_count
		record.append(tick_count, slot, step_count)
		@warning_ignore("integer_division")
		var player := slot / HandTypes.Finger.size()
		var finger := slot % HandTypes.Finger.size()
		hands[player].drag(
			finger as HandTypes.Finger, float(step_count) / MatchRecord.STEPS_PER_CURL
		)


func _tick_call() -> void:
	for hand in hands:
		hand.step(TICK_SECONDS)
	_phase_ticks += 1
	var segment := _match_config.call_segment_at(_phase_seconds())
	if segment >= _match_config.call_segment_seconds.size():
		_finish_round()
	elif segment != _segment:
		_enter_segment(segment)


func _enter_segment(segment: int) -> void:
	_segment = segment
	call_segment_changed.emit(_segment)
	if _segment == _match_config.hand_call_segment:
		hands_called.emit(_name_hands())


func _phase_seconds() -> float:
	return float(_phase_ticks) / TICKS_PER_SECOND


func _name_hands() -> RoundResult:
	var mine := hands[0].curls
	var theirs := hands[1].curls
	var result := RoundResult.new()
	result.my_shape = _judge.shape_of(mine)
	result.their_shape = _judge.shape_of(theirs)
	result.my_name = _judge.hand_name(mine)
	result.their_name = _judge.hand_name(theirs)
	return result


func _finish_round() -> void:
	var result := _name_hands()
	result.outcome = RoundRules.outcome(result.my_shape, result.their_shape)
	state.record(result.outcome)
	phase = Phase.RESULT
	_phase_ticks = 0
	round_judged.emit(result)
