# PlayerCamera.gd
# Lives at scene root. Position from RemoteTransform3D normally.
# Z hold      — free look, camera swings around player
# Right-click — ADS: zoom over shoulder, crosshair shown, piton ray active
# Left-click  — fire piton (handled in Player.gd via get_piton_ray_hit())
# V           — swap shoulder. Mousewheel — zoom. F1 — make current.

extends Camera3D

@export var position_smoothing: float = 10.0
@export var up_smoothing: float = 1.0
@export var collision_margin: float = 0.3
@export var zoom_speed: float = 0.5
@export var zoom_min: float = 1.0
@export var zoom_max: float = 10.0
@export var freelook_sensitivity: float = 0.005

## ADS settings — applied as an offset on top of RemoteTransform, never modifies it
@export var ads_fov: float = 50.0
@export var ads_blend_speed: float = 10.0
## How much to pull the camera closer and tighter to shoulder during ADS
@export var ads_pull_z: float = 2.0     # pull this many units closer
@export var ads_pull_x: float = 0.3    # pull this many units toward center

@export var remote_transform: RemoteTransform3D
@export var player: Node3D

const FISH_COLLISION_MASK := 1
const NORMAL_FOV := 75.0

var _shoulder_side: float = 1.0
var _smoothed_up: Vector3 = Vector3.UP

# Free look (Z)
var _freelooking: bool = false
var _fl_yaw: float   = 0.0
var _fl_pitch: float = 0.0
const FL_PITCH_MIN := -0.6
const FL_PITCH_MAX :=  0.6

# ADS
var _ads: bool = false
var _ads_t: float = 0.0


func _ready() -> void:
	make_current()
	fov = NORMAL_FOV


func is_ads() -> bool:
	return _ads


func get_piton_ray_hit() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var viewport := get_viewport()
	var center := viewport.get_visible_rect().size * 0.5
	var ray_origin := project_ray_origin(center)
	var ray_target := ray_origin + project_ray_normal(center) * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target, FISH_COLLISION_MASK)
	if player:
		query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _unhandled_input(event: InputEvent) -> void:
	# ── Z: free look ─────────────────────────────────────────────────────────
	if event is InputEventKey and event.keycode == KEY_Z:
		_freelooking = event.pressed
		if remote_transform:
			remote_transform.update_position = not event.pressed
			remote_transform.update_rotation = not event.pressed
		if not event.pressed:
			_fl_yaw   = 0.0
			_fl_pitch = 0.0
		Input.set_mouse_mode(
			Input.MOUSE_MODE_CAPTURED if _freelooking else Input.MOUSE_MODE_VISIBLE
		)

	# ── Mouse motion: free look only ─────────────────────────────────────────
	if event is InputEventMouseMotion and _freelooking:
		_fl_yaw   -= event.relative.x * freelook_sensitivity
		_fl_pitch -= event.relative.y * freelook_sensitivity
		_fl_pitch  = clamp(_fl_pitch, FL_PITCH_MIN, FL_PITCH_MAX)

	# ── Right-click: ADS toggle ───────────────────────────────────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_ads = event.pressed

	# ── Scroll: zoom — only touches remote_transform.position directly ────────
	if event is InputEventMouseButton and event.pressed and not _ads:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if remote_transform:
				remote_transform.position.z = clamp(remote_transform.position.z - zoom_speed, zoom_min, zoom_max)
				remote_transform.position.y = clamp(remote_transform.position.y - zoom_speed * 0.3, 0.0, zoom_max)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if remote_transform:
				remote_transform.position.z = clamp(remote_transform.position.z + zoom_speed, zoom_min, zoom_max)
				remote_transform.position.y = clamp(remote_transform.position.y + zoom_speed * 0.3, 0.0, zoom_max)

	# ── Keys ─────────────────────────────────────────────────────────────────
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

	# ── ADS blend — FOV only, position handled as offset below ───────────────
	_ads_t = move_toward(_ads_t, 1.0 if _ads else 0.0, ads_blend_speed * delta)
	fov = lerpf(NORMAL_FOV, ads_fov, _ads_t)

	# ── Up vector smoothing ───────────────────────────────────────────────────
	var target_up: Vector3    = player.global_transform.basis.y
	var up_delta: float       = _smoothed_up.angle_to(target_up)
	var adaptive_speed: float = clamp(up_delta * up_smoothing, 0.02, 8.0)
	_smoothed_up = _smoothed_up.lerp(
		target_up,
		clamp(adaptive_speed * delta, 0.0, 1.0)
	).normalized()

	if _freelooking:
		# ── Free look ─────────────────────────────────────────────────────────
		var radius: float        = remote_transform.position.length()
		var height_offset: float = remote_transform.position.y
		var p_up: Vector3        = _smoothed_up
		var p_forward: Vector3   = -player.global_transform.basis.z
		var yawed_dir: Vector3   = Basis(p_up, _fl_yaw) * p_forward
		var right: Vector3       = p_up.cross(yawed_dir).normalized()
		var final_dir: Vector3   = Basis(right, -_fl_pitch) * yawed_dir
		global_position = player.global_position \
			- final_dir * radius \
			+ p_up * height_offset
		look_at(player.global_position, _smoothed_up)
	else:
		# ── Normal / ADS follow ───────────────────────────────────────────────
		# Start from RemoteTransform world pos — never modify remote_transform.position
		var target_world_pos: Vector3 = remote_transform.global_position

		# ADS offset: pull camera closer and toward shoulder center
		# Applied in camera-local space so it works regardless of orientation
		if _ads_t > 0.001:
			var cam_forward: Vector3 = -global_transform.basis.z
			var cam_right: Vector3   = global_transform.basis.x
			target_world_pos += cam_forward * ads_pull_z * _ads_t
			target_world_pos -= cam_right * _shoulder_side * ads_pull_x * _ads_t

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

		if player.global_position.distance_to(global_position) > 0.01:
			look_at(player.global_position, _smoothed_up)
