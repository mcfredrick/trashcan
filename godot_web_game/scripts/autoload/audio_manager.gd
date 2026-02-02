extends Node

signal playback_started
signal playback_stopped
signal playback_position_changed(position: float)

var _audio_player: AudioStreamPlayer = null
var _is_playing: bool = false
var _start_time: float = 0.0
var _js_source: JavaScriptObject = null
var _js_start_time: float = 0.0

func _ready():
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)
	_audio_player.finished.connect(_on_playback_finished)

func _process(_delta):
	if _is_playing:
		playback_position_changed.emit(get_playback_position())

func get_playback_position() -> float:
	if OS.has_feature("web"):
		return _get_web_playback_position()
	else:
		return _audio_player.get_playback_position()

func _get_web_playback_position() -> float:
	if _js_start_time > 0:
		var current_time = JavaScriptBridge.eval("window.drumalong.getAudioTime();")
		return current_time - _js_start_time
	return 0.0

func play_song_web():
	"""Play audio using Web Audio API (for web builds)"""
	var js_code = """
	(function() {
		try {
			// Stop any existing playback
			if (window.drumalong._currentSource) {
				window.drumalong._currentSource.stop();
			}

			const source = window.drumalong.createPlaybackSource();
			window.drumalong._currentSource = source;

			const startTime = window.drumalong.getAudioTime();
			source.start(0);

			return startTime;
		} catch (err) {
			console.error('Failed to start playback:', err);
			return 0;
		}
	})();
	"""
	var start_time = JavaScriptBridge.eval(js_code)
	_js_start_time = start_time if start_time else 0.0
	_is_playing = true
	playback_started.emit()

func stop_song_web():
	"""Stop Web Audio playback"""
	var js_code = """
	(function() {
		if (window.drumalong._currentSource) {
			window.drumalong._currentSource.stop();
			window.drumalong._currentSource = null;
		}
	})();
	"""
	JavaScriptBridge.eval(js_code)
	_is_playing = false
	_js_start_time = 0.0
	playback_stopped.emit()

func play_song_native(audio_path: String):
	"""Play audio from file path (for native builds)"""
	var audio_stream = _load_audio_stream(audio_path)
	if audio_stream:
		_audio_player.stream = audio_stream
		_audio_player.play()
		_is_playing = true
		playback_started.emit()
	else:
		push_error("Failed to load audio: " + audio_path)

func _load_audio_stream(path: String) -> AudioStream:
	var ext = path.get_extension().to_lower()

	match ext:
		"mp3":
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var stream = AudioStreamMP3.new()
				stream.data = file.get_buffer(file.get_length())
				file.close()
				return stream
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		_:
			push_error("Unsupported audio format: " + ext)

	return null

func stop():
	if OS.has_feature("web"):
		stop_song_web()
	else:
		_audio_player.stop()
		_is_playing = false
		playback_stopped.emit()

func pause():
	if OS.has_feature("web"):
		# Web Audio API doesn't have native pause, would need to track position
		stop_song_web()
	else:
		_audio_player.stream_paused = true

func resume():
	if OS.has_feature("web"):
		# Would need to resume from saved position
		play_song_web()
	else:
		_audio_player.stream_paused = false

func is_playing() -> bool:
	return _is_playing

func _on_playback_finished():
	_is_playing = false
	playback_stopped.emit()
