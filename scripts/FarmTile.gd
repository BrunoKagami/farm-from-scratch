extends Node2D
class_name FarmTile

enum State { EMPTY, PLANTED, READY }

var state: State = State.EMPTY
var crop_type: String = ""
var grow_progress: float = 0.0

func apply_state(new_state: int, crop: String, progress: float = 0.0) -> void:
	state = new_state as State
	crop_type = crop
	grow_progress = progress
	queue_redraw()

func _draw() -> void:
	var T  := GameData.TILE_SIZE
	var cx := T / 2
	var cy := T / 2
	match state:
		State.EMPTY:
			pass
		State.PLANTED:
			var c: Color = (GameData.CROPS[crop_type]["color"] as Color).darkened(0.4)
			var h := int(lerp(T * 0.2, T * 0.55, grow_progress))
			var w := int(lerp(T * 0.12, T * 0.28, grow_progress))
			draw_rect(Rect2(cx - 1, cy + T/6, 3, h / 2), c.lightened(0.1))
			draw_rect(Rect2(cx - w/2, cy + T/6 - h/2, w, h / 2), c)
			draw_rect(Rect2(cx - w/4, cy + T/6 - h, w / 2, h / 2), c.lightened(0.15))
			draw_rect(Rect2(2, T - 5, T - 4, 3), Color(0, 0, 0, 0.4))
			draw_rect(Rect2(2, T - 5, int((T - 4) * grow_progress), 3),
			          (GameData.CROPS[crop_type]["color"] as Color))
		State.READY:
			var c: Color = GameData.CROPS[crop_type]["color"] as Color
			draw_rect(Rect2(cx - 2, cy + T/5, 4, T/3), c.darkened(0.3))
			draw_rect(Rect2(cx - T/5, cy - T/5, T*2/5, T*2/5), c)
			draw_rect(Rect2(cx - T/7, cy - T/3, T*2/7, T/4), c.lightened(0.2))
			draw_rect(Rect2(cx + T/8, cy - T/6, T/5, T/5), c.lightened(0.1))
			draw_rect(Rect2(cx - T/3, cy - T/8, T/5, T/5), c.lightened(0.1))
			draw_rect(Rect2(cx - T/4, cy - T/4, 4, 4), Color(1, 1, 1, 0.7))
