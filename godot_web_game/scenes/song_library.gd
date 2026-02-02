extends Control

signal song_selected(song_data: Dictionary)

var songs: Array = []
var _js_callback: JavaScriptObject = null

func _ready():
	$MarginContainer/VBoxContainer/Header/BackButton.pressed.connect(_on_back_pressed)
	$MarginContainer/VBoxContainer/UploadSection/UploadButton.pressed.connect(_on_upload_pressed)
	$FileDialog.file_selected.connect(_on_file_selected)

	if OS.has_feature("web"):
		_setup_web_callbacks()

	_load_songs()

func _setup_web_callbacks():
	# Create callback for when file processing is complete
	_js_callback = JavaScriptBridge.create_callback(_on_web_file_processed)
	JavaScriptBridge.get_interface("window").drumalong_godot_callback = _js_callback

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_upload_pressed():
	if OS.has_feature("web"):
		_trigger_web_file_upload()
	else:
		$FileDialog.popup_centered()

func _trigger_web_file_upload():
	_update_status("Selecting file...")

	var js_code = """
	(async function() {
		try {
			const fileInfo = await window.drumalong.triggerFileUpload();
			window.drumalong_godot_callback('file_selected', JSON.stringify(fileInfo));

			window.drumalong_godot_callback('status', 'Decoding audio...');
			const audioInfo = await window.drumalong.decodeAudioFile();

			window.drumalong_godot_callback('status', 'Analyzing drum hits...');
			const samples = window.drumalong.getAudioSamples(22050);
			const onsets = window.drumalong_detectOnsets(samples, 22050);

			window.drumalong_godot_callback('status', 'Detecting tempo...');
			const bpm = window.drumalong_estimateTempo(onsets);

			window.drumalong_godot_callback('status', 'Saving song...');
			const songData = {
				id: Date.now().toString(),
				name: fileInfo.name.replace(/\\.[^/.]+$/, ''),
				duration: audioInfo.duration,
				sampleRate: audioInfo.sampleRate,
				bpm: bpm,
				onsets: onsets
			};

			// Store in IndexedDB
			await window.drumalong_db.saveSong(songData);

			window.drumalong_godot_callback('song_added', JSON.stringify(songData));
			window.drumalong_godot_callback('status', 'Ready to play!');
		} catch (err) {
			window.drumalong_godot_callback('error', err.message);
		}
	})();
	"""
	JavaScriptBridge.eval(js_code)

func _on_web_file_processed(args):
	var event_type = args[0]
	var data = args[1] if args.size() > 1 else ""

	match event_type:
		"status":
			_update_status(data)
		"file_selected":
			var info = JSON.parse_string(data)
			if info:
				_update_status("Processing: " + info.get("name", ""))
		"song_added":
			var song_data = JSON.parse_string(data)
			if song_data:
				_add_song(song_data)
		"error":
			_update_status("Error: " + data)
			push_error("File upload error: " + data)

func _on_file_selected(path: String):
	_update_status("Processing: " + path.get_file())
	_process_audio_file_native(path)

func _process_audio_file_native(path: String):
	_update_status("Loading audio...")

	# Load audio file
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_update_status("Error: Could not open file")
		return

	var audio_stream: AudioStream = null
	var ext = path.get_extension().to_lower()

	match ext:
		"mp3":
			audio_stream = AudioStreamMP3.new()
			audio_stream.data = file.get_buffer(file.get_length())
		"ogg":
			audio_stream = AudioStreamOggVorbis.load_from_file(path)
		"wav":
			audio_stream = AudioStreamWAV.new()
			# WAV loading is more complex, skip for now
			_update_status("WAV support coming soon")
			return
		_:
			_update_status("Unsupported format: " + ext)
			return

	file.close()

	if not audio_stream:
		_update_status("Error: Could not decode audio")
		return

	_update_status("Analyzing drum hits...")

	# For native, we'll use a simplified onset detection
	# Full analysis would require AudioEffectCapture or similar
	var song_data = {
		"id": str(Time.get_unix_time_from_system()),
		"name": path.get_file().get_basename(),
		"path": path,
		"duration": audio_stream.get_length(),
		"onsets": _generate_placeholder_onsets(audio_stream.get_length())
	}

	_add_song(song_data)
	_update_status("Ready to play!")

