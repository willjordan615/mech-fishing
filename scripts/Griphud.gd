# GripHUD.gd
# Dev-only stability bar. Attach to a CanvasLayer → Control in the scene,
# assign `player` in the inspector.
# Reads grip state from Player.gd's grip_changed signal.

extends Control

@export var player: NodePath

var _grip: float = 1.0
var _zone: int = 0  # GripZone.PLANTED

func _ready() -> void:
	if player.is_empty():
		push_warning("[GripHUD] No player path assigned.")
		return
	var p := get_node(player)
	if p.has_signal("grip_changed"):
		p.grip_changed.connect(_on_grip_changed)

func _on_grip_changed(grip: float, zone: int) -> void:
	_grip = grip
	_zone = zone
	queue_redraw()

func _draw() -> void:
	var bar_width: float = 300.0
	var bar_height: float = 24.0
	var margin: float = 20.0
	var pos := Vector2(margin, margin)

	# Background
	draw_rect(Rect2(pos, Vector2(bar_width, bar_height)), Color(0.1, 0.1, 0.1, 0.8))

	# Fill color by zone
	var fill_color: Color
	match _zone:
		0: fill_color = Color(0.2, 0.9, 0.3)   # PLANTED — green
		1: fill_color = Color(0.9, 0.8, 0.2)   # STRAINED — yellow
		2: fill_color = Color(0.9, 0.4, 0.1)   # SLIPPING — orange
		_: fill_color = Color(0.9, 0.1, 0.1)   # DETACHED — red

	var fill_width: float = bar_width * clamp(_grip, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(fill_width, bar_height)), fill_color)

	# Zone threshold markers
	var strained_x: float = pos.x + bar_width * 0.7
	var slipping_x: float = pos.x + bar_width * 0.4
	draw_line(
		Vector2(strained_x, pos.y),
		Vector2(strained_x, pos.y + bar_height),
		Color(1, 1, 1, 0.5), 1.0
	)
	draw_line(
		Vector2(slipping_x, pos.y),
		Vector2(slipping_x, pos.y + bar_height),
		Color(1, 1, 1, 0.5), 1.0
	)

	# Label
	var font := ThemeDB.fallback_font
	var label := "GRIP %.2f" % _grip
	draw_string(font, pos + Vector2(bar_width + 10, bar_height - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
