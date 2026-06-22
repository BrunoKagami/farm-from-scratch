extends CharacterBody2D

const SPEED := GameData.PLAYER_SPEED
# Sempre convergimos suavemente pro que o servidor diz — só teleporta de
# vez (sem suavizar) se a divergência for grande o bastante pra ser lag
# real (perda de pacote, spike de rede), não um resíduo pequeno e normal.
const SNAP_THRESHOLD := 32.0
const RECONCILE_LERP  := 0.3

# --- Máquina de estados de animação/ação ---
# Cada estado tem um único ponto de entrada (_enter_state) que decide
# offset/animação. Sem isso, cada ação nova (golpe, regar, pescar...)
# acabava virando mais uma flag solta brigando pelas mesmas variáveis.
enum State { IDLE, WALK, CHOP }
var _state: State = State.IDLE
# Usado por estados com duração fixa (CHOP) pra saber quando voltar
# a aceitar mudança de movimento/estado.
var _state_locked_until_msec := 0

var selected_crop: String = "lumifruit"
var _last_dir := "down"
var _suppress_correction_until_msec := 0

# Animação de corte: quadros 32x64 (o dobro de alto que os outros, pra
# caber o machado erguido), então o corpo fica numa altura diferente
# dentro do frame em cada folha — cada uma com seu próprio offset de
# compensação, senão o personagem "salta" na tela enquanto golpeia.
# "frames" reordena os quadros da folha original (parado, preparando,
# golpe, recuperação) — a folha "right" foi salva fora dessa ordem.
const CHOP_ANIMATIONS := {
	"down":  { "anim": &"chop_down",  "path": "res://assets/characters/axe_chop_down.png",  "offset": Vector2(0, -4),  "frames": [0, 1, 2, 3] },
	"up":    { "anim": &"chop_up",    "path": "res://assets/characters/axe_chop_up.png",    "offset": Vector2(0, -16), "frames": [0, 1, 2, 3] },
	"left":  { "anim": &"chop_left",  "path": "res://assets/characters/axe_chop_left.png",  "offset": Vector2(0, -14), "frames": [0, 1, 2, 3] },
	"right": { "anim": &"chop_right", "path": "res://assets/characters/axe_chop_right.png", "offset": Vector2(0, -15), "frames": [0, 2, 3, 1] },
}
const CHOP_DURATION := 0.5

# Machado: item fixo do jogador, não-contável e não-desgastável (não mora
# no Inventory, não some/baixa quantidade) — é só mais uma opção no ciclo
# de seleção, igual as culturas.
const DIR_VECTORS := {
	"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT,
}
const CHOP_SENSOR_RANGE := 16.0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Jogadores nunca colidiam entre si antes (PlayerRemote era só visual,
	# sem física). Os corpos autoritativos no servidor agora são CharacterBody2D
	# reais, então têm que ficar numa camada separada da dos outros jogadores,
	# senão colidem entre si e a simulação do servidor diverge da previsão do
	# cliente (que nunca trata outro jogador como obstáculo).
	collision_layer = 2
	collision_mask = 1
	for dir_name in CHOP_ANIMATIONS:
		var conf: Dictionary = CHOP_ANIMATIONS[dir_name]
		_add_chop_animation(conf["anim"], conf["path"], conf["frames"])

func _add_chop_animation(anim_name: StringName, path: String, frame_order: Array) -> void:
	var sf := _anim.sprite_frames
	if sf == null or sf.has_animation(anim_name):
		return
	var tex: Texture2D = load(path)
	sf.add_animation(anim_name)
	sf.set_animation_loop(anim_name, false)
	sf.set_animation_speed(anim_name, 8.0)
	for i in frame_order:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 32, 0, 32, 64)
		sf.add_frame(anim_name, at)

