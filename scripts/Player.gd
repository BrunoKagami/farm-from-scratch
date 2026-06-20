extends CharacterBody2D

const SPEED := 80.0

var selected_crop: String = "lumifruit"
var _last_dir := "down"

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	velocity = direction * SPEED
	move_and_slide()
	_update_anim(direction)

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
	var tile: Node2D = world_grid.get_tile(grid_pos)
	if tile == null:
		return

	var s: int = tile.get("state")
	var my_id := multiplayer.get_unique_id()
	var offline := multiplayer.multiplayer_peer is OfflineMultiplayerPeer

	if s == 0:  # EMPTY — plantar
		var cost: int = GameData.CROPS[selected_crop]["seed_cost"]
		if not GameManager.spend_money(cost):
			return
		if offline:
			world_grid.server_plant(grid_pos, selected_crop, my_id)
		else:
			world_grid.rpc_id(1, "server_plant", grid_pos, selected_crop, my_id)
	elif s == 2:  # READY — colher
		if offline:
			world_grid.server_harvest(grid_pos, my_id)
		else:
			world_grid.rpc_id(1, "server_harvest", grid_pos, my_id)

func _update_anim(dir: Vector2) -> void:
	if _anim == null:
		return
	if dir == Vector2.ZERO:
		_anim.play("idle_" + _last_dir)
		return
	if abs(dir.x) >= abs(dir.y):
		_last_dir = "right" if dir.x > 0 else "left"
	else:
		_last_dir = "down" if dir.y > 0 else "up"
	_anim.play("walk_" + _last_dir)

func _cycle_crop() -> void:
	var crops := ["lumifruit", "voidroot", "starbloom"]
	var idx := crops.find(selected_crop)
	selected_crop = crops[(idx + 1) % crops.size()]
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("refresh_crop"):
		hud.refresh_crop(selected_crop)

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
