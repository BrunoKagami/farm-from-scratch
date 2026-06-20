extends CanvasLayer

@onready var money_label: Label  = $MoneyLabel
@onready var inv_label: Label    = $InvLabel
@onready var crop_label: Label   = $CropLabel
@onready var shop_panel          = $ShopPanel

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	_on_money_changed(GameManager.money)
	refresh_inv()
	refresh_crop("lumifruit")

func _on_money_changed(amount: int) -> void:
	money_label.text = "$ %d" % amount

func refresh_inv() -> void:
	var parts: Array[String] = []
	for item in Inventory.items:
		parts.append("%s x%d" % [item, Inventory.items[item]])
	inv_label.text = "  ".join(parts) if parts.size() > 0 else ""

func refresh_crop(crop: String) -> void:
	var cost: int = GameData.CROPS[crop]["seed_cost"]
	crop_label.text = "Cultura: %s  (semente: $%d)" % [crop, cost]
