extends Area2D


func _on_Fuel_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().get_current_scene().get_node("Cow").refuel()
		$AnimationPlayer.play("pickup")
		$CollisionShape2D.set_deferred("disabled", true)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	queue_free()
