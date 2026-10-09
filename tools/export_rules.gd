extends SceneTree
## サーバー用のルール(server/src/rules.json)と、判定一致テストの答え(server/test/judge_fixture.json)を
## 書き出す(Architecture 3.3節)。
## godot --headless --path . --script res://tools/export_rules.gd

const MATCH_CONFIG: MatchConfig = preload("res://data/match_config.tres")
const HAND_NAMES: HandNameTable = preload("res://data/hand_name_table.tres")
const HAND_RULES: HandRuleTable = preload("res://data/hand_rule_table.tres")
const HAND_EFFECTS: HandEffectTable = preload("res://data/hand_effect_table.tres")
const ONLINE_CONFIG: OnlineConfig = preload("res://data/online_config.tres")
const RULES_PATH := "res://server/src/rules.json"
const FIXTURE_PATH := "res://server/test/judge_fixture.json"
const FIXTURE_SEED := 20261009
const RANDOM_CASES := 2000
## 乱数の手で、指を伸びきり・曲がりきりにする確率(残りは途中の曲がり具合)。
const EXTREME_CHANCE := 0.85
const OUTCOME_NAMES := {
	HandTypes.Outcome.WIN: "win",
	HandTypes.Outcome.LOSE: "lose",
	HandTypes.Outcome.DRAW: "draw",
}


func _init() -> void:
	if not HAND_EFFECTS.effects.is_empty():
		printerr("効果の表に行がある。サーバーは効果を扱わないため、先にサーバーを直す(Architecture 3.2節)")
		quit(1)
		return
	var ok := _write(RULES_PATH, JSON.stringify(_rules(), "\t"))
	ok = ok and _write(FIXTURE_PATH, JSON.stringify(_fixture()))
	print("export_rules: ", "ok" if ok else "FAILED")
	quit(0 if ok else 1)


func _rules() -> Dictionary:
	var conditions := {}
	for key: String in HAND_RULES.conditions:
		var condition: Resource = HAND_RULES.conditions[key]
		conditions[key] = {
			"kind": HandTypes.ConditionKind.keys()[condition.kind], "value": condition.value
		}
	return {
		"curlMax": HandModel.CURL_MAX,
		"winsToFinish": MATCH_CONFIG.wins_to_finish,
		"callSegmentSeconds": MATCH_CONFIG.call_segment_seconds,
		"handCallSegment": MATCH_CONFIG.hand_call_segment,
		"resultDisplaySeconds": MATCH_CONFIG.result_display_seconds,
		"extendedBelow": HAND_RULES.extended_below,
		"curledAbove": HAND_RULES.curled_above,
		"scissorsMinExtended": HAND_RULES.scissors_min_extended,
		"paperMinExtended": HAND_RULES.paper_min_extended,
		"curledMark": HandNameTable.CURLED_MARK,
		"extendedMark": HandNameTable.EXTENDED_MARK,
		"conditions": conditions,
		"nameMaxLength": ONLINE_CONFIG.name_max_length,
		"fallbackName": ONLINE_CONFIG.default_name_prefix + ONLINE_CONFIG.default_name_suffixes[0],
		"matchStartDelaySeconds": ONLINE_CONFIG.match_start_delay_seconds,
		"moveRatePerSecond": ONLINE_CONFIG.move_rate_per_second,
		"moveBurst": ONLINE_CONFIG.move_burst,
	}


func _fixture() -> Dictionary:
	var judge := HandShapeJudge.new(HAND_NAMES, HAND_RULES)
	var pairs := []
	var pattern_count := 1 << HandTypes.Finger.size()
	for a in pattern_count:
		for b in pattern_count:
			pairs.append([_pose_of_bits(a), _pose_of_bits(b)])
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	for i in RANDOM_CASES:
		pairs.append([_random_curls(rng), _random_curls(rng)])
	var cases := []
	for pair: Array in pairs:
		var mine: PackedInt32Array = pair[0]
		var theirs: PackedInt32Array = pair[1]
		var outcome := RoundRules.outcome(judge.states_of(mine), judge.states_of(theirs), judge)
		cases.append({"mine": mine, "theirs": theirs, "outcome": OUTCOME_NAMES[outcome]})
	return {"cases": cases}


func _pose_of_bits(bits: int) -> PackedInt32Array:
	var curls := PackedInt32Array()
	for finger in HandTypes.Finger.size():
		curls.append(HandModel.CURL_MAX if bits & (1 << finger) else 0)
	return curls


func _random_curls(rng: RandomNumberGenerator) -> PackedInt32Array:
	var curls := PackedInt32Array()
	for finger in HandTypes.Finger.size():
		if rng.randf() < EXTREME_CHANCE:
			curls.append(HandModel.CURL_MAX * rng.randi_range(0, 1))
		else:
			curls.append(rng.randi_range(0, HandModel.CURL_MAX))
	return curls


func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("書き出せない: ", path)
		return false
	file.store_string(text + "\n")
	return true
