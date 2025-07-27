extends Area2D

@export var value: int = 5
var picked = false

func _on_Coin_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") && !picked:
		get_tree().get_current_scene().add_coins(value)
		$AnimationPlayer.play("pickup")
		$CollisionShape2D.set_deferred("disabled", true)
		picked = true
		


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	queue_free()
