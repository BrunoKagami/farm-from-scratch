extends Node

# Persistência server-side em JSON, organizada dentro da própria pasta do
# projeto/servidor (não na pasta escondida de user:// do Godot), pra ficar
# fácil de inspecionar e fazer backup.
const SAVE_DIR := "res://saves/"
const PLAYERS_DIR := SAVE_DIR + "players/"
const WORLD_FILE := SAVE_DIR + "world.json"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PLAYERS_DIR)

func _sanitize_name(name: String) -> String:
	var clean := name.strip_edges().to_lower()
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_-]")
	clean = regex.sub(clean, "", true)
	return clean if not clean.is_empty() else "jogador"

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: falha ao escrever %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))

func load_player(name: String) -> Dictionary:
	return _read_json(PLAYERS_DIR + _sanitize_name(name) + ".json")

func save_player(name: String, state: Dictionary) -> void:
	_write_json(PLAYERS_DIR + _sanitize_name(name) + ".json", state)

func load_world() -> Dictionary:
	return _read_json(WORLD_FILE)

func save_world(state: Dictionary) -> void:
	_write_json(WORLD_FILE, state)
