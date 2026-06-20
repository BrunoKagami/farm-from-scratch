extends Node2D

const TILESET_PATH := "res://assets/environment/tileset_initial.png"

const GRASS   := Vector2i(1, 4)
const DIRT_TL := Vector2i(0, 0)
const DIRT_T  := Vector2i(1, 0)
const DIRT_TR := Vector2i(2, 0)
const DIRT_L  := Vector2i(0, 1)
const DIRT_C  := Vector2i(1, 1)
const DIRT_R  := Vector2i(2, 1)
const DIRT_BL := Vector2i(0, 2)
const DIRT_B  := Vector2i(1, 2)
const DIRT_BR := Vector2i(2, 2)

const ALL_TILES := [GRASS, DIRT_TL, DIRT_T, DIRT_TR, DIRT_L, DIRT_C, DIRT_R, DIRT_BL, DIRT_B, DIRT_BR]

func _ready() -> void:
	var tex := load(TILESET_PATH)
	if tex == null:
		push_error("Tileset não encontrado: " + TILESET_PATH)
		return

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(GameData.TILE_SIZE, GameData.TILE_SIZE)
	for coord in ALL_TILES:
		source.create_tile(coord)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(GameData.TILE_SIZE, GameData.TILE_SIZE)
	tileset.add_source(source, 0)

	var tilemap := TileMapLayer.new()
	tilemap.tile_set = tileset
	tilemap.z_index = -2
	add_child(tilemap)
	_paint(tilemap)

func _paint(tilemap: TileMapLayer) -> void:
	var farm := GameData.FARM_RECT
	for y in GameData.GRID_H:
		for x in GameData.GRID_W:
			var pos := Vector2i(x, y)
			tilemap.set_cell(pos, 0, _pick_tile(x, y, farm))

func _pick_tile(x: int, y: int, farm: Rect2i) -> Vector2i:
	if not farm.has_point(Vector2i(x, y)):
		return GRASS
	var l := farm.position.x
	var r := farm.position.x + farm.size.x - 1
	var t := farm.position.y
	var b := farm.position.y + farm.size.y - 1
	if   x == l and y == t: return DIRT_TL
	elif x == r and y == t: return DIRT_TR
	elif x == l and y == b: return DIRT_BL
	elif x == r and y == b: return DIRT_BR
	elif y == t:             return DIRT_T
	elif y == b:             return DIRT_B
	elif x == l:             return DIRT_L
	elif x == r:             return DIRT_R
	else:                    return DIRT_C
