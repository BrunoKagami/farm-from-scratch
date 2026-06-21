extends CanvasLayer

@onready var money_label: Label  = $MoneyLabel
@onready var inv_label: Label    = $InvLabel
@onready var crop_label: Label   = $CropLabel
@onready var clock_label: Label  = $ClockLabel
@onready var msg_label: Label    = $MsgLabel
@onready var tunnel_label: Label = $TunnelLabel

# Debug temporário: mostra X,Y do jogador local e de cada jogador remoto,
# pra diagnosticar divergência de posição entre clientes.
var debug_pos_label: Label

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	_on_money_changed(GameManager.money)
	refresh_inv()
	refresh_crop("lumifruit")
	tunnel_label.visible = multiplayer.is_server()
	if multiplayer.is_server():
		tunnel_label.text = "Host  porta 7777  |  cloudflared tunnel --url http://localhost:7777"

	debug_pos_label = Label.new()
	debug_pos_label.name = "DebugPosLabel"
	debug_pos_label.anchor_top = 1.0
	debug_pos_label.anchor_bottom = 1.0
	debug_pos_label.offset_left = 8
	debug_pos_label.offset_top = -52
	debug_pos_label.offset_right = 400
	debug_pos_label.offset_bottom = -28
	add_child(debug_pos_label)

func update_debug_positions(text: String) -> void:
	debug_pos_label.text = text

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
