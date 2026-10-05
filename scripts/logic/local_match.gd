class_name LocalMatch
extends RefCounted
## ボットを相手にしたオフラインの1試合(GameDesign 5章)。
## 自分はプレイヤー0。advance(delta) で掛け声 → 判定 → 結果表示 → 次のラウンドと進め、シグナルで知らせる。

signal round_started
signal call_segment_changed(index: int)
signal round_judged(result: RoundResult)
signal match_finished(winner: int)

enum Phase { CALLING, RESULT, OVER }


class RoundResult:
	var outcome: HandTypes.Outcome
	var my_shape: HandTypes.Shape
	var their_shape: HandTypes.Shape
	var my_name: String
	var their_name: String


var my_hand: HandModel
var their_hand: HandModel
var state: MatchState
var phase := Phase.OVER
var _match_config: MatchConfig
var _judge: HandShapeJudge
var _bot: HandBot
var _rng: RandomNumberGenerator
var _elapsed := 0.0
var _segment := 0


func _init(
	hand_config: HandConfig,
	match_config: MatchConfig,
	names: FoulNameTable,
	rng: RandomNumberGenerator,
) -> void:
	_match_config = match_config
	_rng = rng
	_judge = HandShapeJudge.new(hand_config, names)
	my_hand = HandModel.new(hand_config)
	their_hand = HandModel.new(hand_config)
	_bot = HandBot.new(their_hand, rng)
	state = MatchState.new(match_config)


func start() -> void:
	state = MatchState.new(_match_config)
	_start_round()


func can_operate() -> bool:
	return phase == Phase.CALLING


func advance(delta: float) -> void:
	match phase:
		Phase.CALLING:
			_advance_call(delta)
		Phase.RESULT:
			_elapsed += delta
			if _elapsed < _match_config.result_display_seconds:
				return
			if state.is_over():
				phase = Phase.OVER
				match_finished.emit(state.winner())
			else:
				_start_round()


func _start_round() -> void:
	my_hand.randomize_pose(_rng)
	their_hand.randomize_pose(_rng)
	_bot.start_round()
	phase = Phase.CALLING
	_elapsed = 0.0
	_segment = 0
	round_started.emit()
	call_segment_changed.emit(_segment)


func _advance_call(delta: float) -> void:
	_bot.step(delta)
	my_hand.step(delta)
	their_hand.step(delta)
	_elapsed += delta
	var segment := _match_config.call_segment_at(_elapsed)
	if segment >= _match_config.call_segment_seconds.size():
		_finish_round()
	elif segment != _segment:
		_segment = segment
		call_segment_changed.emit(_segment)


func _finish_round() -> void:
	var result := RoundResult.new()
	result.my_shape = _judge.shape_of(my_hand.curls)
	result.their_shape = _judge.shape_of(their_hand.curls)
	result.my_name = _judge.hand_name(my_hand.curls)
	result.their_name = _judge.hand_name(their_hand.curls)
	result.outcome = RoundRules.outcome(result.my_shape, result.their_shape)
	state.record(result.outcome)
	phase = Phase.RESULT
	_elapsed = 0.0
	round_judged.emit(result)