func _generate_placeholder_onsets(duration: float) -> Array:
	# Generate demo onsets until proper native analysis is implemented
	var onsets = []
	var time = 1.0
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(duration)
	var drum_types = ["kick", "snare", "hihat", "high_tom", "mid_tom", "floor_tom", "crash", "ride"]

	while time < duration - 1.0:
		var lane = rng.randi() % 8
		onsets.append({
			"time": time,
			"lane": lane,
			"type": drum_types[lane]
		})
		time += 0.25 + rng.randf() * 0.5

	return onsets

func _add_song(song_data: Dictionary):
	# Check if song already exists
	for existing in songs:
		if existing.get("id") == song_data.get("id"):
			return

	songs.append(song_data)
	_refresh_song_list()
	_save_songs()

func _load_songs():
	if OS.has_feature("web"):
		_load_songs_web()
	else:
		_load_songs_native()
	_refresh_song_list()

func _load_songs_web():
	var js_code = """
	(async function() {
		try {
			const songs = await window.drumalong_db.getAllSongs();
			window.drumalong_godot_callback('songs_loaded', JSON.stringify(songs));
		} catch (err) {
			console.error('Failed to load songs:', err);
			window.drumalong_godot_callback('songs_loaded', '[]');
		}
	})();
	"""
	JavaScriptBridge.eval(js_code)

func _load_songs_native():
	var config = ConfigFile.new()
	if config.load("user://songs.cfg") == OK:
		var count = config.get_value("songs", "count", 0)
		for i in range(count):
			var song_json = config.get_value("songs", "song_" + str(i), "{}")
			var song = JSON.parse_string(song_json)
			if song:
				songs.append(song)

func _save_songs():
	if OS.has_feature("web"):
		return  # Web uses IndexedDB, saved automatically

	var config = ConfigFile.new()
	config.set_value("songs", "count", songs.size())
	for i in range(songs.size()):
		config.set_value("songs", "song_" + str(i), JSON.stringify(songs[i]))
	config.save("user://songs.cfg")

func _refresh_song_list():
	var song_list = $MarginContainer/VBoxContainer/ScrollContainer/SongList

	# Clear existing items except the empty label
	for child in song_list.get_children():
		if child.name != "EmptyLabel":
			child.queue_free()

	# Wait a frame for queue_free to process
	await get_tree().process_frame

	var empty_label = song_list.get_node_or_null("EmptyLabel")
	if empty_label:
		empty_label.visible = songs.is_empty()

	for song in songs:
		var item = _create_song_item(song)
		song_list.add_child(item)

func _create_song_item(song_data: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 60)

	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = song_data.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 18)
	info_container.add_child(name_label)

	var duration = song_data.get("duration", 0.0)
	var duration_str = "%d:%02d" % [int(duration) / 60, int(duration) % 60]
	var notes_count = song_data.get("onsets", []).size()
	var bpm = song_data.get("bpm", 120)

	var details_label = Label.new()
	details_label.text = "%s | %d BPM | %d notes" % [duration_str, bpm, notes_count]
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_container.add_child(details_label)

	container.add_child(info_container)

	var play_button = Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(80, 40)
	play_button.pressed.connect(_on_play_song.bind(song_data))
	container.add_child(play_button)

	var delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 40)
	delete_button.pressed.connect(_on_delete_song.bind(song_data))
	container.add_child(delete_button)

	return container

func _on_play_song(song_data: Dictionary):
	GameState.current_song = song_data
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func _on_delete_song(song_data: Dictionary):
	if OS.has_feature("web"):
		var song_id = song_data.get("id", "")
		var js_code = "window.drumalong_db.deleteSong('%s');" % song_id
		JavaScriptBridge.eval(js_code)

	songs.erase(song_data)
	_refresh_song_list()
	_save_songs()

func _update_status(text: String):
	$MarginContainer/VBoxContainer/UploadSection/UploadStatus.text = text
