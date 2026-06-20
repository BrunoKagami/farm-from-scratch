extends Control

@onready var status_label: Label = $VBox/StatusLabel
@onready var ip_input: LineEdit  = $VBox/IPInput
@onready var host_btn: Button    = $VBox/HostBtn
@onready var join_btn: Button    = $VBox/JoinBtn

var _on_web := OS.has_feature("web")
var _waiting_for_input := false

func _ready() -> void:
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	var nm := get_node("/root/NetworkManager")
	nm.connected_to_server.connect(_on_connected)
	nm.connection_failed.connect(_on_failed)
	nm.player_connected.connect(_on_player_connected)

	if _on_web:
		ip_input.focus_mode = Control.FOCUS_NONE
		ip_input.mouse_filter = Control.MOUSE_FILTER_STOP
		ip_input.gui_input.connect(_on_input_field_clicked)
		ip_input.placeholder_text = "Toque aqui para colar o link"

func _process(_delta: float) -> void:
	if not _waiting_for_input:
		return
	var result = JavaScriptBridge.eval("window.__ffs_url__ || ''")
	if result != null and typeof(result) == TYPE_STRING and result != "":
		JavaScriptBridge.eval("window.__ffs_url__ = ''")
		_waiting_for_input = false
		ip_input.text = (result as String).strip_edges()

func _on_input_field_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_url_overlay()

func _show_url_overlay() -> void:
	_waiting_for_input = true
	JavaScriptBridge.eval("""
		(function() {
			if (document.getElementById('__ffs_overlay__')) return;
			var ov = document.createElement('div');
			ov.id = '__ffs_overlay__';
			ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.85);z-index:9999;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;';
			var lbl = document.createElement('p');
			lbl.textContent = 'Cole o link do túnel:';
			lbl.style.cssText = 'color:#fff;font-size:20px;font-family:sans-serif;margin:0;';
			var inp = document.createElement('input');
			inp.type = 'url';
			inp.autocomplete = 'off';
			inp.placeholder = 'https://abc.trycloudflare.com';
			inp.style.cssText = 'width:80%;max-width:400px;padding:14px;font-size:17px;border-radius:10px;border:none;outline:none;';
			var btn = document.createElement('button');
			btn.textContent = 'Conectar';
			btn.style.cssText = 'padding:14px 32px;font-size:18px;background:#3a9;color:#fff;border:none;border-radius:10px;cursor:pointer;font-family:sans-serif;';
			function confirm() {
				if (!inp.value) return;
				window.__ffs_url__ = inp.value;
				document.body.removeChild(ov);
			}
			btn.onclick = confirm;
			inp.addEventListener('keydown', function(e){ if(e.key==='Enter') confirm(); });
			ov.appendChild(lbl);
			ov.appendChild(inp);
			ov.appendChild(btn);
			document.body.appendChild(ov);
			setTimeout(function(){ inp.focus(); }, 80);
		})();
	""")

func _on_host() -> void:
	get_node("/root/NetworkManager").host()
	join_btn.disabled = true
	host_btn.disabled = true
	_start_game()

func _on_join() -> void:
	var addr := ip_input.text.strip_edges()
	if _on_web and addr.is_empty():
		_show_url_overlay()
		return
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
	status_label.text = "Falha ao conectar. Verifique o link."
	host_btn.disabled = false
	join_btn.disabled = false

func _on_player_connected(_peer_id: int) -> void:
	pass

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")
