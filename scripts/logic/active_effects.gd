class_name ActiveEffects
extends RefCounted
## 掛かっている効果と残りラウンド数(GameDesign 2.5節)。プレイヤーは 0 と 1。
## ラウンドの終わりに end_round() で1つ減らしてから trigger() する。残りが1以上なら次のラウンドに掛かる。

## その手が相手から隠れている残りラウンド数。
var _censor_rounds: Array[int] = []
## 指を撃たれる残りラウンド数。
var _pistol_rounds: Array[int] = []
## [プレイヤー][指] の寝坊している残りラウンド数。Packed 配列は値で渡るため、書き換えたら戻す。
var _oversleep_rounds: Array[PackedInt32Array] = []


func _init() -> void:
	reset()


static func opponent_of(player: int) -> int:
	return LocalMatch.PLAYER_COUNT - 1 - player


func reset() -> void:
	_censor_rounds.assign([0, 0])
	_pistol_rounds.assign([0, 0])
	_oversleep_rounds.clear()
	for player in LocalMatch.PLAYER_COUNT:
		var fingers := PackedInt32Array()
		fingers.resize(HandTypes.Finger.size())
		_oversleep_rounds.append(fingers)


## owner が出した手 states の効果を発動する。
func trigger(owner: int, effect: HandEffect, states: Array) -> void:
	var target := opponent_of(owner)
	match effect.kind:
		HandTypes.EffectKind.CENSOR:
			_censor_rounds[owner] = maxi(_censor_rounds[owner], effect.rounds)
		HandTypes.EffectKind.PISTOL:
			_pistol_rounds[target] = maxi(_pistol_rounds[target], effect.rounds)
		HandTypes.EffectKind.OVERSLEEP:
			var finger := states.find(HandTypes.FingerState.CURLED)
			var rounds := _oversleep_rounds[target]
			rounds[finger] = maxi(rounds[finger], effect.rounds)
			_oversleep_rounds[target] = rounds


func end_round() -> void:
	for player in LocalMatch.PLAYER_COUNT:
		_censor_rounds[player] = maxi(_censor_rounds[player] - 1, 0)
		_pistol_rounds[player] = maxi(_pistol_rounds[player] - 1, 0)
		var rounds := _oversleep_rounds[player]
		for finger in rounds.size():
			rounds[finger] = maxi(rounds[finger] - 1, 0)
		_oversleep_rounds[player] = rounds


## player の手が相手からモザイクで隠れているか。
func is_censored(player: int) -> bool:
	return _censor_rounds[player] > 0


func is_shot(player: int) -> bool:
	return _pistol_rounds[player] > 0


func is_oversleeping(player: int, finger: HandTypes.Finger) -> bool:
	return _oversleep_rounds[player][finger] > 0
