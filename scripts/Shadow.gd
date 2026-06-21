extends Node2D

# Sombra estática simples (elipse, sem antialiasing) — combina melhor com
# pixel art do que sombra "de verdade" calculada por luz/oclusão, que tem
# borda suave e comprimento sem limite (ficava feia e exagerada).
var width: float = 14.0
var height: float = 7.0
var alpha: float = 0.35

func _ready() -> void:
	z_as_relative = true
	z_index = -1

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(width * 0.5, height * 0.5))
	draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, alpha), true, -1.0, false)
