extends Control

const LANE_NAMES = ["Kick", "Snare", "Hi-Hat", "High Tom", "Mid Tom", "Floor Tom", "Crash", "Ride"]
const LANE_COLORS = [
	Color(0.8, 0.2, 0.2),  # Kick - Red
	Color(0.9, 0.9, 0.2),  # Snare - Yellow
	Color(0.2, 0.8, 0.2),  # Hi-Hat - Green
	Color(0.2, 0.6, 0.9),  # High Tom - Blue
	Color(0.2, 0.8, 0.8),  # Mid Tom - Cyan
	Color(0.4, 0.4, 0.9),  # Floor Tom - Indigo
	Color(0.9, 0.5, 0.1),  # Crash - Orange
	Color(0.7, 0.3, 0.9),  # Ride - Purple
]

var song_data: Dictionary = {}
var is_playing: bool = false
var is_paused: bool = false
var song_time: float = 0.0
var score: int = 0
var combo: int = 0
var max_combo: int = 0

var hits_perfect: int = 0
var hits_great: int = 0
var hits_good: int = 0
var hits_miss: int = 0

var lanes: Array = []
var pending_notes: Array = []  # Notes waiting to be spawned
var active_notes: Array = []   # Notes currently on screen

const NOTE_SPEED: float = 400.0  # Pixels per second
const SPAWN_AHEAD_TIME: float = 2.0  # Spawn notes 2 seconds before hit time

func _ready():
	$BottomBar/PauseButton.pressed.connect(_on_pause_pressed)
	$BottomBar/RestartButton.pressed.connect(_on_restart_pressed)
	$BottomBar/QuitButton.pressed.connect(_on_quit_pressed)
	$BottomBar/Progress.gui_input.connect(_on_progress_input)
	$BottomBar/SlowDownButton.pressed.connect(_on_slow_down_pressed)
	$BottomBar/SpeedUpButton.pressed.connect(_on_speed_up_pressed)
	MidiInput.drum_hit.connect(_on_midi_drum_hit)
	_setup_lanes()
	_load_song()
	_start_countdown()

func _on_midi_drum_hit(lane: int, velocity: int, _timestamp: float):
	if is_playing and not is_paused:
		_handle_drum_hit(lane)

func _setup_lanes():
	var lane_container = $LaneContainer/Lanes
	for i in range(8):
		var lane = _create_lane(i)
		lane_container.add_child(lane)
		lanes.append(lane)

func _create_lane(index: int) -> Control:
	var lane = Panel.new()
	lane.name = "Lane_" + str(index)
	lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = LANE_COLORS[index].darkened(0.7)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = LANE_COLORS[index].darkened(0.3)
	lane.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.name = "LaneLabel"
	label.text = LANE_NAMES[index]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	label.offset_top = -30
	label.add_theme_font_size_override("font_size", 14)
	lane.add_child(label)

	return lane

func _load_song():
	if GameState.current_song:
		song_data = GameState.current_song
		$HUD/TopBar/SongName.text = song_data.get("name", "Unknown Song")
		pending_notes = song_data.get("onsets", []).duplicate()
	else:
		# Demo mode with generated notes
		$HUD/TopBar/SongName.text = "Demo Mode"
		_generate_demo_notes()

func _generate_demo_notes():
	# Generate some demo notes for testing
	for i in range(50):
		var note = {
			"time": 2.0 + i * 0.5,
			"lane": randi() % 8,
			"type": LANE_NAMES[randi() % 8].to_lower().replace(" ", "_")
		}
		pending_notes.append(note)

func _start_countdown():
	$CountdownLabel.visible = true

	var bpm = song_data.get("bpm", 120)
	var beat_interval = 60.0 / bpm
	var beats = 4

	# Display BPM info
	$CountdownLabel.text = str(bpm) + " BPM"
	await get_tree().create_timer(0.5).timeout

	# Play count-in with metronome
	if OS.has_feature("web"):
		_play_web_count_in(bpm, beats)

	# Visual countdown synced to beat
	for i in range(beats):
		$CountdownLabel.text = str(beats - i)
		# Flash the label
		$CountdownLabel.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property($CountdownLabel, "modulate", Color(1, 1, 1, 0.5), beat_interval * 0.8)
		await get_tree().create_timer(beat_interval).timeout

	$CountdownLabel.text = "GO!"
	await get_tree().create_timer(0.3).timeout
	$CountdownLabel.visible = false
	_start_playing()

