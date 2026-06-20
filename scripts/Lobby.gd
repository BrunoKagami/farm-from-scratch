extends Control

@onready var status_label: Label = $VBox/StatusLabel
@onready var ip_input: LineEdit  = $VBox/IPInput
@onready var host_btn: Button    = $VBox/HostBtn
@onready var join_btn: Button    = $VBox/JoinBtn

func _ready() -> void:
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	var nm := get_node("/root/NetworkManager")
	nm.connected_to_server.connect(_on_connected)
	nm.connection_failed.connect(_on_failed)
	nm.player_connected.connect(_on_player_connected)

var _hosting := false

func _on_host() -> void:
	if _hosting:
		_start_game()
		return
	get_node("/root/NetworkManager").host()
	_hosting = true
	var tunnel_hint := "\nTúnel: cloudflared tunnel --url http://localhost:7777"
	status_label.text = "Hospedando na porta 7777…\n[Enter] para começar" + tunnel_hint
	join_btn.disabled = true

func _on_join() -> void:
	var addr := ip_input.text.strip_edges()
	if addr.is_empty():
		addr = "127.0.0.1"
	get_node("/root/NetworkManager").join(addr)
	status_label.text = "Conectando a %s…" % addr
	host_btn.disabled = true
	join_btn.disabled = true

func _on_connected() -> void:
	status_label.text = "Conectado! Aguardando…"
	_start_game()

func _on_failed() -> void:
	status_label.text = "Falha ao conectar."
	host_btn.disabled = false
	join_btn.disabled = false

func _on_player_connected(_peer_id: int) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not host_btn.disabled:
		_on_host()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")
