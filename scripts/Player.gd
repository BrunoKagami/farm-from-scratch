extends CharacterBody2D

const SPEED := 80.0

var selected_crop: String = "lumifruit"

func _ready() -> void:
	if not multiplayer.is_server() and multiplayer.get_unique_id() != name.to_int():
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	velocity = direction * SPEED
	move_and_slide()

	var world_grid := get_node_or_null("/root/World")
	if world_grid and world_grid.has_method("send_player_state"):
		world_grid.send_player_state(global_position, velocity)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("next_crop"):
		_cycle_crop()

func _try_interact() -> void:
	if _near_shop():
		_open_shop()
		return
	var grid_pos := Vector2i(
		int(global_position.x / GameData.TILE_SIZE),
		int(global_position.y / GameData.TILE_SIZE)
	)
	var world_grid := get_node_or_null("/root/World")
	if world_grid == null:
		return
	var tile := world_grid.get_tile(grid_pos)
	if tile == null:
		return
	if tile.state == tile.State.EMPTY:
		rpc_id(1, "_request_plant_rpc", grid_pos, selected_crop)
	elif tile.state == tile.State.READY:
		rpc_id(1, "_request_harvest_rpc", grid_pos)

@rpc("any_peer", "reliable")
func _request_plant_rpc(grid_pos: Vector2i, crop: String) -> void:
	var world_grid := get_node_or_null("/root/World")
	if world_grid:
		world_grid.request_plant(grid_pos, crop)

@rpc("any_peer", "reliable")
func _request_harvest_rpc(grid_pos: Vector2i) -> void:
	var world_grid := get_node_or_null("/root/World")
	if world_grid:
		world_grid.request_harvest(grid_pos)

func _cycle_crop() -> void:
	var crops := ["lumifruit", "voidroot", "starbloom"]
	var idx := crops.find(selected_crop)
	selected_crop = crops[(idx + 1) % crops.size()]

func _near_shop() -> bool:
	var shop := get_node_or_null("/root/World/Shop")
	if shop == null:
		return false
	return global_position.distance_to(shop.global_position) < 96.0

func _open_shop() -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud == null:
		return
	var panel := hud.get_node_or_null("ShopPanel")
	if panel:
		panel.visible = not panel.visible
