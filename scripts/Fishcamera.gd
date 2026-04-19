extends Camera3D

# =============================================================================
# FishCamera.gd — F2 to activate
# Admin camera following the fish from far back.
# Hardcoded sibling path: ../Fish
# =============================================================================

@export var follow_distance: float = 40.0
@export var follow_height: float = 12.0
@export var smoothing: float = 4.0

@onready var _fish: Node3D = $"../Fish"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F2:
			make_current()


func _physics_process(delta: float) -> void:
	if not current or not is_instance_valid(_fish):
		return

	var fish_forward: Vector3 = -_fish.global_transform.basis.x

	var desired_pos: Vector3 = (
		_fish.global_position
		- fish_forward * follow_distance
		+ Vector3.UP * follow_height
	)

	global_position = global_position.lerp(desired_pos, smoothing * delta)
	look_at(_fish.global_position, Vector3.UP)
