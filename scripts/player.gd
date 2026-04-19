# Player.gd

extends CharacterBody3D

signal grip_changed(grip: float, zone: int)

enum GripZone { PLANTED, STRAINED, SLIPPING, DETACHED }

@export var move_speed: float = 6.0
@export var turn_speed: float = 2.5
@export var jump_speed: float = 8.0
@export var detach_gravity: float = 15.0
@export var ride_height: float = 0.5
@export var snap_strength: float = 20.0
@export var max_snap_velocity: float = 40.0

## Assign in inspector — the Fish node.
@export var fish_node: Node3D

## Assign AttachmentManager node in inspector.
@export var attachment_manager: Node

## Assign PlayerCamera in inspector — used for ADS piton ray.
@export var player_camera: Camera3D

## Assign BubbleEmitterBurst.tscn in inspector.
@export var bubble_emitter_scene: PackedScene
@export var bubble_displacement_threshold: float = 4.0

@onready var _shapecast: ShapeCast3D = $ShapeCast3D

const ForceAccumulatorScript = preload("res://scripts/ForceAccumulator.gd")
var _accumulator = ForceAccumulatorScript.new()

var _attached: bool = false
var _surface_normal: Vector3 = Vector3.UP
var _airborne_timer: float = 0.0

const NORMAL_HISTORY_SIZE := 10
var _normal_history: Array = []
var _smoothed_normal: Vector3 = Vector3.UP

var _local_pos_on_fish: Vector3 = Vector3.ZERO

var _prev_velocity: Vector3 = Vector3.ZERO
var _burst_cooldown: float = 0.0
const BURST_COOLDOWN_TIME: float = 0.35

var _grip: float = 1.0


func _ready() -> void:
	_accumulator.attachment_manager = attachment_manager
	_accumulator.attached = false


func _unhandled_input(event: InputEvent) -> void:
	# Left-click fires piton only when ADS is active
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and _attached \
			and attachment_manager \
			and player_camera \
			and player_camera.is_ads():
		_try_fire_piton_from_camera()


func _physics_process(delta: float) -> void:
	_airborne_timer = max(0.0, _airborne_timer - delta)
	var jumping := Input.is_action_just_pressed("thruster")

	# ── STEP 1: Carry player with fish ──────────────────────────────────────
	if _attached and fish_node and _local_pos_on_fish != Vector3.ZERO:
		var carried_pos: Vector3 = fish_node.to_global(_local_pos_on_fish)
		if carried_pos.is_finite():
			global_position = carried_pos

	# ── STEP 2: Detect surface ───────────────────────────────────────────────
	_shapecast.force_shapecast_update()

	if _shapecast.is_colliding() and _airborne_timer <= 0.0:
		_attached = true
		_accumulator.attached = true
		var n: Vector3 = _shapecast.get_collision_normal(0)
		if n.is_finite() and n.length() > 0.01:
			_surface_normal = n.normalized()
			_accumulator.set_surface_normal(_surface_normal)
			_normal_history.append(_surface_normal)
			if _normal_history.size() > NORMAL_HISTORY_SIZE:
				_normal_history.pop_front()
			var avg := Vector3.ZERO
			for h in _normal_history:
				avg += h
			var candidate: Vector3 = (avg / _normal_history.size()).normalized()
			var delta_angle: float = _smoothed_normal.angle_to(candidate)
			if delta_angle > 0.25:
				_smoothed_normal = _smoothed_normal.lerp(candidate, 0.08).normalized()
			elif delta_angle > 0.1:
				_smoothed_normal = _smoothed_normal.lerp(candidate, 0.005).normalized()
	else:
		if _attached:
			_detach()

	# ── STEP 3: Jump / detach ────────────────────────────────────────────────
	if jumping and _attached:
		_detach()
		velocity = _smoothed_normal * jump_speed

	# ── STEP 4: Align up vector to surface ───────────────────────────────────
	if _attached:
		_align_up_to(_smoothed_normal, delta)

	# ── STEP 5: Input ────────────────────────────────────────────────────────
	var fwd    := Input.get_axis("move_forward", "move_back")
	var strafe := Input.get_axis("move_left", "move_right")
	var turn   := Input.get_axis("turn_left", "turn_right")

	var up_axis: Vector3 = _smoothed_normal if _attached else global_transform.basis.y
	if abs(turn) > 0.0:
		rotate(up_axis.normalized(), -turn * turn_speed * delta)

	var forward := global_transform.basis.z
	var right   := global_transform.basis.x

	# ── STEP 6: Movement ─────────────────────────────────────────────────────
	if _attached:
		forward = (forward - _smoothed_normal * forward.dot(_smoothed_normal)).normalized()
		right   = (right   - _smoothed_normal * right.dot(_smoothed_normal)).normalized()

		var move_dir := forward * fwd + right * strafe
		if move_dir.length() > 1.0:
			move_dir = move_dir.normalized()

		velocity = move_dir * move_speed

		var hit_point: Vector3 = _shapecast.get_collision_point(0)
		if hit_point.is_finite():
			var to_surface: Vector3 = global_position - hit_point
			var current_distance: float = to_surface.length()
			if current_distance > 0.0001 and current_distance < 10.0:
				var error: float = current_distance - ride_height
				var correction: Vector3 = -_smoothed_normal * error * snap_strength
				if correction.length() > max_snap_velocity:
					correction = correction.normalized() * max_snap_velocity
				velocity += correction

		var outward := velocity.dot(_smoothed_normal)
		if outward > 0.0:
			velocity -= _smoothed_normal * outward

		# Apply accumulator forces (tether pull, behavior forces)
		_accumulator.set_velocity(velocity)
		var acc_force: Vector3 = _accumulator.resolve(delta)
		velocity += acc_force * delta
	else:
		_accumulator.set_velocity(velocity)
		if jumping and fish_node:
			var to_fish: Vector3 = (fish_node.global_position - global_position).normalized()
			_accumulator.set_thruster_force(to_fish * jump_speed)
		var acc_force: Vector3 = _accumulator.resolve(delta)
		velocity += acc_force * delta

	if not velocity.is_finite():
		velocity = Vector3.ZERO

	move_and_slide()

	_check_displacement_burst(delta)
	_update_grip()

	if _attached and fish_node:
		_local_pos_on_fish = fish_node.to_local(global_position)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _detach() -> void:
	_attached = false
	_accumulator.attached = false
	_airborne_timer = 0.5
	_local_pos_on_fish = Vector3.ZERO
	_normal_history.clear()
	_smoothed_normal = Vector3.UP
	_grip = 0.0
	grip_changed.emit(_grip, GripZone.DETACHED)


