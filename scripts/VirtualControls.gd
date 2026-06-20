extends Control

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		hide()
		set_process_input(false)
		return
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE

const JOY_POS      := Vector2(72,  305)
const JOY_RADIUS   := 42.0
const KNOB_RADIUS  := 18.0
const JOY_DEAD     := 10.0
const BTN_E_POS    := Vector2(572, 308)
const BTN_TAB_POS  := Vector2(528, 265)
const BTN_RADIUS   := 26.0

var _joy_touch     := -1
var _joy_offset    := Vector2.ZERO
var _btn_e_touch   := -1
var _btn_tab_touch := -1

const C_BASE  := Color(1, 1, 1, 0.12)
const C_RING  := Color(1, 1, 1, 0.38)
const C_KNOB  := Color(1, 1, 1, 0.32)
const C_BTN   := Color(1, 1, 1, 0.18)
const C_PRESS := Color(0.5, 1.0, 0.6, 0.55)
const C_TEXT  := Color(1, 1, 1, 0.85)

func _draw() -> void:
	draw_circle(JOY_POS, JOY_RADIUS, C_BASE)
	draw_arc(JOY_POS, JOY_RADIUS, 0, TAU, 48, C_RING, 1.5)
	draw_circle(JOY_POS + _joy_offset, KNOB_RADIUS, C_KNOB)

	var ce := C_PRESS if _btn_e_touch >= 0 else C_BTN
	draw_circle(BTN_E_POS, BTN_RADIUS, ce)
	draw_arc(BTN_E_POS, BTN_RADIUS, 0, TAU, 32, C_RING, 1.5)
	var font := ThemeDB.fallback_font
	draw_string(font, BTN_E_POS + Vector2(-5, 6), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_TEXT)

	var ct := C_PRESS if _btn_tab_touch >= 0 else C_BTN
	draw_circle(BTN_TAB_POS, BTN_RADIUS, ct)
	draw_arc(BTN_TAB_POS, BTN_RADIUS, 0, TAU, 32, C_RING, 1.5)
	draw_string(font, BTN_TAB_POS + Vector2(-10, 6), "»", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_TEXT)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch_event(event.index, event.position, event.pressed)
		queue_redraw()
	elif event is InputEventScreenDrag:
		_handle_drag(event)
		queue_redraw()
	# Fallback para browsers mobile que convertem touch em mouse
	elif event is InputEventMouseButton:
		var pressed: bool = event.pressed
		_handle_touch_event(0, event.position, pressed)
		queue_redraw()
	elif event is InputEventMouseMotion and _joy_touch == 0:
		_handle_drag_pos(event.position)
		queue_redraw()

func _handle_touch_event(idx: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _joy_touch < 0 and pos.distance_to(JOY_POS) <= JOY_RADIUS + 24:
			_joy_touch  = idx
			_joy_offset = Vector2.ZERO
		elif _btn_e_touch < 0 and pos.distance_to(BTN_E_POS) <= BTN_RADIUS + 12:
			_btn_e_touch = idx
			Input.action_press("interact")
		elif _btn_tab_touch < 0 and pos.distance_to(BTN_TAB_POS) <= BTN_RADIUS + 12:
			_btn_tab_touch = idx
			Input.action_press("next_crop")
	else:
		if idx == _joy_touch:
			_joy_touch  = -1
			_joy_offset = Vector2.ZERO
			_release_directions()
		if idx == _btn_e_touch:
			_btn_e_touch = -1
			Input.action_release("interact")
		if idx == _btn_tab_touch:
			_btn_tab_touch = -1
			Input.action_release("next_crop")

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _joy_touch:
		return
	_handle_drag_pos(event.position)

func _handle_drag_pos(pos: Vector2) -> void:
	var delta := pos - JOY_POS
	if delta.length() > JOY_RADIUS:
		delta = delta.normalized() * JOY_RADIUS
	_joy_offset = delta
	_apply_directions(delta)

func _apply_directions(delta: Vector2) -> void:
	_release_directions()
	if delta.length() < JOY_DEAD:
		return
	var n := delta.normalized()
	if n.x < -0.3: Input.action_press("ui_left")
	if n.x >  0.3: Input.action_press("ui_right")
	if n.y < -0.3: Input.action_press("ui_up")
	if n.y >  0.3: Input.action_press("ui_down")

func _release_directions() -> void:
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")
