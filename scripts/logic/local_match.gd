class_name LocalMatch
extends RefCounted
## オフラインの1試合(GameDesign 5章)。プレイヤーは 0(手前)と 1(奥)。
## 固定間隔の tick() だけで進む決定論的なシミュレーション。同じ seed と同じ入力からは必ず同じ試合になる。
## 入力は flip() で溜め、次の tick() の頭で順に反転し record へ残す(Architecture 4.1節)。

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
	## 発動した効果。無ければ null。判定のときだけ入る。
	var my_effect: HandEffect
	var their_effect: HandEffect


var hands: Array[HandModel] = []
var state: MatchState
var phase := Phase.OVER
var record := MatchRecord.new()
var effects := ActiveEffects.new()
## start() からの tick 数。記録の時刻に使う。
var tick_count := 0
var _match_config: MatchConfig
var _judge: HandShapeJudge
var _effect_table: HandEffectTable
var _rng := RandomNumberGenerator.new()
var _phase_ticks := 0
var _segment := 0
## まだ適用していない反転(届いた順)。slot はプレイヤー × 指。
var _pending_slots := PackedByteArray()


func _init(match_config: MatchConfig, names: HandNameTable, effect_table: HandEffectTable) -> void:
	_match_config = match_config
	_effect_table = effect_table
	_judge = HandShapeJudge.new(names)
	for player in PLAYER_COUNT:
		hands.append(HandModel.new())
	state = MatchState.new(match_config)


static func slot_of(player: int, finger: int) -> int:
	return player * HandTypes.Finger.size() + finger


func start(match_seed: int) -> void:
	_rng.seed = match_seed
	record = MatchRecord.new()
	record.seed = match_seed
	tick_count = 0
	state = MatchState.new(_match_config)
	effects.reset()
	_start_round()


func can_operate() -> bool:
	return phase == Phase.CALLING


## 指を反転する。操作できない間は捨てる。
func flip(player: int, finger: HandTypes.Finger) -> void:
	if can_operate():
		push_flip(slot_of(player, finger))


## リプレイ用。記録された反転をそのまま次の tick() へ渡す。
func push_flip(slot: int) -> void:
	if slot >= 0 and slot < PLAYER_COUNT * HandTypes.Finger.size():
		_pending_slots.append(slot)


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
	_apply_effects()
	_pending_slots.clear()
	phase = Phase.CALLING
	_phase_ticks = 0
	round_started.emit()
	_enter_segment(0)


func _apply_effects() -> void:
	var delay := roundi(_effect_table.oversleep_delay_seconds * TICKS_PER_SECOND)
	for player in PLAYER_COUNT:
		var hand := hands[player]
		for finger in HandTypes.Finger.size():
			var sleepy := effects.is_oversleeping(player, finger)
			hand.delay_ticks[finger] = delay if sleepy else 0
		if effects.is_shot(player):
			var shot := _rng.randi_range(0, HandTypes.Finger.size() - 1)
			hand.set_state(shot as HandTypes.Finger, HandTypes.FingerState.CURLED)


func _apply_pending() -> void:
	var finger_count := HandTypes.Finger.size()
	for slot in _pending_slots:
		record.append(tick_count, slot)
		@warning_ignore("integer_division")
		var player := slot / finger_count
		hands[player].flip((slot % finger_count) as HandTypes.Finger)
	_pending_slots.clear()


func _tick_call() -> void:
	for hand in hands:
		hand.step()
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
	var mine := hands[0].states
	var theirs := hands[1].states
	var result := RoundResult.new()
	result.my_shape = HandShapeJudge.shape_of(mine)
	result.their_shape = HandShapeJudge.shape_of(theirs)
	result.my_name = _judge.hand_name(mine)
	result.their_name = _judge.hand_name(theirs)
	return result


func _finish_round() -> void:
	var result := _name_hands()
	result.outcome = RoundRules.outcome(result.my_shape, result.their_shape)
	state.record(result.outcome)
	effects.end_round()
	result.my_effect = _trigger_effect(0)
	result.their_effect = _trigger_effect(1)
	phase = Phase.RESULT
	_phase_ticks = 0
	round_judged.emit(result)


func _trigger_effect(player: int) -> HandEffect:
	var states := hands[player].states
	if HandShapeJudge.shape_of(states) != HandTypes.Shape.NAMED:
		return null
	var effect := _effect_table.effect_of(states)
	if effect != null:
		effects.trigger(player, effect, states)
	return effect
