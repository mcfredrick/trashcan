extends Node

signal playback_started
signal playback_stopped
signal playback_position_changed(position: float)

var _audio_player: AudioStreamPlayer = null
var _is_playing: bool = false
var _is_paused: bool = false
var _start_time: float = 0.0
var _js_source: JavaScriptObject = null
var _js_start_time: float = 0.0
var _js_offset: float = 0.0  # Offset for seeking
var _pause_position: float = 0.0  # Position when paused
var _playback_rate: float = 1.0  # Speed multiplier

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
		# Account for playback rate in position calculation
		return ((current_time - _js_start_time) * _playback_rate) + _js_offset
	return _js_offset

func play_song_web(offset: float = 0.0):
	"""Play audio using Web Audio API (for web builds)"""
	_js_offset = offset
	var js_code = """
	(function() {
		try {
			// Stop any existing playback
			if (window.drumalong._currentSource) {
				window.drumalong._currentSource.stop();
			}

			const source = window.drumalong.createPlaybackSource();
			source.playbackRate.value = %f;
			window.drumalong._currentSource = source;
			window.drumalong._playbackRate = %f;

			const startTime = window.drumalong.getAudioTime();
			source.start(0, %f);

			return startTime;
		} catch (err) {
			console.error('Failed to start playback:', err);
			return 0;
		}
	})();
	""" % [_playback_rate, _playback_rate, offset]
	var start_time = JavaScriptBridge.eval(js_code)
	_js_start_time = start_time if start_time else 0.0
	_is_playing = true
	_is_paused = false
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
	_is_paused = false
	_js_start_time = 0.0
	_js_offset = 0.0
	playback_stopped.emit()

func play_song_native(audio_path: String):
	"""Play audio from file path (for native builds)"""
	var audio_stream = _load_audio_stream(audio_path)
	if audio_stream:
		_audio_player.stream = audio_stream
		_audio_player.pitch_scale = _playback_rate
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
		_is_paused = false
		_pause_position = 0.0
		playback_stopped.emit()

func pause():
	if not _is_playing:
		return
	_pause_position = get_playback_position()
	_is_paused = true
	if OS.has_feature("web"):
		stop_song_web()
		_is_paused = true  # Re-set since stop_song_web clears it
	else:
		_audio_player.stream_paused = true

func resume():
	if not _is_paused:
		return
	_is_paused = false
	if OS.has_feature("web"):
		play_song_web(_pause_position)
	else:
		_audio_player.stream_paused = false

func seek(position: float):
	"""Seek to a specific position in seconds"""
	var was_playing = _is_playing and not _is_paused
	if OS.has_feature("web"):
		if was_playing:
			stop_song_web()
			play_song_web(position)
		else:
			_js_offset = position
			_pause_position = position
	else:
		if _audio_player.stream:
			_audio_player.seek(position)
			if not was_playing:
				_pause_position = position

func get_duration() -> float:
	"""Get the duration of the current audio"""
	if OS.has_feature("web"):
		var duration = JavaScriptBridge.eval("window.drumalong.audioBuffer ? window.drumalong.audioBuffer.duration : 0;")
		return duration if duration else 0.0
	else:
		if _audio_player.stream:
			return _audio_player.stream.get_length()
	return 0.0

func set_playback_rate(rate: float):
	"""Set playback speed (0.5 = half speed, 2.0 = double speed)"""
	_playback_rate = clamp(rate, 0.25, 2.0)
	if OS.has_feature("web"):
		if _is_playing:
			# Need to restart playback with new rate
			var current_pos = get_playback_position()
			stop_song_web()
			play_song_web(current_pos)
		else:
			# Just store the rate for next playback
			JavaScriptBridge.eval("window.drumalong._playbackRate = %f;" % _playback_rate)
	else:
		_audio_player.pitch_scale = _playback_rate

func get_playback_rate() -> float:
	"""Get current playback speed"""
	return _playback_rate

func is_playing() -> bool:
	return _is_playing

func _on_playback_finished():
	_is_playing = false
	playback_stopped.emit()
