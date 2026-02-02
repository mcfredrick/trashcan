extends Node

# Current song being played
var current_song: Dictionary = {}

# Results from last gameplay session
var last_results: Dictionary = {}

# User settings stored in localStorage (web) or ConfigFile (native)
var _settings: Dictionary = {}
var _config_path: String = "user://settings.cfg"

func _ready():
	_load_settings()

func _load_settings():
	if OS.has_feature("web"):
		_load_settings_web()
	else:
		_load_settings_native()

func _load_settings_web():
	var js_code = """
	(function() {
		var settings = localStorage.getItem('drumalong_settings');
		return settings ? settings : '{}';
	})();
	"""
	var result = JavaScriptBridge.eval(js_code)
	if result:
		var json = JSON.new()
		if json.parse(result) == OK:
			_settings = json.data if json.data is Dictionary else {}

func _load_settings_native():
	var config = ConfigFile.new()
	if config.load(_config_path) == OK:
		for key in config.get_section_keys("settings"):
			_settings[key] = config.get_value("settings", key)

func _save_settings():
	if OS.has_feature("web"):
		_save_settings_web()
	else:
		_save_settings_native()

func _save_settings_web():
	var json = JSON.stringify(_settings)
	var js_code = "localStorage.setItem('drumalong_settings', '%s');" % json.replace("'", "\\'")
	JavaScriptBridge.eval(js_code)

func _save_settings_native():
	var config = ConfigFile.new()
	for key in _settings:
		config.set_value("settings", key, _settings[key])
	config.save(_config_path)

func get_setting(key: String, default_value = null):
	return _settings.get(key, default_value)

func set_setting(key: String, value):
	_settings[key] = value
	_save_settings()

func clear_current_song():
	current_song = {}

func clear_results():
	last_results = {}
