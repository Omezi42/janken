extends RefCounted
## HandModel(GameDesign 2.1節・2.5節・6.3節)。

const E := HandTypes.FingerState.EXTENDED
const C := HandTypes.FingerState.CURLED
const RANDOM_TRIALS := 200
const SLEEPY_TICKS := 24


func run(assert_true: Callable) -> void:
	_test_flip(assert_true)
	_test_delay(assert_true)
	_test_random_pose(assert_true)


func _test_flip(assert_true: Callable) -> void:
	var hand := _hand_at([E, E, E, E, E])
	hand.flip(HandTypes.Finger.MIDDLE)
	assert_true.call(hand.states == [E, E, C, E, E], "反転は触った指だけ(隣はつられない) %s" % [hand.states])
	hand.flip(HandTypes.Finger.MIDDLE)
	assert_true.call(hand.states == [E, E, E, E, E], "2回反転すると元に戻る")


func _test_delay(assert_true: Callable) -> void:
	var hand := _hand_at([E, E, E, E, E])
	hand.delay_ticks[HandTypes.Finger.INDEX] = SLEEPY_TICKS
	hand.flip(HandTypes.Finger.INDEX)
	assert_true.call(not hand.is_curled(HandTypes.Finger.INDEX), "寝坊した指はすぐには反転しない")
	assert_true.call(hand.settled_state(HandTypes.Finger.INDEX) == C, "予約を済ませた後の状態は反転後")
	for i in SLEEPY_TICKS - 1:
		hand.step()
	assert_true.call(not hand.is_curled(HandTypes.Finger.INDEX), "遅れの tick 数が経つまで元の状態のまま")
	hand.step()
	assert_true.call(hand.is_curled(HandTypes.Finger.INDEX), "遅れの tick 数が経ったら反転する")
	hand.flip(HandTypes.Finger.MIDDLE)
	assert_true.call(hand.is_curled(HandTypes.Finger.MIDDLE), "寝坊していない指はすぐ反転する")


func _test_random_pose(assert_true: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var hand := HandModel.new()
	var curled := 0
	for trial in RANDOM_TRIALS:
		hand.randomize_pose(rng)
		curled += hand.states.count(C)
	var ratio := float(curled) / (RANDOM_TRIALS * HandTypes.Finger.size())
	assert_true.call(absf(ratio - 0.5) < 0.05, "初期配置は伸び・曲がりが半々 (%f)" % ratio)


func _hand_at(pose: Array) -> HandModel:
	var hand := HandModel.new()
	hand.set_pose(pose)
	return hand
