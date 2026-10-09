class_name PlayerProfile
## プレイヤー名(GameDesign 9.2節)。端末の user://profile.cfg に保存する。

const PATH := "user://profile.cfg"
const SECTION := "player"
const NAME_KEY := "name"


## 前後の空白を除いて最大文字数で切る。
static func clean_name(text: String, config: OnlineConfig) -> String:
	return text.strip_edges().left(config.name_max_length)


static func random_name(config: OnlineConfig, rng: RandomNumberGenerator) -> String:
	var suffixes := config.default_name_suffixes
	return config.default_name_prefix + suffixes[rng.randi_range(0, suffixes.size() - 1)]


static func load_name() -> String:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return ""
	return str(file.get_value(SECTION, NAME_KEY, ""))


static func save_name(player_name: String) -> void:
	var file := ConfigFile.new()
	file.load(PATH)
	file.set_value(SECTION, NAME_KEY, player_name)
	file.save(PATH)
