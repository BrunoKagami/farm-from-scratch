extends CharacterBody2D

const SPEED := 80.0
const TILE_SIZE := 32

var selected_crop: String = "lumifruit"

func _physics_process(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	velocity = direction * SPEED
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("next_crop"):
		_cycle_crop()

func _try_interact() -> void:
	var tile := _get_tile_at_position(global_position)
	if tile == null:
		return
	if tile.state == tile.State.EMPTY:
		var gm: Node = get_node("/root/GameManager")
		var cost: int = tile.CROPS[selected_crop]["seed_cost"]
		if gm.spend_money(cost):
			tile.plant(selected_crop)
	elif tile.state == tile.State.READY:
		var crop := tile.harvest()
		if crop != "":
			var gm: Node = get_node("/root/GameManager")
			gm.add_money(tile.CROPS[crop]["sell_price"])

func _cycle_crop() -> void:
	var crops := ["lumifruit", "voidroot", "starbloom"]
	var idx := crops.find(selected_crop)
	selected_crop = crops[(idx + 1) % crops.size()]
	print("Selected crop: ", selected_crop)

func _get_tile_at_position(pos: Vector2) -> Node:
	var world := get_node_or_null("/root/World")
	if world == null:
		return null
	var grid_pos := Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))
	return world.get_tile(grid_pos)
