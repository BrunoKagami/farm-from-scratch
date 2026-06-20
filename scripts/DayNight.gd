extends Node

const DAY_DURATION     := 120.0
const SYNC_INTERVAL    := 5.0
const SMOOTH_THRESHOLD := 0.02
const LERP_SPEED       := 2.0

var time_of_day := 0.25
var _sync_timer := 0.0
var _target_time := -1.0

# Pontos de cor ao longo do dia (time_of_day 0.0–1.0 = 00:00–24:00)
const SKY := [
	[0.000, Color(0.04, 0.04, 0.12)],  # 00:00 meia-noite
	[0.208, Color(0.05, 0.05, 0.14)],  # 05:00 pré-amanhecer
	[0.250, Color(0.85, 0.45, 0.20)],  # 06:00 amanhecer laranja
	[0.292, Color(1.00, 0.85, 0.70)],  # 07:00 manhã dourada
	[0.333, Color(1.00, 1.00, 1.00)],  # 08:00 dia pleno
	[0.750, Color(1.00, 0.95, 0.85)],  # 18:00 tarde quente
	[0.792, Color(0.90, 0.45, 0.15)],  # 19:00 pôr do sol
	[0.833, Color(0.20, 0.10, 0.28)],  # 20:00 crepúsculo
	[0.875, Color(0.04, 0.04, 0.12)],  # 21:00 noite
	[1.000, Color(0.04, 0.04, 0.12)],  # 24:00 meia-noite
]

func _process(delta: float) -> void:
	if multiplayer.is_server():
		time_of_day += delta / DAY_DURATION
		if time_of_day >= 1.0:
			time_of_day -= 1.0
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			rpc("_receive_time", time_of_day)
	else:
		time_of_day += delta / DAY_DURATION
		if time_of_day >= 1.0:
			time_of_day -= 1.0
		if _target_time >= 0.0:
			var diff := _angular_diff(time_of_day, _target_time)
			if abs(diff) < 0.001:
				_target_time = -1.0
			else:
				time_of_day = _lerp_angle(time_of_day, _target_time, LERP_SPEED * delta)

	_update_hud()
	_update_light()

@rpc("authority", "reliable")
func _receive_time(server_time: float) -> void:
	if multiplayer.is_server():
		return
	var diff: float = abs(_angular_diff(time_of_day, server_time))
	if diff >= SMOOTH_THRESHOLD:
		time_of_day = server_time
		_target_time = -1.0
	else:
		_target_time = server_time

func _sky_color() -> Color:
	for i in range(SKY.size() - 1):
		var t0: float = SKY[i][0]
		var t1: float = SKY[i + 1][0]
		if time_of_day >= t0 and time_of_day < t1:
			var f := (time_of_day - t0) / (t1 - t0)
			return (SKY[i][1] as Color).lerp(SKY[i + 1][1] as Color, f)
	return SKY[0][1] as Color

func _update_light() -> void:
	var cm := get_node_or_null("/root/World/CanvasModulate")
	if cm:
		cm.color = _sky_color()

func _angular_diff(a: float, b: float) -> float:
	var d := b - a
	if d > 0.5:  d -= 1.0
	if d < -0.5: d += 1.0
	return d

func _lerp_angle(current: float, target: float, t: float) -> float:
	var d := _angular_diff(current, target)
	return fmod(current + d * t + 1.0, 1.0)

func _update_hud() -> void:
	var hours   := int(time_of_day * 24)
	var minutes := int((time_of_day * 24 - hours) * 60)
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("set_clock"):
		hud.set_clock(hours, minutes)
