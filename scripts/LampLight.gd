extends PointLight2D

# Reaproveitado tanto pro poste quanto pras janelas da casa — só muda a
# escala e o teto de brilho (janela é menor e mais fraca que o poste).
@export var radius_scale: float = 0.6
@export var max_energy: float = 1.0
@export var light_color: Color = Color(1.0, 0.82, 0.45)

func _ready() -> void:
	texture = _build_texture()
	color = light_color
	# Raio efetivo = (largura/2) * texture_scale = 128 * radius_scale — um
	# halo de luz local, não um clarão cobrindo a tela.
	texture_scale = radius_scale
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
	energy = value * max_energy
