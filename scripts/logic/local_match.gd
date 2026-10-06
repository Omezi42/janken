class_name LocalMatch
extends RefCounted
## オフラインの1試合(GameDesign 5章)。プレイヤーは 0(手前)と 1(奥)。
## 固定間隔の tick() だけで進む決定論的なシミュレーション。同じ seed と同じ入力からは必ず同じ試合になる。
## 入力は drag() / swing() で溜め、次の tick() の頭でステップ数へ丸めて適用し record へ残す(Architecture 4.1節)。

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
const AXIS_COUNT := 2


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
## まだ適用していない曲がり具合・向きの変化(ステップ単位)。並びは slot(プレイヤー × 量 × 指)。
var _pending_steps := PackedFloat64Array()


func _init(
	hand_config: HandConfig,
	match_config: MatchConfig,
	names: HandNameTable,
	effect_table: HandEffectTable
) -> void:
	_match_config = match_config
	_effect_table = effect_table
	_judge = HandShapeJudge.new(hand_config, names)
	for player in PLAYER_COUNT:
		hands.append(HandModel.new(hand_config))
	_pending_steps.resize(PLAYER_COUNT * AXIS_COUNT * HandTypes.Finger.size())
	state = MatchState.new(match_config)


static func slot_of(player: int, axis: HandTypes.Axis, finger: int) -> int:
	return (player * AXIS_COUNT + axis) * HandTypes.Finger.size() + finger


static func steps_per_unit(axis: HandTypes.Axis) -> int:
	if axis == HandTypes.Axis.CURL:
		return MatchRecord.STEPS_PER_CURL
	return MatchRecord.STEPS_PER_DEGREE


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


## amount は曲がり具合の変化量(正で曲がる)。操作できない間は捨てる。
func drag(player: int, finger: HandTypes.Finger, amount: float) -> void:
	_push(player, HandTypes.Axis.CURL, finger, amount)


## degrees は向きの変化量(正で時計回り)。操作できない間は捨てる。
func swing(player: int, finger: HandTypes.Finger, degrees: float) -> void:
	_push(player, HandTypes.Axis.SWING, finger, degrees)


func _push(player: int, axis: HandTypes.Axis, finger: HandTypes.Finger, amount: float) -> void:
	if can_operate():
		_pending_steps[slot_of(player, axis, finger)] += amount * steps_per_unit(axis)


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
	_apply_effects()
	_pending_steps.fill(0.0)
	phase = Phase.CALLING
	_phase_ticks = 0
	round_started.emit()
	_enter_segment(0)


func _apply_effects() -> void:
	for player in PLAYER_COUNT:
		var hand := hands[player]
		for finger in HandTypes.Finger.size():
			var sleepy := effects.is_oversleeping(player, finger)
			hand.drag_scales[finger] = _effect_table.oversleep_drag_scale if sleepy else 1.0
		if effects.is_shot(player):
			var shot := _rng.randi_range(0, HandTypes.Finger.size() - 1)
			hand.set_curl(shot as HandTypes.Finger, HandModel.MAX_CURL)


func _apply_pending() -> void:
	for slot in _pending_steps.size():
		var step_count := roundi(_pending_steps[slot])
		if step_count == 0:
			continue
		_pending_steps[slot] -= step_count
		record.append(tick_count, slot, step_count)
		var finger_count := HandTypes.Finger.size()
		@warning_ignore("integer_division")
		var axis_slot := slot / finger_count
		@warning_ignore("integer_division")
		var player := axis_slot / AXIS_COUNT
		var axis := (axis_slot % AXIS_COUNT) as HandTypes.Axis
		var amount := float(step_count) / steps_per_unit(axis)
		hands[player].move(axis, (slot % finger_count) as HandTypes.Finger, amount)


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
	effects.end_round()
	result.my_effect = _trigger_effect(0)
	result.their_effect = _trigger_effect(1)
	phase = Phase.RESULT
	_phase_ticks = 0
	round_judged.emit(result)


func _trigger_effect(player: int) -> HandEffect:
	var states := _judge.states_of(hands[player].curls)
	if _judge.shape_of(hands[player].curls) != HandTypes.Shape.NAMED:
		return null
	var effect := _effect_table.effect_of(states)
	if effect != null:
		effects.trigger(player, effect, states)
	return effect
