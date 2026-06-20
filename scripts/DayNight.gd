extends Node

signal hour_changed(hour: int)

const DAY_DURATION := 120.0  # segundos por dia completo

var time_of_day := 0.25  # começa 06:00

func _process(delta: float) -> void:
	time_of_day += delta / DAY_DURATION
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	var hours := int(time_of_day * 24)
	var minutes := int((time_of_day * 24 - hours) * 60)
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("set_clock"):
		hud.set_clock(hours, minutes)
