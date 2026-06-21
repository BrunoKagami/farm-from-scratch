extends Node

signal money_changed(new_amount: int)

var money: int = 100

func _ready() -> void:
	print("Farm From Scratch — GameManager ready")
	Inventory.add("lumifruit_seed", 3)
	Inventory.add("voidroot_seed", 1)

# Chamado quando o servidor (autoridade real) confirma/corrige nosso saldo.
func set_money_authoritative(amount: int) -> void:
	if amount == money:
		return
	money = amount
	emit_signal("money_changed", money)
