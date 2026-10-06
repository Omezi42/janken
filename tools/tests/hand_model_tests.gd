extends RefCounted
## HandModel(GameDesign 6.2節・6.3節)。

const STEP := 1.0 / 60.0
const SETTLE_SECONDS := 3.0
## 寝坊の速さを比べる時間(ばねが目標へ届く前)。
const EARLY_SECONDS := 0.1
const TOLERANCE := 0.001
const RANDOM_TRIALS := 50
const SLEEPY_SCALE := 0.5

var _config: HandConfig = load("res://data/hand_config.tres")


func run(assert_true: Callable) -> void:
	_test_linkage(assert_true)
	_test_linkage_at_edge(assert_true)
	_test_inertia(assert_true)
	_test_stops_at_edge(assert_true)
	_test_speed_scale(assert_true)
	_test_random_pose(assert_true)


func _test_linkage(assert_true: Callable) -> void:
	var hand := _hand_at([0.5, 0.5, 0.5, 0.5, 0.5])
	hand.reach(HandTypes.Finger.MIDDLE, 0.9)
	var expected := [0.436, 0.66, 0.9, 0.66, 0.58]
	assert_true.call(_close(hand.targets, expected), "連動は隣へ掛け算で伝わり、負なら逆向き %s" % [hand.targets])
	assert_true.call(
		_close(hand.curls, [0.5, 0.5, 0.5, 0.5, 0.5]), "触った指も目標だけが動き、曲がり具合はばねで追う %s" % [hand.curls]
	)


func _test_linkage_at_edge(assert_true: Callable) -> void:
	var hand := _hand_at([0.5, 0.5, 0.5, 0.5, 0.8])
	hand.reach(HandTypes.Finger.PINKY, 1.3)
	assert_true.call(_close(hand.targets, [0.4936, 0.516, 0.54, 0.6, 1.0]), "端で止まった分は連動しない")


func _test_inertia(assert_true: Callable) -> void:
	var hand := _hand_at([0.5, 0.5, 0.5, 0.5, 0.5])
	hand.reach(HandTypes.Finger.MIDDLE, 0.9)
	var middle_target := hand.targets[HandTypes.Finger.MIDDLE]
	var ring_target := hand.targets[HandTypes.Finger.RING]
	var middle_peak := 0.0
	var ring_peak := 0.0
	for i in int(SETTLE_SECONDS / STEP):
		hand.step(STEP)
		middle_peak = maxf(middle_peak, hand.curls[HandTypes.Finger.MIDDLE])
		ring_peak = maxf(ring_peak, hand.curls[HandTypes.Finger.RING])
	assert_true.call(
		middle_peak > middle_target + TOLERANCE, "触った指も慣性で目標を行き過ぎる(最大 %f)" % middle_peak
	)
	assert_true.call(ring_peak > ring_target + TOLERANCE, "つられた指も慣性で目標を行き過ぎる(最大 %f)" % ring_peak)
	assert_true.call(_close(hand.curls, hand.targets), "やがて目標に落ち着く %s" % [hand.curls])


func _test_stops_at_edge(assert_true: Callable) -> void:
	var hand := _hand_at([0.5, 0.5, 0.5, 0.9, 0.5])
	hand.reach(HandTypes.Finger.MIDDLE, 1.0)
	var inside := true
	for i in int(SETTLE_SECONDS / STEP):
		hand.step(STEP)
		inside = inside and hand.curls[HandTypes.Finger.RING] <= HandModel.MAX_CURL
	assert_true.call(inside, "曲がり具合は 1.0 を超えない")
	assert_true.call(
		is_equal_approx(hand.curls[HandTypes.Finger.RING], HandModel.MAX_CURL), "端で止まる"
	)


func _test_speed_scale(assert_true: Callable) -> void:
	var awake := _hand_at([0.0, 0.0, 0.0, 0.0, 0.0])
	var sleepy := _hand_at([0.0, 0.0, 0.0, 0.0, 0.0])
	sleepy.speed_scales[HandTypes.Finger.INDEX] = SLEEPY_SCALE
	for hand in [awake, sleepy]:
		hand.reach(HandTypes.Finger.INDEX, HandModel.MAX_CURL)
	for i in int(EARLY_SECONDS / STEP):
		awake.step(STEP)
		sleepy.step(STEP)
	var index := HandTypes.Finger.INDEX
	assert_true.call(
		sleepy.curls[index] < awake.curls[index],
		"寝坊した指は遅い (%f < %f)" % [sleepy.curls[index], awake.curls[index]]
	)
	for i in int(SETTLE_SECONDS / STEP):
		sleepy.step(STEP)
	assert_true.call(_close(sleepy.curls, sleepy.targets), "寝坊した指もやがて目標に届く")


func _test_random_pose(assert_true: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var hand := HandModel.new(_config)
	var in_range := true
	for trial in RANDOM_TRIALS:
		hand.randomize_pose(rng)
		for curl in hand.curls:
			in_range = in_range and curl >= HandModel.MIN_CURL and curl <= HandModel.MAX_CURL
	assert_true.call(in_range, "初期配置は曲がり具合 0〜1")
	assert_true.call(_close(hand.curls, hand.targets), "初期配置では目標と曲がり具合が一致")


func _hand_at(pose: Array) -> HandModel:
	var hand := HandModel.new(_config)
	hand.set_pose(PackedFloat64Array(pose))
	return hand


func _close(actual: PackedFloat64Array, expected: Array) -> bool:
	for i in expected.size():
		if absf(actual[i] - expected[i]) > TOLERANCE:
			return false
	return true
