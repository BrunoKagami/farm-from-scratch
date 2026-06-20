extends Node2D

const GRID_W := 20
const GRID_H := 20
const TILE_SIZE := 32

var tile_scene := preload("res://scenes/FarmTile.tscn")
var tiles: Dictionary = {}

func _ready() -> void:
	_build_grid()
	_setup_input_map()

func _build_grid() -> void:
	for y in GRID_H:
		for x in GRID_W:
			var tile: Node2D = tile_scene.instantiate()
			tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			tile.name = "Tile_%d_%d" % [x, y]
			add_child(tile)
			tiles[Vector2i(x, y)] = tile

func get_tile(grid_pos: Vector2i) -> Node:
	return tiles.get(grid_pos, null)

func _setup_input_map() -> void:
	_add_action_key("interact", KEY_E)
	_add_action_key("next_crop", KEY_TAB)

func _add_action_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.keycode = key
		InputMap.action_add_event(action, ev)
