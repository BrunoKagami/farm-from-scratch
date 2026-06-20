extends Node

const TILE_SIZE := 32
const GRID_W    := 20
const GRID_H    := 20
const FARM_RECT := Rect2i(6, 6, 8, 8)

const CROPS := {
	"lumifruit": { "color": Color(0.2, 0.85, 0.4),  "grow_time": 10.0, "sell_price": 20, "seed_cost": 5  },
	"voidroot":  { "color": Color(0.65, 0.2, 0.95), "grow_time": 20.0, "sell_price": 45, "seed_cost": 10 },
	"starbloom": { "color": Color(1.0,  0.85, 0.1),  "grow_time": 35.0, "sell_price": 80, "seed_cost": 20 },
}

const SEED_COSTS  := { "lumifruit_seed": 5,  "voidroot_seed": 10, "starbloom_seed": 20 }
const SELL_PRICES := { "lumifruit": 20, "voidroot": 45, "starbloom": 80 }