func _try_fire_piton_from_camera() -> void:
	var hit: Dictionary = player_camera.get_piton_ray_hit()
	if hit.is_empty():
		return
	if not hit.has("position") or not hit.has("normal"):
		return
	attachment_manager.add_piton(hit["position"], hit["normal"])


func _update_grip() -> void:
	if not _attached:
		return
	var capacity: float = attachment_manager.total_capacity() if attachment_manager else 0.0
	var load: float     = attachment_manager.total_load()     if attachment_manager else 0.0
	if capacity > 0.0:
		_grip = clamp(1.0 - (load / capacity), 0.0, 1.0)
	else:
		_grip = 1.0
	var zone: int
	if _grip > 0.7:
		zone = GripZone.PLANTED
	elif _grip > 0.4:
		zone = GripZone.STRAINED
	else:
		zone = GripZone.SLIPPING
	grip_changed.emit(_grip, zone)


func get_surface_normal() -> Vector3:
	return _smoothed_normal

func is_attached() -> bool:
	return _attached


func _align_up_to(target_up: Vector3, delta: float) -> void:
	if not target_up.is_finite() or target_up.length() < 0.01:
		return
	var current_up: Vector3 = global_transform.basis.y
	var dot_val: float = clamp(current_up.dot(target_up), -1.0, 1.0)
	if dot_val > 0.9999:
		return
	var axis: Vector3 = current_up.cross(target_up)
	if axis.length() < 0.0001:
		return
	axis = axis.normalized()
	var angle: float = acos(dot_val)
	var step: float = min(angle, 12.0 * delta)
	global_transform.basis = Basis(axis, step) * global_transform.basis
	global_transform.basis = global_transform.basis.orthonormalized()


func _get_player_center() -> Vector3:
	var shape: Shape3D = _shapecast.shape
	if shape is CapsuleShape3D:
		return global_position + global_transform.basis.y * (shape as CapsuleShape3D).height * 0.5
	elif shape is SphereShape3D:
		return global_position + global_transform.basis.y * (shape as SphereShape3D).radius
	elif shape is BoxShape3D:
		return global_position + global_transform.basis.y * (shape as BoxShape3D).size.y * 0.5
	return global_position


func _check_displacement_burst(delta: float) -> void:
	_burst_cooldown -= delta
	var delta_v: float = (velocity - _prev_velocity).length()
	_prev_velocity = velocity
	if delta_v >= bubble_displacement_threshold and _burst_cooldown <= 0.0:
		_spawn_player_burst(delta_v)
		_burst_cooldown = BURST_COOLDOWN_TIME


func _spawn_player_burst(delta_v: float) -> void:
	if bubble_emitter_scene == null:
		return
	var emitter: GPUParticles3D = bubble_emitter_scene.instantiate()
	get_tree().current_scene.add_child(emitter)
	emitter.global_position = _get_player_center()
	var intensity: float = clamp(
		inverse_lerp(bubble_displacement_threshold, bubble_displacement_threshold * 4.0, delta_v),
		0.2, 1.0
	)
	emitter.burst(intensity)
	var lifetime: float = emitter.bubble_lifetime + 0.5
	get_tree().create_timer(lifetime).timeout.connect(emitter.queue_free)
