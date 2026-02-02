extends Control

func _ready():
	$VBoxContainer/ButtonContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$VBoxContainer/ButtonContainer/MenuButton.pressed.connect(_on_menu_pressed)
	_display_results()

func _display_results():
	var results = GameState.last_results
	if results.is_empty():
		return

	$VBoxContainer/SongName.text = results.get("song_name", "Unknown Song")
	$VBoxContainer/ScoreContainer/ScoreLabel.text = str(results.get("score", 0))
	$VBoxContainer/ScoreContainer/ComboLabel.text = "Max Combo: " + str(results.get("max_combo", 0))

	$VBoxContainer/StatsGrid/PerfectValue.text = str(results.get("perfect", 0))
	$VBoxContainer/StatsGrid/GreatValue.text = str(results.get("great", 0))
	$VBoxContainer/StatsGrid/GoodValue.text = str(results.get("good", 0))
	$VBoxContainer/StatsGrid/MissValue.text = str(results.get("miss", 0))

	var total_notes = results.get("perfect", 0) + results.get("great", 0) + results.get("good", 0) + results.get("miss", 0)
	var accuracy = 0.0
	if total_notes > 0:
		var weighted_hits = results.get("perfect", 0) * 1.0 + results.get("great", 0) * 0.75 + results.get("good", 0) * 0.5
		accuracy = (weighted_hits / total_notes) * 100.0

	$VBoxContainer/AccuracyLabel.text = "Accuracy: %.1f%%" % accuracy

func _on_retry_pressed():
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/song_library.tscn")
