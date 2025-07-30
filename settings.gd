extends Control

var settings = {
	"infinite_jumps": false,
	"speed_multiplier": 1.0,
	"acceleration_multiplier": 1.0,
	"jump_height_multiplier": 1.0,
	"air_speed_multiplier": 1.0,
	"flip_sensitivity_multiplier": 1.0,
	"infinite_fuel": false,
	"music_enabled": true,
	"sfx_enabled": true,
	"master_volume": 1.0
}

@onready var infinite_jumps_check = $InfiniteJumpsCheck
@onready var speed_slider = $SpeedSlider
@onready var speed_label = $SpeedSlider/SpeedLabel
@onready var acceleration_slider = $AccelerationSlider
@onready var acceleration_label = $AccelerationSlider/AccelerationLabel
@onready var jump_height_slider = $JumpHeightSlider
@onready var jump_height_label = $JumpHeightSlider/JumpHeightLabel
@onready var air_speed_slider = $AirSpeedSlider
@onready var air_speed_label = $AirSpeedSlider/AirSpeedLabel
@onready var flip_sensitivity_slider = $FlipSensitivitySlider
@onready var flip_sensitivity_label = $FlipSensitivitySlider/FlipSensitivityLabel
@onready var infinite_fuel_check = $InfiniteFuelCheck
@onready var music_check = $MusicCheck
@onready var sfx_check = $SFXCheck
@onready var master_volume_slider = $MasterVolumeSlider
@onready var master_volume_label = $MasterVolumeSlider/MasterVolumeLabel

func _on_play_pressed():
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _ready():
	$Back.pressed.connect(_on_play_pressed)
	load_settings()
	connect_signals()
	update_ui()

func connect_signals():
	infinite_jumps_check.toggled.connect(_on_infinite_jumps_toggled)
	speed_slider.value_changed.connect(_on_speed_changed)
	acceleration_slider.value_changed.connect(_on_acceleration_changed)
	jump_height_slider.value_changed.connect(_on_jump_height_changed)
	air_speed_slider.value_changed.connect(_on_air_speed_changed)
	flip_sensitivity_slider.value_changed.connect(_on_flip_sensitivity_changed)
	infinite_fuel_check.toggled.connect(_on_infinite_fuel_toggled)
	music_check.toggled.connect(_on_music_toggled)
	sfx_check.toggled.connect(_on_sfx_toggled)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)

func update_ui():
	infinite_jumps_check.button_pressed = settings.infinite_jumps
	speed_slider.value = settings.speed_multiplier
	speed_label.text = "Speed: " + str(settings.speed_multiplier) + "x"
	acceleration_slider.value = settings.acceleration_multiplier
	acceleration_label.text = "Acceleration: " + str(settings.acceleration_multiplier) + "x"
	jump_height_slider.value = settings.jump_height_multiplier
	jump_height_label.text = "Jump Height: " + str(settings.jump_height_multiplier) + "x"
	air_speed_slider.value = settings.air_speed_multiplier
	air_speed_label.text = "Air Speed: " + str(settings.air_speed_multiplier) + "x"
	flip_sensitivity_slider.value = settings.flip_sensitivity_multiplier
	flip_sensitivity_label.text = "Flip Sensitivity: " + str(settings.flip_sensitivity_multiplier) + "x"
	infinite_fuel_check.button_pressed = settings.infinite_fuel
	music_check.button_pressed = settings.music_enabled
	sfx_check.button_pressed = settings.sfx_enabled
	master_volume_slider.value = settings.master_volume
	master_volume_label.text = "Volume: " + str(int(settings.master_volume * 100)) + "%"

func _on_infinite_jumps_toggled(enabled: bool):
	settings.infinite_jumps = enabled
	save_settings()

func _on_speed_changed(value: float):
	settings.speed_multiplier = value
	speed_label.text = "Speed: " + str(value) + "x"
	save_settings()

func _on_acceleration_changed(value: float):
	settings.acceleration_multiplier = value
	acceleration_label.text = "Acceleration: " + str(value) + "x"
	save_settings()

func _on_jump_height_changed(value: float):
	settings.jump_height_multiplier = value
	jump_height_label.text = "Jump Height: " + str(value) + "x"
	save_settings()

func _on_air_speed_changed(value: float):
	settings.air_speed_multiplier = value
	air_speed_label.text = "Air Speed: " + str(value) + "x"
	save_settings()

func _on_flip_sensitivity_changed(value: float):
	settings.flip_sensitivity_multiplier = value
	flip_sensitivity_label.text = "Flip Sensitivity: " + str(value) + "x"
	save_settings()

func _on_infinite_fuel_toggled(enabled: bool):
	settings.infinite_fuel = enabled
	save_settings()

func _on_music_toggled(enabled: bool):
	settings.music_enabled = enabled
	apply_audio_settings()
	save_settings()

func _on_sfx_toggled(enabled: bool):
	settings.sfx_enabled = enabled
	apply_audio_settings()
	save_settings()

func _on_master_volume_changed(value: float):
	settings.master_volume = value
	master_volume_label.text = "Volume: " + str(int(value * 100)) + "%"
	apply_audio_settings()
	save_settings()

func apply_audio_settings():
	var master_bus = AudioServer.get_bus_index("Master")
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(settings.master_volume))
	
	AudioServer.set_bus_mute(music_bus, not settings.music_enabled)
	AudioServer.set_bus_mute(sfx_bus, not settings.sfx_enabled)

func save_settings():
	var config = ConfigFile.new()
	for key in settings.keys():
		config.set_value("settings", key, settings[key])
	config.save("user://settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		for key in settings.keys():
			settings[key] = config.get_value("settings", key, settings[key])

func get_setting(key: String):
	var settings_scene = get_tree().get_first_node_in_group("Settings")
	if settings_scene:
		return settings_scene.settings.get(key)
	return null