func _play_web_count_in(bpm: int, beats: int):
	var js_code = "window.drumalong_playCountIn(%d, %d);" % [bpm, beats]
	JavaScriptBridge.eval(js_code)

func _start_playing():
	is_playing = true
	song_time = 0.0

	# Start audio playback
	if OS.has_feature("web"):
		AudioManager.play_song_web()
	else:
		var audio_path = song_data.get("path", "")
		if audio_path:
			AudioManager.play_song_native(audio_path)

func _process(delta):
	if not is_playing or is_paused:
		return

	# Sync with actual audio playback position
	if AudioManager.is_playing():
		song_time = AudioManager.get_playback_position()
	else:
		song_time += delta
	_spawn_upcoming_notes()
	_update_notes(delta)
	_check_input()
	_update_ui()

func _spawn_upcoming_notes():
	var spawn_time = song_time + SPAWN_AHEAD_TIME
	var notes_to_spawn = []

	for note in pending_notes:
		if note.time <= spawn_time:
			notes_to_spawn.append(note)

	for note in notes_to_spawn:
		pending_notes.erase(note)
		_spawn_note(note)

func _spawn_note(note_data: Dictionary):
	var lane_index = note_data.get("lane", 0)
	if lane_index < 0 or lane_index >= lanes.size():
		return

	var lane = lanes[lane_index]
	var note_sprite = ColorRect.new()
	note_sprite.custom_minimum_size = Vector2(0, 30)
	note_sprite.size = Vector2(lane.size.x - 10, 30)
	note_sprite.position = Vector2(5, -50)  # Start above the lane
	note_sprite.color = LANE_COLORS[lane_index]

	note_sprite.set_meta("hit_time", note_data.time)
	note_sprite.set_meta("lane", lane_index)
	note_sprite.set_meta("was_hit", false)

	lane.add_child(note_sprite)
	active_notes.append(note_sprite)

func _update_notes(delta):
	var hit_line_y = $LaneContainer.size.y - 25  # Position of hit line
	var notes_to_remove = []

	for note in active_notes:
		if not is_instance_valid(note):
			notes_to_remove.append(note)
			continue

		var hit_time = note.get_meta("hit_time")
		var time_until_hit = hit_time - song_time
		var target_y = hit_line_y - (time_until_hit * NOTE_SPEED)
		note.position.y = target_y

		# Check if note passed without being hit
		if time_until_hit < -0.15 and not note.get_meta("was_hit"):
			_register_miss(note)
			notes_to_remove.append(note)

	for note in notes_to_remove:
		if is_instance_valid(note):
			note.queue_free()
		active_notes.erase(note)

func _check_input():
	for i in range(8):
		var action_name = "drum_" + LANE_NAMES[i].to_lower().replace("-", "").replace(" ", "")
		if Input.is_action_just_pressed(action_name):
			_handle_drum_hit(i)

func _handle_drum_hit(lane_index: int):
	var closest_note = null
	var closest_time_diff = 999.0

	for note in active_notes:
		if not is_instance_valid(note):
			continue
		if note.get_meta("lane") != lane_index:
			continue
		if note.get_meta("was_hit"):
			continue

		var hit_time = note.get_meta("hit_time")
		var time_diff = abs(hit_time - song_time)

		if time_diff < closest_time_diff:
			closest_time_diff = time_diff
			closest_note = note

	if closest_note and closest_time_diff <= 0.15:
		_register_hit(closest_note, closest_time_diff)
	else:
		# Hit with no note - could penalize or ignore
		pass

