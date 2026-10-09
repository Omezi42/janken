class_name MatchSession
extends RefCounted
## LocalMatch と OnlineMatch の共通の型(Architecture 4章)。プレイヤーは 0(手前・自分)と 1(奥・相手)。
## 画面とボットはこの型だけを見て、オフラインとオンラインの試合を同じに扱う。

signal round_started
signal call_segment_changed(index: int)
## 手の名前を呼ぶ区間の始まり。call.outcome は使わない。
signal hands_called(call: RoundResult)
signal round_judged(result: RoundResult)
signal match_finished(winner: int)

## WAITING・JUDGING はオンラインだけ(最初のラウンドの前・判定の結果を待つ間)。
enum Phase { CALLING, RESULT, OVER, WAITING, JUDGING }

const TICKS_PER_SECOND := 60
const TICK_SECONDS := 1.0 / TICKS_PER_SECOND
const PLAYER_COUNT := 2


class RoundResult:
	var outcome: HandTypes.Outcome
	## 指の状態(HandTypes.FingerState)。
	var my_states: Array
	var their_states: Array
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
var effects := ActiveEffects.new()
var judge: HandShapeJudge
## 両者の名前(GameDesign 9.2節)。
var player_names := PackedStringArray(["", ""])


func _init(names: HandNameTable, rule_table: HandRuleTable, match_config: MatchConfig) -> void:
	judge = HandShapeJudge.new(names, rule_table)
	for player in PLAYER_COUNT:
		hands.append(HandModel.new())
	state = MatchState.new(match_config)


func can_operate() -> bool:
	return phase == Phase.CALLING


## 指を曲がり具合 curl(0〜HandModel.CURL_MAX)へ動かす。操作できない間は捨てる。
func move(_player: int, _finger: HandTypes.Finger, _curl: int) -> void:
	pass


## 固定間隔(TICK_SECONDS)ごとに呼ぶ。
func tick() -> void:
	pass


## いまの両者の手から、名前と形を入れた RoundResult を作る。
func name_hands(my_curls: PackedInt32Array, their_curls: PackedInt32Array) -> RoundResult:
	var result := RoundResult.new()
	result.my_states = judge.states_of(my_curls)
	result.their_states = judge.states_of(their_curls)
	result.my_shape = HandShapeJudge.shape_of(result.my_states)
	result.their_shape = HandShapeJudge.shape_of(result.their_states)
	result.my_name = judge.hand_name(my_curls)
	result.their_name = judge.hand_name(their_curls)
	return result
