@tool
class_name SpritesynthSettings
extends RefCounted

const SETTING_KEY: String = "spritesynth/api_key"
const ENV_VAR_NAME: String = "SPIRESYNTH_API_KEY"


static func get_api_key() -> String:
	var env_key: String = OS.get_environment(ENV_VAR_NAME)
	if not env_key.is_empty():
		return env_key
	if ProjectSettings.has_setting(SETTING_KEY):
		var stored = ProjectSettings.get_setting(SETTING_KEY)
		if stored is String and not (stored as String).is_empty():
			return stored
	return ""


static func save_api_key(key: String) -> void:
	ProjectSettings.set_setting(SETTING_KEY, key)
	ProjectSettings.save()


static func is_using_env_var() -> bool:
	var env_key: String = OS.get_environment(ENV_VAR_NAME)
	if env_key.is_empty():
		return false
	if ProjectSettings.has_setting(SETTING_KEY):
		var stored = ProjectSettings.get_setting(SETTING_KEY)
		if stored is String and not (stored as String).is_empty():
			return false
	return not env_key.is_empty()


static func get_key_source() -> String:
	var env_key: String = OS.get_environment(ENV_VAR_NAME)
	if not env_key.is_empty():
		if ProjectSettings.has_setting(SETTING_KEY):
			var stored = ProjectSettings.get_setting(SETTING_KEY)
			if stored is String and not (stored as String).is_empty():
				return "ProjectSettings"
		return "Environment variable ($" + ENV_VAR_NAME + ")"
	if ProjectSettings.has_setting(SETTING_KEY):
		var stored = ProjectSettings.get_setting(SETTING_KEY)
		if stored is String and not (stored as String).is_empty():
			return "ProjectSettings"
	return "Not configured"


static func has_api_key() -> bool:
	return not get_api_key().is_empty()
