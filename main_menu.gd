extends Control

@onready var moo_sound = $Song

func _ready():
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	moo_sound.play()

func _on_play_pressed():
	get_tree().change_scene_to_file("res://Levels/level_1.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_quit_pressed():
	get_tree().quit()
