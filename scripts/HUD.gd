extends CanvasLayer

@onready var money_label: Label  = $MoneyLabel
@onready var inv_label: Label    = $InvLabel
@onready var crop_label: Label   = $CropLabel
@onready var clock_label: Label  = $ClockLabel
@onready var msg_label: Label    = $MsgLabel
@onready var tunnel_label: Label = $TunnelLabel

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	_on_money_changed(GameManager.money)
	refresh_inv()
	refresh_crop("lumifruit")
	tunnel_label.visible = multiplayer.is_server()
	if multiplayer.is_server():
		tunnel_label.text = "Host  porta 7777  |  cloudflared tunnel --url http://localhost:7777"

func _on_money_changed(amount: int) -> void:
	money_label.text = "$ %d" % amount

func refresh_inv() -> void:
	if Inventory.items.is_empty():
		inv_label.text = "Inv: vazio"
	else:
		var parts: Array[String] = []
		for item in Inventory.items:
			parts.append("%s x%d" % [item, Inventory.items[item]])
		inv_label.text = "Inv: " + "  ".join(parts)

func refresh_crop(crop: String) -> void:
	var cost: int = GameData.CROPS[crop]["seed_cost"]
	crop_label.text = "Cultura: %s  ($%d)" % [crop, cost]

func set_clock(hour: int, minute: int) -> void:
	var icon := "☀" if hour >= 6 and hour < 20 else "☾"
	clock_label.text = "%s %02d:%02d" % [icon, hour, minute]

func show_msg(text: String) -> void:
	msg_label.text = text
	msg_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func(): msg_label.visible = false)
