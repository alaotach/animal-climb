extends Node2D

@export var terrain_scene: PackedScene
@export var segment_length := 100.0
@export var wave_amplitude := 100.0
@export var wave_frequency := 0.05
@export var segment_resolution := 20
@export var ahead_distance := 1000.0

var last_x := 0.0

@onready var player := get_node("Cow/RigidBody2D/Cow")

func _process(_delta):
	var target_x = player.global_position.x + ahead_distance
	while last_x < target_x:
		_generate_segment()
