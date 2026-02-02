extends Control

func _ready():
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	print("DrumAlong is ready!")

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/song_library.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/calibration.tscn")
