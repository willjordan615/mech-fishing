extends MultiMeshInstance3D

@export var spread: float = 200.0
@export var min_spawn_dist: float = 120.0
@export var max_live_dist: float = 180.0
@export var water_y: float = 15.0
@export var shaft_length: float = 60.0
@export var fade_speed: float = 0.6
@export var near_fade_start: float = 40.0
@export var near_fade_end: float = 120.0

var _current_opacity: float = 0.0
var _target_opacity: float = 0.15
var _positions: Array = []
var _base_transforms: Array = []
var _recycling: Array = []

func _ready():
	_positions.resize(multimesh.instance_count)
	_base_transforms.resize(multimesh.instance_count)
	_recycling.resize(multimesh.instance_count)
	for i in multimesh.instance_count:
		_positions[i] = Vector3.ZERO
		_base_transforms[i] = Transform3D()
		_recycling[i] = false
	_place_shafts()
	_target_opacity = randf_range(0.08, 0.18)

func _place_one(i: int):
	var player_pos = get_parent().global_position
	var x: float = 0.0
	var z: float = 0.0

	for _attempt in range(30):
		x = player_pos.x + randf_range(-spread, spread)
		z = player_pos.z + randf_range(-spread, spread)
		var dx = x - player_pos.x
		var dz = z - player_pos.z
		if sqrt(dx * dx + dz * dz) >= min_spawn_dist:
			break

	_positions[i] = Vector3(x, 0.0, z)
	_recycling[i] = false

	var tilt_x = randf_range(-0.15, 0.15)
	var tilt_z = randf_range(-0.15, 0.15)
	var scale_xz = randf_range(0.3, 3.5)
	var scale_y = randf_range(0.88, 1.12)

	var t = Transform3D()
	t = t.rotated(Vector3.RIGHT, tilt_x)
	t = t.rotated(Vector3.FORWARD, tilt_z)
	t = t.scaled(Vector3(scale_xz, scale_y, scale_xz))
	t.origin = Vector3(x, water_y - (shaft_length * 0.5), z)

	_base_transforms[i] = t
	multimesh.set_instance_transform(i, t)

func _recycle_one(i: int):
	if _recycling[i]:
		return
	_recycling[i] = true
	var t = multimesh.get_instance_transform(i)
	t.origin.y = -9999.0
	multimesh.set_instance_transform(i, t)
	_positions[i] = Vector3(9999.0, 0.0, 9999.0)
	get_tree().create_timer(randf_range(0.5, 1.5)).timeout.connect(func():
		_place_one(i)
	)

func _place_shafts():
	for i in multimesh.instance_count:
		_place_one(i)

func _physics_process(delta):
	global_position = Vector3.ZERO
	global_rotation = Vector3.ZERO

	var player_pos = get_parent().global_position
	var camera = get_viewport().get_camera_3d()

	for i in multimesh.instance_count:
		if _recycling[i]:
			continue

		var dx = _positions[i].x - player_pos.x
		var dz = _positions[i].z - player_pos.z
		var dist = sqrt(dx * dx + dz * dz)

		# Scale down XZ only, preserving full base transform including rotation
		var fade = clamp((dist - near_fade_start) / (near_fade_end - near_fade_start), 0.0, 1.0)
		var base: Transform3D = _base_transforms[i]
		var scaled_t = Transform3D(base)
		scaled_t.basis.x *= fade
		scaled_t.basis.z *= fade
		multimesh.set_instance_transform(i, scaled_t)

		if fade <= 0.0:
			_recycle_one(i)
			continue

		var shaft_world_pos = Vector3(_positions[i].x, water_y - (shaft_length * 0.5), _positions[i].z)
		var in_frustum = camera and camera.is_position_in_frustum(shaft_world_pos)
		if not in_frustum and dist > max_live_dist:
			_recycle_one(i)

	_current_opacity = move_toward(_current_opacity, _target_opacity, fade_speed * delta)
	if abs(_current_opacity - _target_opacity) < 0.01:
		_target_opacity = randf_range(0.06, 0.18)

	var mat = material_override
	if mat:
		mat.set_shader_parameter("opacity", _current_opacity)
		mat.set_shader_parameter("player_pos", player_pos)
