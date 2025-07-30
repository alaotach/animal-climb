extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Boost collision detected with: ", body.name)
	if body.name == "Cow" or body.has_method("revive"):
		print("Player collected boost!")
		body.revive()
		$AnimationPlayer.play("pickup")
		$CollisionShape2D.set_deferred("disabled", true)
		queue_free()
	else:
		print("Not the player, body type: ", body.get_class())