func _register_hit(note: Node, time_diff: float):
	note.set_meta("was_hit", true)

	var rating: String
	var points: int

	if time_diff <= 0.025:
		rating = "PERFECT"
		points = 100
		hits_perfect += 1
	elif time_diff <= 0.05:
		rating = "GREAT"
		points = 75
		hits_great += 1
	else:
		rating = "GOOD"
		points = 50
		hits_good += 1

	combo += 1
	if combo > max_combo:
		max_combo = combo

	var combo_multiplier = min(1.0 + (combo * 0.1), 4.0)
	score += int(points * combo_multiplier)

	_show_hit_feedback(rating)

	# Visual feedback on note
	var tween = create_tween()
	tween.tween_property(note, "modulate:a", 0.0, 0.1)
	tween.tween_callback(note.queue_free)

func _register_miss(note: Node):
	hits_miss += 1
	combo = 0
	_show_hit_feedback("MISS")

func _show_hit_feedback(rating: String):
	var feedback = $HitFeedback
	feedback.text = rating

	match rating:
		"PERFECT":
			feedback.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		"GREAT":
			feedback.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		"GOOD":
			feedback.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
		"MISS":
			feedback.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

	var tween = create_tween()
	tween.tween_property(feedback, "modulate:a", 1.0, 0.05)
	tween.tween_interval(0.3)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.2)

func _update_ui():
	$HUD/TopBar/Score.text = str(score)
	if combo > 1:
		$HUD/ComboLabel.text = str(combo) + "x COMBO"
	else:
		$HUD/ComboLabel.text = ""

	# Update progress bar
	var duration = song_data.get("duration", 60.0)
	if duration > 0:
		$BottomBar/Progress.value = (song_time / duration) * 100.0

	# Check if song ended
	if pending_notes.is_empty() and active_notes.is_empty():
		_end_song()

func _on_pause_pressed():
	is_paused = not is_paused
	$BottomBar/PauseButton.text = "Resume" if is_paused else "Pause"
	if is_paused:
		AudioManager.pause()
	else:
		AudioManager.resume()

func _on_restart_pressed():
	_seek_to_position(0.0)

func _on_progress_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var progress_bar = $BottomBar/Progress
		var click_ratio = event.position.x / progress_bar.size.x
		var duration = song_data.get("duration", 60.0)
		var seek_time = click_ratio * duration
		_seek_to_position(seek_time)

func _seek_to_position(position: float):
	var duration = song_data.get("duration", 60.0)
	position = clamp(position, 0.0, duration)

	# Stop audio and seek
	AudioManager.seek(position)
	song_time = position

	# Clear all active notes
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
	active_notes.clear()

	# Reset pending notes to include notes after the seek position
	pending_notes = []
	var all_onsets = song_data.get("onsets", [])
	for onset in all_onsets:
		if onset.time >= position - 0.5:  # Include notes slightly before for visual
			pending_notes.append(onset.duplicate())

	# Reset scoring for fair restart
	if position == 0.0:
		score = 0
		combo = 0
		max_combo = 0
		hits_perfect = 0
		hits_great = 0
		hits_good = 0
		hits_miss = 0

	# Update UI
	_update_ui()

func _on_slow_down_pressed():
	var current_rate = AudioManager.get_playback_rate()
	var new_rate = max(0.25, current_rate - 0.25)
	AudioManager.set_playback_rate(new_rate)
	_update_speed_label()

func _on_speed_up_pressed():
	var current_rate = AudioManager.get_playback_rate()
	var new_rate = min(2.0, current_rate + 0.25)
	AudioManager.set_playback_rate(new_rate)
	_update_speed_label()

func _update_speed_label():
	var rate = AudioManager.get_playback_rate()
	$BottomBar/SpeedLabel.text = "%.2fx" % rate

func _on_quit_pressed():
	AudioManager.stop()
	get_tree().change_scene_to_file("res://scenes/song_library.tscn")

func _end_song():
	AudioManager.stop()
	is_playing = false
	GameState.last_results = {
		"score": score,
		"max_combo": max_combo,
		"perfect": hits_perfect,
		"great": hits_great,
		"good": hits_good,
		"miss": hits_miss,
		"song_name": song_data.get("name", "Unknown")
	}
	get_tree().change_scene_to_file("res://scenes/results.tscn")
