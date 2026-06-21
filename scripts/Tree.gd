extends Node2D

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
var chopped := false

func _ready() -> void:
	_anim.sprite_frames = _build_frames()
	_anim.animation = &"sway"
	_anim.play()

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
