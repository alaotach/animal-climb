extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Boost collision detected with: ", body.name)
	if body.name == "Cow" or body.has_method("activate_speed_boost"):
		print("Player collected boost!")
		body.activate_speed_boost()
		queue_free()
	else:
		print("Not the player, body type: ", body.get_class())
