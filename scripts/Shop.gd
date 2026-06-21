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

# Compra/venda não mexem mais em Inventory/GameManager direto: é só um
# pedido pro servidor, que é quem decide de verdade e manda o resultado
# de volta via WorldGrid._apply_economy_state.

func _sell(crop: String, _price: int) -> void:
	if Inventory.count(crop) <= 0:
		_show("Sem %s no inventário." % crop)
		return
	var world_grid := get_node_or_null("/root/World")
	if world_grid == null:
		return
	world_grid.request_sell_crop(crop)
	_show("Vendendo %s..." % crop)

func _buy_seed(seed: String, cost: int) -> void:
	if GameManager.money < cost:
		_show("Dinheiro insuficiente.")
		return
	var world_grid := get_node_or_null("/root/World")
	if world_grid == null:
		return
	world_grid.request_buy_seed(seed)
	_show("Comprando %s..." % seed)

func _show(text: String) -> void:
	if is_instance_valid(msg_label):
		msg_label.text = text
