extends Node

const DAY_DURATION    := 120.0   # segundos reais por dia completo
const SYNC_INTERVAL   := 5.0     # host manda sync a cada N segundos
const SMOOTH_THRESHOLD := 0.02   # ~29 min de jogo — acima disso snap
const LERP_SPEED      := 2.0     # velocidade de correção suave (por segundo)

var time_of_day := 0.25          # 0.0–1.0, começa 06:00
var _sync_timer := 0.0
var _target_time := -1.0         # -1 = sem target pendente

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
		# Avança o clock local para manter fluidez entre syncs
		time_of_day += delta / DAY_DURATION
		if time_of_day >= 1.0:
			time_of_day -= 1.0

		# Aplica correção pendente
		if _target_time >= 0.0:
			var diff := _angular_diff(time_of_day, _target_time)
			if abs(diff) < 0.001:
				_target_time = -1.0
			else:
				time_of_day = _lerp_angle(time_of_day, _target_time, LERP_SPEED * delta)

	_update_hud()

@rpc("authority", "reliable")
func _receive_time(server_time: float) -> void:
	if multiplayer.is_server():
		return
	var diff: float = abs(_angular_diff(time_of_day, server_time))
	if diff >= SMOOTH_THRESHOLD:
		# Drift grande: snap imediato
		time_of_day = server_time
		_target_time = -1.0
	else:
		# Drift pequeno: correção suave
		_target_time = server_time

func _angular_diff(a: float, b: float) -> float:
	var d := b - a
	# Envolve diferença no range [-0.5, 0.5] para lidar com virada de dia
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
