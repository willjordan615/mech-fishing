# PlayerCamera.gd
# Lives at scene root. Position from RemoteTransform3D.
# Rotation built independently from a smoothed up vector — never reads
# RemoteTransform3D rotation directly, so vertex normal jitter never
# reaches the camera. Slow up_smoothing filters noise, follows fish rolls.
# V — swap shoulder. Mousewheel — zoom. F1 — make current.

extends Camera3D

@export var position_smoothing: float = 10.0

## How fast the camera up vector follows orientation changes.
## Low value (0.5-2.0) = smooth through vertex noise, still follows fish rolls.
@export var up_smoothing: float = 1.0

@export var collision_margin: float = 0.3
@export var zoom_speed: float = 0.5
@export var zoom_min: float = 1.0
@export var zoom_max: float = 10.0

@export var remote_transform: Node3D
@export var player: Node3D

const FISH_COLLISION_MASK := 1

var _shoulder_side: float = 1.0
var _smoothed_up: Vector3 = Vector3.UP


func _ready() -> void:
	make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if remote_transform:
				remote_transform.position.z = clamp(remote_transform.position.z - zoom_speed, zoom_min, zoom_max)
				remote_transform.position.y = clamp(remote_transform.position.y - zoom_speed * 0.3, 0.0, zoom_max)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if remote_transform:
				remote_transform.position.z = clamp(remote_transform.position.z + zoom_speed, zoom_min, zoom_max)
				remote_transform.position.y = clamp(remote_transform.position.y + zoom_speed * 0.3, 0.0, zoom_max)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			make_current()
		if event.keycode == KEY_V:
			_shoulder_side *= -1.0
			if remote_transform:
				remote_transform.position.x *= -1.0


func _physics_process(delta: float) -> void:
	if not current or not remote_transform or not player:
		return

	# ── Position ──────────────────────────────────────────────────────────────
	var target_world_pos: Vector3 = remote_transform.global_position

	# Collision — pull back from fish geometry
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(
		player.global_position,
		target_world_pos,
		FISH_COLLISION_MASK
	)
	ray.exclude = [player.get_rid()]
	var hit := space.intersect_ray(ray)
	if hit and hit.has("position"):
		var to_player: Vector3 = (player.global_position - hit.position).normalized()
		target_world_pos = hit.position + to_player * collision_margin

	global_position = global_position.lerp(
		target_world_pos,
		clamp(position_smoothing * delta, 0.0, 1.0)
	)

	# ── Rotation — adaptive smoothing on up vector ────────────────────────────
	# Measure how far the target up is from our current smoothed up.
	# Small delta (vertex noise) = heavy smoothing, change is ignored.
	# Large delta (fish roll, surge) = light smoothing, camera follows.
	var target_up: Vector3 = player.global_transform.basis.y
	var up_delta: float = _smoothed_up.angle_to(target_up)  # radians

	# Map delta to a smoothing speed:
	# Near 0 radians of change → very slow follow (filters noise)
	# Large change (e.g. 0.5+ radians) → fast follow (tracks rolls)
	var adaptive_speed: float = clamp(up_delta * up_smoothing, 0.02, 8.0)

	_smoothed_up = _smoothed_up.lerp(
		target_up,
		clamp(adaptive_speed * delta, 0.0, 1.0)
	).normalized()

	# Look at the player using the smoothed up as reference.
	# This is all the rotation we need — no slerp, no quaternion math.
	var look_target: Vector3 = player.global_position
	if look_target.distance_to(global_position) > 0.01:
		look_at(look_target, _smoothed_up)
