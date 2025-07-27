extends Node2D

var coins_collected = 0

func add_coins(amount):
	coins_collected += amount
	$UI/coin/Label.text = str(coins_collected)
	
func update_fuel_UI(value):
	$UI/fuel/ProgressBar.value = value
	#var stylebox = $UI/fuel/ProgressBar.get("custom_styles/fg")
	#stylebox.bg_color.h = lerp(0,0.3,value/100)
	if value < 20:
		$UI/fuel/AnimationPlayer.play("alarm")
	else:
		$UI/fuel/AnimationPlayer.play("idle")
