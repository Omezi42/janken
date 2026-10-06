extends RefCounted
## HandModel / FingerAxis(GameDesign 6.2節・6.3節)。

const STEP := 1.0 / 60.0
const SETTLE_SECONDS := 3.0
const TOLERANCE := 0.001
const RANDOM_TRIALS := 50
## 向きのばねが「何度も揺れる」とみなす行き過ぎの割合。
const WOBBLY_OVERSHOOT := 0.3

var _config: HandConfig = load("res://data/hand_config.tres")


func run(assert_true: Callable) -> void:
	_test_linkage(assert_true)
	_test_linkage_at_edge(assert_true)
	_test_inertia(assert_true)
	_test_stops_at_edge(assert_true)
	_test_swing_linkage(assert_true)
	_test_swing_wobbles(assert_true)
	_test_random_pose(assert_true)


func _test_linkage(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.5]))
	hand.drag(HandTypes.Finger.MIDDLE, 0.4)
	var expected := [0.436, 0.66, 0.9, 0.66, 0.58]
	assert_true.call(_close(hand.targets, expected), "連動は隣へ掛け算で伝わり、負なら逆向き %s" % [hand.targets])
	assert_true.call(
		_close(hand.curls, [0.5, 0.5, 0.9, 0.5, 0.5]), "掴んだ指だけ直接動き、つられた指は目標だけ動く %s" % [hand.curls]
	)


func _test_linkage_at_edge(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.8]))
	hand.drag(HandTypes.Finger.PINKY, 0.5)
	assert_true.call(_close(hand.targets, [0.4936, 0.516, 0.54, 0.6, 1.0]), "端で止まった分は連動しない")


func _test_inertia(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.5]))
	hand.drag(HandTypes.Finger.MIDDLE, 0.4)
	var ring_target := hand.targets[HandTypes.Finger.RING]
	var peak := 0.0
	var grabbed_still := true
	for i in int(SETTLE_SECONDS / STEP):
		hand.step(STEP)
		peak = maxf(peak, hand.curls[HandTypes.Finger.RING])
		grabbed_still = grabbed_still and is_equal_approx(hand.curls[HandTypes.Finger.MIDDLE], 0.9)
	assert_true.call(peak > ring_target + TOLERANCE, "つられた指は慣性で目標を行き過ぎる(最大 %f)" % peak)
	assert_true.call(grabbed_still, "掴んだ指は行き過ぎない")
	assert_true.call(_close(hand.curls, hand.targets), "やがて目標に落ち着く %s" % [hand.curls])


func _test_stops_at_edge(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.9, 0.5]))
	hand.drag(HandTypes.Finger.MIDDLE, 0.5)
	var inside := true
	for i in int(SETTLE_SECONDS / STEP):
		hand.step(STEP)
		inside = inside and hand.curls[HandTypes.Finger.RING] <= HandModel.MAX_CURL
	assert_true.call(inside, "曲がり具合は 1.0 を超えない")
	assert_true.call(
		is_equal_approx(hand.curls[HandTypes.Finger.RING], HandModel.MAX_CURL), "端で止まる"
	)


func _test_swing_linkage(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.5]))
	hand.swing(HandTypes.Finger.INDEX, 10.0)
	var targets := hand.swing_axis.targets
	assert_true.call(_close(targets, [2.0, 10.0, 5.0, 2.5, 1.25]), "向きも隣へ掛け算で連動する %s" % [targets])
	assert_true.call(_close(hand.curls, [0.5, 0.5, 0.5, 0.5, 0.5]), "向きを動かしても曲がり具合は変わらない")
	hand.swing(HandTypes.Finger.INDEX, 100.0)
	assert_true.call(
		is_equal_approx(hand.swings[HandTypes.Finger.INDEX], _config.swing_range_degrees),
		"向きは可動範囲で止まる"
	)


func _test_swing_wobbles(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.5]))
	hand.swing(HandTypes.Finger.INDEX, 10.0)
	var target := hand.swing_axis.targets[HandTypes.Finger.MIDDLE]
	var peak := 0.0
	for i in int(SETTLE_SECONDS / STEP):
		hand.step(STEP)
		peak = maxf(peak, hand.swings[HandTypes.Finger.MIDDLE])
	assert_true.call(peak > target * (1.0 + WOBBLY_OVERSHOOT), "向きのばねは柔らかく大きく行き過ぎる(最大 %f)" % peak)


func _test_random_pose(assert_true: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var hand := HandModel.new(_config)
	var in_range := true
	var swing_range := _config.swing_range_degrees
	for trial in RANDOM_TRIALS:
		hand.randomize_pose(rng)
		for curl in hand.curls:
			in_range = in_range and curl >= HandModel.MIN_CURL and curl <= HandModel.MAX_CURL
		for swing in hand.swings:
			in_range = in_range and absf(swing) <= swing_range
	assert_true.call(in_range, "初期配置は曲がり具合 0〜1、向きは可動範囲の中")
	assert_true.call(_close(hand.curls, hand.targets), "初期配置では目標と曲がり具合が一致")


func _hand_at(pose: PackedFloat64Array) -> HandModel:
	var hand := HandModel.new(_config)
	hand.set_pose(pose)
	return hand


func _close(actual: PackedFloat64Array, expected: Array) -> bool:
	for i in expected.size():
		if absf(actual[i] - expected[i]) > TOLERANCE:
			return false
	return true
