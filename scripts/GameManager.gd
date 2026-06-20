extends Node

signal money_changed(new_amount: int)

var money: int = 100

func _ready() -> void:
	print("Farm From Scratch — GameManager ready")
	Inventory.add("lumifruit_seed", 3)
	Inventory.add("voidroot_seed", 1)

func add_money(amount: int) -> void:
	money += amount
	emit_signal("money_changed", money)

func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	emit_signal("money_changed", money)
	return true
