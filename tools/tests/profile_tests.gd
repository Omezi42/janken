extends RefCounted
## PlayerProfile の名前の整え方(GameDesign 9.2節)。user:// の実データには触らない。

const ONLINE_CONFIG: OnlineConfig = preload("res://data/online_config.tres")
const RANDOM_TRIES := 20


func run(assert_true: Callable) -> void:
	var long_name := "あいうえおかきくけこ"
	var cleaned := PlayerProfile.clean_name(long_name, ONLINE_CONFIG)
	assert_true.call(cleaned.length() == ONLINE_CONFIG.name_max_length, "名前は最大文字数で切る")
	assert_true.call(PlayerProfile.clean_name("  ぐー ", ONLINE_CONFIG) == "ぐー", "名前の前後の空白を除く")
	assert_true.call(PlayerProfile.clean_name("   ", ONLINE_CONFIG).is_empty(), "空白だけなら空")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in RANDOM_TRIES:
		var random_name := PlayerProfile.random_name(ONLINE_CONFIG, rng)
		assert_true.call(
			random_name.begins_with(ONLINE_CONFIG.default_name_prefix), "既定の名前は決まった頭を持つ"
		)
		assert_true.call(random_name.length() <= ONLINE_CONFIG.name_max_length, "既定の名前も最大文字数に収まる")
