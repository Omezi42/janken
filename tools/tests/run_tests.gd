extends SceneTree
## テストの入口。個々のスイートは別ファイル(`*_tests.gd`、`run(assert_true: Callable)` を持つ)へ切り出し、
## ここは呼び出しと判定だけを持つ。

const SUITES := [
	preload("res://tools/tests/hand_shape_judge_tests.gd"),
	preload("res://tools/tests/match_tests.gd"),
	preload("res://tools/tests/hand_model_tests.gd"),
]

var _failures := 0
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for suite in SUITES:
		suite.new().run(_assert_true)
	if _failures > 0:
		printerr("tests FAILED: ", _failures, " / ", _checks)
		quit(1)
		return
	print("tests passed: ", _checks)
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("FAILED: ", message)
