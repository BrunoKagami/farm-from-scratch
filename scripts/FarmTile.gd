extends Node2D

enum State { EMPTY, PLANTED, READY }

const CROPS = {
	"lumifruit": { "color": Color(0.2, 0.8, 0.4), "grow_time": 10.0, "sell_price": 20, "seed_cost": 5 },
	"voidroot":  { "color": Color(0.6, 0.2, 0.9), "grow_time": 20.0, "sell_price": 45, "seed_cost": 10 },
	"starbloom":  { "color": Color(1.0, 0.8, 0.1), "grow_time": 35.0, "sell_price": 80, "seed_cost": 20 },
}

var state: State = State.EMPTY
var crop_type: String = ""
var grow_timer: float = 0.0
var grow_duration: float = 0.0

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label

const TILE_SIZE := 32

func _ready() -> void:
	_update_visuals()

func _process(delta: float) -> void:
	if state == State.PLANTED:
		grow_timer += delta
		if grow_timer >= grow_duration:
			state = State.READY
			_update_visuals()

func plant(crop: String) -> void:
	if state != State.EMPTY:
		return
	crop_type = crop
	state = State.PLANTED
	grow_timer = 0.0
	grow_duration = CROPS[crop]["grow_time"]
	_update_visuals()

func harvest() -> String:
	if state != State.READY:
		return ""
	var harvested := crop_type
	state = State.EMPTY
	crop_type = ""
	_update_visuals()
	return harvested

func _update_visuals() -> void:
	match state:
		State.EMPTY:
			sprite.color = Color(0.15, 0.15, 0.25)
			label.text = ""
		State.PLANTED:
			sprite.color = CROPS[crop_type]["color"].darkened(0.4)
			label.text = "..."
		State.READY:
			sprite.color = CROPS[crop_type]["color"]
			label.text = "!"
