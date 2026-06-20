extends PanelContainer

@onready var msg_label: Label = $VBox/MsgLabel

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox := $VBox

	for crop in GameData.SELL_PRICES:
		var price: int = GameData.SELL_PRICES[crop]
		var btn := Button.new()
		btn.text = "Vender %s  +$%d" % [crop, price]
		btn.pressed.connect(_sell.bind(crop, price))
		vbox.add_child(btn)

	for seed in GameData.SEED_COSTS:
		var cost: int = GameData.SEED_COSTS[seed]
		var btn := Button.new()
		btn.text = "Comprar %s  -$%d" % [seed, cost]
		btn.pressed.connect(_buy_seed.bind(seed, cost))
		vbox.add_child(btn)

	var close := Button.new()
	close.text = "Fechar"
	close.pressed.connect(func(): visible = false)
	vbox.add_child(close)

func _sell(crop: String, price: int) -> void:
	var qty: int = Inventory.count(crop)
	if qty <= 0:
		_show("Sem %s no inventário." % crop)
		return
	Inventory.remove(crop)
	GameManager.add_money(price)
	_show("Vendido %s! +$%d" % [crop, price])
	_refresh_hud()

func _buy_seed(seed: String, cost: int) -> void:
	if not GameManager.spend_money(cost):
		_show("Dinheiro insuficiente.")
		return
	Inventory.add(seed)
	_show("Comprado: %s" % seed)
	_refresh_hud()

func _show(text: String) -> void:
	if is_instance_valid(msg_label):
		msg_label.text = text

func _refresh_hud() -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("refresh_inv"):
		hud.refresh_inv()
