extends Node2D

var _anim: AnimatedSprite2D
var chopped := false

func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = _build_frames()
	_anim.animation = &"sway"
	_anim.play()
	add_child(_anim)

	# Só o tronco bloqueia — a copa não tem colisão.
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 14)
	shape.shape = rect
	shape.position = Vector2(0, 20)
	body.add_child(shape)
	add_child(body)

func _build_frames() -> SpriteFrames:
	var tex: Texture2D = load("res://assets/environment/Arvore-Sheet.png")
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	sf.add_animation(&"sway")
	sf.set_animation_loop(&"sway", true)
	sf.set_animation_speed(&"sway", 2.0)
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 64, 0, 64, 64)
		sf.add_frame(&"sway", at)

	sf.add_animation(&"stump")
	sf.set_animation_loop(&"stump", false)
	var stump_at := AtlasTexture.new()
	stump_at.atlas = tex
	stump_at.region = Rect2(3 * 64, 0, 64, 64)
	sf.add_frame(&"stump", stump_at)
	return sf

func apply_state(is_chopped: bool) -> void:
	chopped = is_chopped
	if _anim == null:
		return
	var target: StringName = &"stump" if chopped else &"sway"
	if _anim.animation != target:
		_anim.animation = target
		_anim.play()
