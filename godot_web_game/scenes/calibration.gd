extends Control

const CALIBRATION_SAMPLES = 10
const BEAT_INTERVAL = 1.0  # 60 BPM for easy calibration

var is_calibrating: bool = false
var beat_times: Array = []
var input_times: Array = []
var current_beat: int = 0
var beat_timer: float = 0.0
var last_beat_time: float = 0.0

func _ready():
	$VBoxContainer/ButtonContainer/BackButton.pressed.connect(_on_back_pressed)
	$VBoxContainer/ButtonContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/ButtonContainer/SaveButton.pressed.connect(_on_save_pressed)
	_load_settings()

func _load_settings():
	var audio_offset = GameState.get_setting("audio_offset", 0.0)
	var midi_offset = GameState.get_setting("midi_offset", 0.0)
	$VBoxContainer/OffsetContainer/OffsetValue.value = audio_offset
	$VBoxContainer/MIDIOffsetContainer/MIDIOffsetValue.value = midi_offset

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_start_pressed():
	_start_calibration()

func _on_save_pressed():
	var audio_offset = $VBoxContainer/OffsetContainer/OffsetValue.value
	var midi_offset = $VBoxContainer/MIDIOffsetContainer/MIDIOffsetValue.value
	GameState.set_setting("audio_offset", audio_offset)
	GameState.set_setting("midi_offset", midi_offset)
	$VBoxContainer/StatusLabel.text = "Settings saved!"

func _start_calibration():
	is_calibrating = true
	beat_times.clear()
	input_times.clear()
	current_beat = 0
	beat_timer = 0.0
	$VBoxContainer/StatusLabel.text = "Listen for the beat and tap when you hear it..."
	$VBoxContainer/ButtonContainer/StartButton.disabled = true

func _process(delta):
	if not is_calibrating:
		return

	beat_timer += delta

	if beat_timer >= BEAT_INTERVAL:
		beat_timer -= BEAT_INTERVAL
		_play_beat()

func _play_beat():
	if current_beat >= CALIBRATION_SAMPLES:
		_finish_calibration()
		return

	last_beat_time = Time.get_ticks_msec() / 1000.0
	beat_times.append(last_beat_time)
	current_beat += 1

	# Visual flash
	$VBoxContainer/VisualIndicator.color = Color(0.2, 0.8, 0.2)
	var tween = create_tween()
	tween.tween_property($VBoxContainer/VisualIndicator, "color", Color(0.3, 0.3, 0.3), 0.2)

	# Play metronome sound (would need actual audio file)
	# $MetronomePlayer.play()

	$VBoxContainer/ProgressLabel.text = "Samples: %d / %d" % [min(input_times.size(), CALIBRATION_SAMPLES), CALIBRATION_SAMPLES]

func _input(event):
	if not is_calibrating:
		return

	var is_drum_hit = false

	if event is InputEventKey and event.pressed and not event.echo:
		is_drum_hit = true
	elif event is InputEventMIDI:
		is_drum_hit = true

	if is_drum_hit and beat_times.size() > input_times.size():
		var input_time = Time.get_ticks_msec() / 1000.0
		input_times.append(input_time)

		# Visual feedback
		$VBoxContainer/VisualIndicator.color = Color(0.8, 0.8, 0.2)
		var tween = create_tween()
		tween.tween_property($VBoxContainer/VisualIndicator, "color", Color(0.3, 0.3, 0.3), 0.1)

		$VBoxContainer/ProgressLabel.text = "Samples: %d / %d" % [input_times.size(), CALIBRATION_SAMPLES]

		if input_times.size() >= CALIBRATION_SAMPLES:
			_finish_calibration()

func _finish_calibration():
	is_calibrating = false
	$VBoxContainer/ButtonContainer/StartButton.disabled = false

	if input_times.size() < 3:
		$VBoxContainer/StatusLabel.text = "Not enough samples. Try again."
		return

	# Calculate average latency
	var total_latency = 0.0
	var valid_samples = 0

	for i in range(min(beat_times.size(), input_times.size())):
		var latency = (input_times[i] - beat_times[i]) * 1000.0  # Convert to ms
		# Ignore outliers (more than 500ms)
		if abs(latency) < 500:
			total_latency += latency
			valid_samples += 1

	if valid_samples > 0:
		var avg_latency = total_latency / valid_samples
		$VBoxContainer/MIDIOffsetContainer/MIDIOffsetValue.value = -avg_latency
		$VBoxContainer/StatusLabel.text = "Calibration complete! Average latency: %.0f ms" % avg_latency
	else:
		$VBoxContainer/StatusLabel.text = "Calibration failed. Please try again."