func _physics_process(_delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	# Estados com duração fixa (golpe de machado) travam o movimento —
	# não dá pra sair andando no meio da animação de corte.
	if _state == State.CHOP and Time.get_ticks_msec() < _state_locked_until_msec:
		direction = Vector2.ZERO
	# Previsão local: move imediatamente para resposta instantânea ao input.
	# Quem decide a posição "oficial" de todo mundo é sempre o servidor —
	# isto aqui é só o palpite local até a correção chegar.
	velocity = direction * SPEED
	move_and_slide()
	_update_state(direction)

	var world_grid := get_node_or_null("/root/World")
	if world_grid and world_grid.has_method("report_movement"):
		world_grid.report_movement(direction, global_position, velocity)

# Decide se devemos trocar de estado (IDLE/WALK) com base no movimento.
# Estados com duração fixa (CHOP) ignoram isso até o tempo deles passar.
func _update_state(dir: Vector2) -> void:
	if _state == State.CHOP and Time.get_ticks_msec() < _state_locked_until_msec:
		return

	var prev_dir := _last_dir
	if dir != Vector2.ZERO:
		if abs(dir.x) >= abs(dir.y):
			_last_dir = "right" if dir.x > 0 else "left"
		else:
			_last_dir = "down" if dir.y > 0 else "up"

	var desired: State = State.WALK if dir != Vector2.ZERO else State.IDLE
	# Reentra também quando só a direção muda (ex: soltar uma tecla
	# diagonal e continuar andando reto) — sem isso a animação ficava
	# travada na direção antiga porque o estado (WALK) não mudou.
	if desired != _state or _last_dir != prev_dir:
		_enter_state(desired)

# Único lugar que toca animação/offset — cada estado configura o que
# precisa e, se tiver duração fixa, marca quando expira.
func _enter_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.IDLE:
			_anim.offset = Vector2.ZERO
			_anim.play("idle_" + _last_dir)
		State.WALK:
			_anim.offset = Vector2.ZERO
			_anim.play("walk_" + _last_dir)
		State.CHOP:
			var conf: Dictionary = CHOP_ANIMATIONS.get(_last_dir, CHOP_ANIMATIONS["down"])
			_anim.offset = conf["offset"]
			_anim.play(conf["anim"])
			_state_locked_until_msec = Time.get_ticks_msec() + int(CHOP_DURATION * 1000)

# Chamado pelo servidor (via WorldGrid) quando a posição autoritativa diverge
# da nossa previsão local.
func server_correct(server_pos: Vector2, _server_vel: Vector2) -> void:
	if multiplayer.is_server():
		return
	if Time.get_ticks_msec() < _suppress_correction_until_msec:
		return
	if global_position.distance_to(server_pos) > SNAP_THRESHOLD:
		global_position = server_pos
	else:
		global_position = global_position.lerp(server_pos, RECONCILE_LERP)

# Logo após reconectar, o corpo novo do servidor nasce no spawn padrão até
# a mensagem _resume_at chegar — ignora correções por um instante pra não
# saltar pro spawn e voltar.
func suppress_correction(seconds: float) -> void:
	_suppress_correction_until_msec = Time.get_ticks_msec() + int(seconds * 1000)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("next_crop"):
		_cycle_crop()

func _try_interact() -> void:
	if _near_shop():
		_open_shop()
		return

	if selected_crop == "axe":
		_try_chop()
		return

	var grid_pos := Vector2i(
		int(global_position.x / GameData.TILE_SIZE),
		int(global_position.y / GameData.TILE_SIZE)
	)
	var world_grid := get_node_or_null("/root/World")
	if world_grid == null:
		return
	var tile: Node2D = world_grid.get_tile(grid_pos)
	if tile == null:
		_hud_msg("Fora da roça")
		return

	var s: int = tile.get("state")
	var my_id := multiplayer.get_unique_id()
	var call_direct := multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
					   or multiplayer.is_server()

	if s == 0:
		var seed_name: String = selected_crop + "_seed"
		if not Inventory.remove(seed_name):
			_hud_msg("Sem semente de %s!" % selected_crop)
			return
		var hud := get_node_or_null("/root/World/HUD")
		if hud and hud.has_method("refresh_inv"):
			hud.refresh_inv()
		_hud_msg("Plantando %s..." % selected_crop)
		if call_direct:
			world_grid.server_plant(grid_pos, selected_crop, my_id)
		else:
			world_grid.rpc_id(1, "server_plant", grid_pos, selected_crop, my_id)

	elif s == 1:
		_hud_msg("Aguardando crescer...")

	elif s == 2:
		_hud_msg("Colhendo!")
		if call_direct:
			world_grid.server_harvest(grid_pos, my_id)
		else:
			world_grid.rpc_id(1, "server_harvest", grid_pos, my_id)

# O golpe acontece sempre que o machado está selecionado, tenha árvore
# na frente ou não — é a ação de cortar em si, não uma reação a achar algo.
# O sensor fica na direção que o personagem está olhando (_last_dir), não
# num raio ao redor dele — não corta o que está atrás.
func _try_chop() -> void:
	_enter_state(State.CHOP)
	var world_grid := get_node_or_null("/root/World")
	if world_grid == null or not world_grid.has_method("get_near_tree"):
		return
	var facing: Vector2 = DIR_VECTORS.get(_last_dir, Vector2.DOWN)
	var sensor_pos := global_position + facing * CHOP_SENSOR_RANGE
	var tree_id: int = world_grid.get_near_tree(sensor_pos)
	if tree_id >= 0:
		_hud_msg("Cortando árvore...")
		world_grid.request_chop_tree(tree_id)

func _hud_msg(text: String) -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("show_msg"):
		hud.show_msg(text)

func _cycle_crop() -> void:
	var crops := ["lumifruit", "voidroot", "starbloom", "axe"]
	var idx := crops.find(selected_crop)
	selected_crop = crops[(idx + 1) % crops.size()]
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("refresh_crop"):
		hud.refresh_crop(selected_crop)

func _near_shop() -> bool:
	var shop := get_node_or_null("/root/World/Shop")
	if shop == null:
		return false
	return global_position.distance_to(shop.global_position) < 96.0

func _open_shop() -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud == null:
		return
	var panel := hud.get_node_or_null("ShopPanel")
	if panel:
		panel.visible = not panel.visible
