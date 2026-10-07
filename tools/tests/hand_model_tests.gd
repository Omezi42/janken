extends RefCounted
## HandModel(GameDesign 2.1節・2.5節・6.3節)。

const MAX := HandModel.CURL_MAX
const RANDOM_TRIALS := 200
const SLEEPY_TICKS := 24
const HALF_CURL := 50


func run(assert_true: Callable) -> void:
	_test_move(assert_true)
	_test_delay(assert_true)
	_test_random_pose(assert_true)


func _test_move(assert_true: Callable) -> void:
	var hand := _hand_at([0, 0, 0, 0, 0])
	hand.move(HandTypes.Finger.MIDDLE, HALF_CURL)
	assert_true.call(
		hand.curls == PackedInt32Array([0, 0, HALF_CURL, 0, 0]), "動かしたのは触った指だけ %s" % [hand.curls]
	)
	hand.move(HandTypes.Finger.MIDDLE, MAX * 2)
	assert_true.call(hand.curls[HandTypes.Finger.MIDDLE] == MAX, "曲がりきりの先では止まる")


func _test_delay(assert_true: Callable) -> void:
	var hand := _hand_at([0, 0, 0, 0, 0])
	hand.delay_ticks[HandTypes.Finger.INDEX] = SLEEPY_TICKS
	hand.move(HandTypes.Finger.INDEX, HALF_CURL)
	hand.move(HandTypes.Finger.INDEX, MAX)
	assert_true.call(hand.curls[HandTypes.Finger.INDEX] == 0, "寝坊した指はすぐには動かない")
	assert_true.call(hand.settled_curl(HandTypes.Finger.INDEX) == MAX, "予約を済ませた後は最後の動き")
	for i in SLEEPY_TICKS - 1:
		hand.step()
	assert_true.call(hand.curls[HandTypes.Finger.INDEX] == 0, "遅れの tick 数が経つまで元のまま")
	hand.step()
	assert_true.call(hand.curls[HandTypes.Finger.INDEX] == MAX, "遅れの tick 数が経ったら動く")
	hand.move(HandTypes.Finger.MIDDLE, MAX)
	assert_true.call(hand.curls[HandTypes.Finger.MIDDLE] == MAX, "寝坊していない指はすぐ動く")


func _test_random_pose(assert_true: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var hand := HandModel.new()
	var curled := 0
	var only_ends := true
	for trial in RANDOM_TRIALS:
		hand.randomize_pose(rng)
		curled += hand.curls.count(MAX)
		only_ends = only_ends and hand.curls.count(0) + hand.curls.count(MAX) == hand.curls.size()
	var ratio := float(curled) / (RANDOM_TRIALS * HandTypes.Finger.size())
	assert_true.call(absf(ratio - 0.5) < 0.05, "初期配置は伸びきり・曲がりきりが半々 (%f)" % ratio)
	assert_true.call(only_ends, "初期配置は中途半端から始めない")


func _hand_at(pose: Array) -> HandModel:
	var hand := HandModel.new()
	hand.set_pose(PackedInt32Array(pose))
	return hand
