extends Node

var items: Dictionary = {}

func add(item: String, qty: int = 1) -> void:
	items[item] = items.get(item, 0) + qty

func remove(item: String, qty: int = 1) -> bool:
	if items.get(item, 0) < qty:
		return false
	items[item] -= qty
	if items[item] == 0:
		items.erase(item)
	return true

func count(item: String) -> int:
	return items.get(item, 0)
