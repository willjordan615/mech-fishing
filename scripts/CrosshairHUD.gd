# CrosshairHUD.gd
# Attach to a Control node inside a CanvasLayer.
# Assign the PlayerCamera in the inspector.
# Crosshair appears only when camera is ADS'd.

extends Control

@export var camera: Camera3D

const COLOR := Color(1.0, 1.0, 1.0, 0.85)
const GAP   := 8.0
const LEN   := 14.0
const DOT_R := 2.5


func _process(_delta: float) -> void:
	var ads: bool = camera != null and camera.is_ads()
	if visible != ads:
		visible = ads
		queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var c := size * 0.5

	# Four lines around center gap
	draw_line(c + Vector2(-GAP - LEN, 0), c + Vector2(-GAP, 0), COLOR, 1.5)
	draw_line(c + Vector2( GAP, 0),       c + Vector2( GAP + LEN, 0), COLOR, 1.5)
	draw_line(c + Vector2(0, -GAP - LEN), c + Vector2(0, -GAP), COLOR, 1.5)
	draw_line(c + Vector2(0,  GAP),       c + Vector2(0,  GAP + LEN), COLOR, 1.5)

	# Center dot
	draw_arc(c, DOT_R, 0.0, TAU, 16, COLOR, 1.0)
