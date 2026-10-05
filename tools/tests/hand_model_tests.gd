extends RefCounted
## HandModel(GameDesign 6.2節・6.3節)。

const STEP := 1.0 / 60.0
const SETTLE_SECONDS := 3.0
const TOLERANCE := 0.001
const RANDOM_TRIALS := 50

var _config: HandConfig = load("res://data/hand_config.tres")


func run(assert_true: Callable) -> void:
	_test_linkage(assert_true)
	_test_linkage_at_edge(assert_true)
	_test_inertia(assert_true)
	_test_stops_at_edge(assert_true)
	_test_random_pose(assert_true)


func _test_linkage(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.5]))
	hand.drag(HandTypes.Finger.MIDDLE, 0.4)
	var expected := [0.436, 0.66, 0.9, 0.66, 0.58]
	assert_true.call(_close(hand.targets, expected), "連動は隣へ掛け算で伝わり、負なら逆向き %s" % [hand.targets])
	assert_true.call(_close(hand.curls, [0.5, 0.5, 0.5, 0.5, 0.5]), "ドラッグで動くのは目標だけ")


func _test_linkage_at_edge(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.8]))
	hand.drag(HandTypes.Finger.PINKY, 0.5)
	assert_true.call(_close(hand.targets, [0.4936, 0.516, 0.54, 0.6, 1.0]), "端で止まった分は連動しない")


func _test_inertia(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0]))
	hand.drag(HandTypes.Finger.THUMB, 0.5)
	var peak := 0.0
	for i in int(SETTLE_SECONDS / STEP):
		hand.step(STEP)
		peak = maxf(peak, hand.curls[HandTypes.Finger.THUMB])
	assert_true.call(peak > 0.5 + TOLERANCE, "慣性で目標を行き過ぎる(最大 %f)" % peak)
	assert_true.call(_close(hand.curls, hand.targets), "やがて目標に落ち着く %s" % [hand.curls])


func _test_stops_at_edge(assert_true: Callable) -> void:
	var hand := _hand_at(PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0]))
	hand.drag(HandTypes.Finger.THUMB, 1.0)
	var inside := true
	for i in int(SETTLE_SECONDS / STEP):
		hand.step(STEP)
		inside = inside and hand.curls[HandTypes.Finger.THUMB] <= HandModel.MAX_CURL
	assert_true.call(inside, "曲がり具合は 1.0 を超えない")
	assert_true.call(is_equal_approx(hand.curls[0], HandModel.MAX_CURL), "端で止まる")


func _test_random_pose(assert_true: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var hand := HandModel.new(_config)
	var in_range := true
	for trial in RANDOM_TRIALS:
		hand.randomize_pose(rng)
		for curl in hand.curls:
			in_range = in_range and curl >= HandModel.MIN_CURL and curl <= HandModel.MAX_CURL
		in_range = in_range and hand.wrist_rotation_degrees >= 0.0
		in_range = in_range and hand.wrist_rotation_degrees < HandModel.FULL_TURN_DEGREES
	assert_true.call(in_range, "初期配置は曲がり具合 0〜1、回転 0〜360°")
	assert_true.call(_close(hand.curls, hand.targets), "初期配置では目標と曲がり具合が一致")


func _hand_at(pose: PackedFloat64Array) -> HandModel:
	var hand := HandModel.new(_config)
	hand.set_pose(pose, 0.0)
	return hand


func _close(actual: PackedFloat64Array, expected: Array) -> bool:
	for i in expected.size():
		if absf(actual[i] - expected[i]) > TOLERANCE:
			return false
	return true
