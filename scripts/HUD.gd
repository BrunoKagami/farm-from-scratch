extends CanvasLayer

@onready var money_label: Label = $MoneyLabel

func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.money_changed.connect(_on_money_changed)
		_on_money_changed(gm.money)

func _on_money_changed(amount: int) -> void:
	money_label.text = "$ %d" % amount
