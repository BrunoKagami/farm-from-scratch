extends PointLight2D

func _ready() -> void:
	texture = _build_texture()
	color = Color(1.0, 0.82, 0.45)
	texture_scale = 3.2
	energy = 0.0

func _build_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

func set_intensity(value: float) -> void:
	energy = value
