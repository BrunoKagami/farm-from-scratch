extends Node2D

var _anim: AnimatedSprite2D

var peer_id: int = 0

const LERP_SPEED := 12.0
var _target_pos: Vector2 = Vector2.INF

func _process(delta: float) -> void:
	if _target_pos == Vector2.INF:
		return
	position = position.lerp(_target_pos, clamp(LERP_SPEED * delta, 0.0, 1.0))

func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = _build_frames()
	_anim.animation = &"idle_down"
	_anim.play()
	# Tint único por peer para diferenciar do jogador local
	var rng := RandomNumberGenerator.new()
	rng.seed = peer_id
	_anim.modulate = Color.from_hsv(rng.randf(), 0.7, 1.0)
	add_child(_anim)

func _build_frames() -> SpriteFrames:
	var tex: Texture2D = load("res://assets/characters/personagem_Base-Sheet.png")
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var dirs := ["down", "right", "up", "left"]
	for i in dirs.size():
		var walk: StringName = StringName("walk_" + dirs[i])
		var idle: StringName = StringName("idle_" + dirs[i])
		sf.add_animation(walk)
		sf.set_animation_loop(walk, true)
		sf.set_animation_speed(walk, 8.0)
		sf.add_animation(idle)
		sf.set_animation_loop(idle, false)
		sf.set_animation_speed(idle, 1.0)
		for f in 3:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((i * 3 + f) * 32, 0, 32, 32)
			sf.add_frame(walk, at)
		var idle_at := AtlasTexture.new()
		idle_at.atlas = tex
		idle_at.region = Rect2(i * 3 * 32, 0, 32, 32)
		sf.add_frame(idle, idle_at)
	return sf

func update_state(pos: Vector2, vel: Vector2) -> void:
	if _target_pos == Vector2.INF:
		position = pos
	_target_pos = pos
	if _anim == null:
		return
	if vel == Vector2.ZERO:
		var cur := str(_anim.animation)
		if cur.begins_with("walk_"):
			_anim.play("idle_" + cur.substr(5))
		return
	var dir: String
	if abs(vel.x) >= abs(vel.y):
		dir = "right" if vel.x > 0 else "left"
	else:
		dir = "down" if vel.y > 0 else "up"
	_anim.play("walk_" + dir)
