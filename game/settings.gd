class_name Settings
extends RefCounted
## Player preferences, kept in user://settings.cfg.

const PATH := "user://settings.cfg"

static func get_bool(key: String, fallback: bool) -> bool:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return fallback
	return bool(cf.get_value("play", key, fallback))

static func set_bool(key: String, value: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("play", key, value)
	cf.save(PATH)
