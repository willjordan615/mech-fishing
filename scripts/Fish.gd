extends AnimatableBody3D

# =============================================================================
# Fish.gd  —  Revised with proper speed model (based on Game Dev Buddies ref)
# =============================================================================

signal force_delta(delta_velocity: Vector3)

# --- Movement properties (tune in Inspector) ---------------------------------

## Sustainable cruise speed (m/s) — fish naturally holds this
@export var cruising_speed: float = 5.0

## Absolute maximum speed — only hit during surge behaviors
@export var max_speed: float = 20.0

## How fast acceleration ramps up per second
@export var movement_jerk: float = 8.0

## How fast acceleration bleeds off when not actively thrusting
@export var deceleration: float = 6.0

## Ceiling on acceleration value itself
@export var max_acceleration: float = 12.0

## Water friction coefficient — drag opposing current speed each frame
@export var water_friction: float = 0.9

# --- Swim animation properties -----------------------------------------------

## Base lateral sway amplitude at cruise speed (scales with speed)
@export var sway_amplitude: float = 1.0

## Sway oscillation frequency in cycles per second
@export var sway_frequency: float = 0.7

## Phase offset for sway — creates the side-to-side body wiggle
@export var sway_phase_offset: float = 0.5

## Base vertical undulation amplitude at cruise speed (scales with speed)
@export var undulate_amplitude: float = 0.3

## Vertical undulation frequency — slower than sway for natural look
@export var undulate_frequency: float = 0.35

# --- Internal state ----------------------------------------------------------

var _time: float = 0.0
var _current_speed: float = 0.0
var _current_acceleration: float = 0.0
var _should_accelerate: bool = true

var _previous_velocity: Vector3 = Vector3.ZERO
var _current_velocity: Vector3 = Vector3.ZERO

@export var water_surface: MeshInstance3D


func _ready() -> void:
	add_to_group("fish")
	set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_generate_collision()
	set_physics_process(true)

func _generate_collision() -> void:
	_find_and_collide(self)

func _find_and_collide(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var shape := mesh_instance.mesh.create_trimesh_shape()
		var col := CollisionShape3D.new()
		col.shape = shape
		add_child(col)
		col.transform = _get_relative_transform(mesh_instance, self)
	for child in node.get_children():
		_find_and_collide(child)

func _get_relative_transform(from: Node3D, to: Node3D) -> Transform3D:
	return to.global_transform.affine_inverse() * from.global_transform


func _physics_process(delta: float) -> void:
	delta = min(delta, 0.05)
	_time += delta

	_update_movement_speed(delta)

	var fish_forward: Vector3 = -global_transform.basis.z
	var fish_right: Vector3 = global_transform.basis.x

	# Guard against max_speed == 0 (used to hold fish stationary for collision tests)
	var speed_fraction: float = 0.0
	if max_speed > 0.0:
		speed_fraction = clamp(_current_speed / max_speed, 0.0, 1.0)

	var sway_wave: float = sin(_time * TAU * sway_frequency + sway_phase_offset)
	var lateral_speed: float = sway_wave * sway_amplitude * speed_fraction

	var undulate_wave: float = sin(_time * TAU * undulate_frequency)
	var vertical_speed: float = undulate_wave * undulate_amplitude * speed_fraction

	_current_velocity = (
		fish_forward * _current_speed * delta +
		fish_right   * lateral_speed  * delta +
		Vector3.UP   * vertical_speed * delta
	)

	if not _current_velocity.is_finite():
		push_warning("[Fish] Non-finite velocity detected; resetting state.")
		_current_velocity = Vector3.ZERO
		_current_speed = 0.0
		_current_acceleration = 0.0
		_previous_velocity = Vector3.ZERO
		return

	# move_and_collide() moves the body by a displacement vector and registers
	# the movement with the physics engine — CharacterBody3D contacts get
	# carried correctly, unlike a raw global_position += assignment.
	move_and_collide(_current_velocity)

	if water_surface:
		var caustic_speed = clamp(_current_speed / max_speed * 1.5, 0.02, 2.0)
		var mat = water_surface.get_active_material(0)
		if mat:
			mat.set_shader_parameter("scroll_speed_a", caustic_speed)
			mat.set_shader_parameter("scroll_speed_b", caustic_speed * 0.6)

	var velocity_delta: Vector3 = _current_velocity - _previous_velocity
	if velocity_delta.length() > 0.0001:
		force_delta.emit(velocity_delta)

	_previous_velocity = _current_velocity


func _update_movement_speed(delta: float) -> void:
	var current_jerk: float = movement_jerk if _should_accelerate else 0.0
	var current_decel: float = deceleration if current_jerk > 0.0 else 0.0
	_current_acceleration = clamp(
		_current_acceleration + (current_jerk - current_decel) * delta,
		0.0,
		max_acceleration
	)

	var projected_speed: float = (
		_current_speed +
		(_current_acceleration - water_friction * _current_speed) * delta
	)
	if projected_speed < cruising_speed:
		_current_acceleration = min(cruising_speed * water_friction, max_acceleration)

	_current_speed += (_current_acceleration - water_friction * _current_speed) * delta
	_current_speed = clamp(_current_speed, 0.0, max_speed)


func trigger_surge(target_speed: float = 18.0, duration: float = 2.0) -> void:
	var original_cruise := cruising_speed
	var original_max := max_speed
	cruising_speed = target_speed
	max_speed = target_speed
	_should_accelerate = true
	await get_tree().create_timer(duration).timeout
	cruising_speed = original_cruise
	max_speed = original_max


func trigger_shudder(intensity: float = 4.0, duration: float = 0.8) -> void:
	var original_sway_amp := sway_amplitude
	var original_sway_freq := sway_frequency
	sway_amplitude = intensity
	sway_frequency = 8.0
	await get_tree().create_timer(duration).timeout
	sway_amplitude = original_sway_amp
	sway_frequency = original_sway_freq


func trigger_roll(angle_degrees: float = 180.0, duration: float = 3.0) -> void:
	var start_rotation := rotation
	var target_rotation := rotation + Vector3(0.0, 0.0, deg_to_rad(angle_degrees))
	var elapsed := 0.0
	while elapsed < duration:
		var t: float = elapsed / duration
		t = t * t * (3.0 - 2.0 * t)
		rotation = start_rotation.lerp(target_rotation, t)
		elapsed += get_physics_process_delta_time()
		await get_tree().physics_frame


func trigger_dive(dive_speed: float = 6.0, duration: float = 4.0) -> void:
	var original_undulate := undulate_amplitude
	undulate_amplitude = -dive_speed
	await get_tree().create_timer(duration).timeout
	undulate_amplitude = original_undulate


func trigger_halt(duration: float = 1.0) -> void:
	_should_accelerate = false
	var original_friction := water_friction
	water_friction = 4.0
	await get_tree().create_timer(duration).timeout
	water_friction = original_friction
	_should_accelerate = true
