extends Node

signal midi_connected(device_name: String)
signal midi_disconnected(device_name: String)
signal drum_hit(lane: int, velocity: int, timestamp: float)

const DRUM_NAMES = ["kick", "snare", "hihat", "hightom", "midtom", "floortom", "crash", "ride"]

var _js_callback: JavaScriptObject = null
var _is_initialized: bool = false
var _has_midi_support: bool = false

func _ready():
	if OS.has_feature("web"):
		_setup_web_midi()

func _setup_web_midi():
	# Create callback for MIDI events from JavaScript
	_js_callback = JavaScriptBridge.create_callback(_on_midi_event)
	JavaScriptBridge.get_interface("window").drumalong_godot_midi_callback = _js_callback

	# Check if Web MIDI is supported
	var supported = JavaScriptBridge.eval("window.drumalong_midi ? window.drumalong_midi.isSupported() : false;")
	_has_midi_support = supported if supported else false

	if _has_midi_support:
		_initialize_midi()

func _initialize_midi():
	var js_code = """
	(async function() {
		const success = await window.drumalong_midi.init(function(lane, velocity, timestamp, noteNumber) {
			// Callback handled via drumalong_godot_midi_callback
		});
		return success;
	})();
	"""
	# Note: This is async, result may not be immediate
	JavaScriptBridge.eval(js_code)
	_is_initialized = true

func _on_midi_event(args):
	var event_type = args[0]
	var data_str = args[1] if args.size() > 1 else "{}"
	var data = JSON.parse_string(data_str)

	if not data:
		return

	match event_type:
		"connected":
			var device_name = data.get("name", "Unknown Device")
			print("MIDI device connected: ", device_name)
			midi_connected.emit(device_name)
		"disconnected":
			var device_name = data.get("name", "Unknown Device")
			print("MIDI device disconnected: ", device_name)
			midi_disconnected.emit(device_name)
		"note":
			var lane = data.get("lane", -1)
			var velocity = data.get("velocity", 0)
			var timestamp = data.get("timestamp", 0.0)

			if lane >= 0 and lane < 8:
				drum_hit.emit(lane, velocity, timestamp)
				# Also trigger the input action for compatibility
				_trigger_drum_action(lane)

func _trigger_drum_action(lane: int):
	# Simulate input action press for the drum lane
	var action_name = "drum_" + DRUM_NAMES[lane]
	var event = InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)

	# Schedule release
	get_tree().create_timer(0.05).timeout.connect(func():
		var release = InputEventAction.new()
		release.action = action_name
		release.pressed = false
		Input.parse_input_event(release)
	)

func is_supported() -> bool:
	return _has_midi_support

func is_initialized() -> bool:
	return _is_initialized

func get_connected_devices() -> Array:
	if not OS.has_feature("web") or not _is_initialized:
		return []

	var result = JavaScriptBridge.eval("JSON.stringify(window.drumalong_midi.getInputs());")
	if result:
		var devices = JSON.parse_string(result)
		return devices if devices else []
	return []

func has_devices() -> bool:
	if not OS.has_feature("web") or not _is_initialized:
		return false

	var result = JavaScriptBridge.eval("window.drumalong_midi.hasDevices();")
	return result if result else false
