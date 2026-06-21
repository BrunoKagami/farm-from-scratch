extends Node

const TILE_SIZE := 32
const GRID_W    := 20
const GRID_H    := 20
const FARM_RECT := Rect2i(6, 6, 8, 8)
const PLAYER_SPEED := 80.0
const PLAYER_SPAWN := Vector2(288, 280)

const CROPS := {
	"lumifruit": { "color": Color(0.2, 0.85, 0.4),  "grow_time": 5.0,  "sell_price": 20, "seed_cost": 5  },
	"voidroot":  { "color": Color(0.65, 0.2, 0.95), "grow_time": 10.0, "sell_price": 45, "seed_cost": 10 },
	"starbloom": { "color": Color(1.0,  0.85, 0.1),  "grow_time": 18.0, "sell_price": 80, "seed_cost": 20 },
}

const SEED_COSTS  := { "lumifruit_seed": 5,  "voidroot_seed": 10, "starbloom_seed": 20 }
const SELL_PRICES := { "lumifruit": 20, "voidroot": 45, "starbloom": 80, "wood": 8 }

# Árvores: posições fixas no gramado, longe da roça/loja/luminária/placa.
# As 5 próximas a (64,64) são só pra ver o efeito visual de várias juntas.
const TREE_SPAWN_POSITIONS := [
	Vector2(64, 64),
	Vector2(112, 64),
	Vector2(64, 112),
	Vector2(112, 116),
	Vector2(40, 144),
	Vector2(140, 92),
	Vector2(560, 64),
	Vector2(64, 560),
	Vector2(560, 560),
]
const TREE_REGROW_TIME := 30.0
const WOOD_YIELD := 2
