extends Control

@onready var status_label: Label = $VBox/StatusLabel
@onready var ip_input: LineEdit  = $VBox/IPInput
@onready var host_btn: Button    = $VBox/HostBtn
@onready var join_btn: Button    = $VBox/JoinBtn

var _on_web := OS.has_feature("web")

func _ready() -> void:
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	var nm := get_node("/root/NetworkManager")
	nm.connected_to_server.connect(_on_connected)
	nm.connection_failed.connect(_on_failed)
	nm.player_connected.connect(_on_player_connected)

	if _on_web:
		# No browser, o LineEdit é problemático — usa prompt() nativo ao clicar
		ip_input.focus_mode = Control.FOCUS_NONE
		ip_input.mouse_filter = Control.MOUSE_FILTER_STOP
		ip_input.gui_input.connect(_on_input_field_clicked)
		ip_input.placeholder_text = "Toque aqui para colar o link"

func _on_input_field_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_ask_url_via_prompt()

func _ask_url_via_prompt() -> void:
	var current := ip_input.text if ip_input.text != "" else ""
	var result = JavaScriptBridge.eval(
		"window.prompt('Cole o link do túnel (ex: https://abc.trycloudflare.com):', '%s')" % current
	)
	if result != null and typeof(result) == TYPE_STRING and result != "":
		ip_input.text = result.strip_edges()

func _on_host() -> void:
	get_node("/root/NetworkManager").host()
	join_btn.disabled = true
	host_btn.disabled = true
	_start_game()

func _on_join() -> void:
	var addr := ip_input.text.strip_edges()
	if _on_web and addr.is_empty():
		# Garante que o usuário colou o link antes de tentar conectar
		_ask_url_via_prompt()
		addr = ip_input.text.strip_edges()
	if addr.is_empty():
		addr = "127.0.0.1"
	var nm := get_node("/root/NetworkManager")
	nm.join(addr)
	status_label.text = "Conectando a\n%s…" % nm._build_url(addr)
	host_btn.disabled = true
	join_btn.disabled = true

func _on_connected() -> void:
	status_label.text = "Conectado!"
	_start_game()

func _on_failed() -> void:
	status_label.text = "Falha ao conectar. Verifique o link e tente novamente."
	host_btn.disabled = false
	join_btn.disabled = false

func _on_player_connected(_peer_id: int) -> void:
	pass

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")
