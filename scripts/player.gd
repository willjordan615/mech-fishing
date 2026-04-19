# Player.gd

extends CharacterBody3D

@export var move_speed: float = 6.0
@export var turn_speed: float = 2.5
@export var jump_speed: float = 8.0
@export var detach_gravity: float = 15.0
@export var ride_height: float = 0.5
@export var snap_strength: float = 20.0
@export var max_snap_velocity: float = 40.0

## Assign in inspector — the Fish node.
@export var fish_node: Node3D

@onready var _shapecast: ShapeCast3D = $ShapeCast3D

var _attached: bool = false
var _surface_normal: Vector3 = Vector3.UP
var _airborne_timer: float = 0.0

# Rolling average of recent surface normals — smooths out vertex jitter
# without losing real orientation changes like fish rolls.
const NORMAL_HISTORY_SIZE := 10
var _normal_history: Array = []
var _smoothed_normal: Vector3 = Vector3.UP

# Option B: player position stored in fish-local space while attached.
# This is what makes the player ride the fish through all movement —
# translation, sway, surge, rolls. De-coupling is just clearing this.
var _local_pos_on_fish: Vector3 = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_airborne_timer = max(0.0, _airborne_timer - delta)
	var jumping := Input.is_action_just_pressed("thruster")

	# ── STEP 1: Carry player with fish ──────────────────────────────────────
	# Before anything else runs, move the player to wherever the fish has
	# carried their local position to in world space. This is the core of
	# Option B — the player rides the fish's coordinate frame.
	if _attached and fish_node and _local_pos_on_fish != Vector3.ZERO:
		var carried_pos: Vector3 = fish_node.to_global(_local_pos_on_fish)
		if carried_pos.is_finite():
			global_position = carried_pos

	# ── STEP 2: Detect surface ───────────────────────────────────────────────
	_shapecast.force_shapecast_update()

	if _shapecast.is_colliding() and _airborne_timer <= 0.0:
		_attached = true
		var n: Vector3 = _shapecast.get_collision_normal(0)
		if n.is_finite() and n.length() > 0.01:
			_surface_normal = n.normalized()
			# Add to history and average — filters vertex noise
			_normal_history.append(_surface_normal)
			if _normal_history.size() > NORMAL_HISTORY_SIZE:
				_normal_history.pop_front()
			var avg := Vector3.ZERO
			for h in _normal_history:
				avg += h
			var candidate: Vector3 = (avg / _normal_history.size()).normalized()

			# Deadzone — if the change from smoothed normal is tiny, ignore it.
			# If it's small, move very slowly. Only large changes move quickly.
			var delta_angle: float = _smoothed_normal.angle_to(candidate)
			if delta_angle > 0.25:
				# Large change — follow it at full speed
				_smoothed_normal = _smoothed_normal.lerp(candidate, 0.08).normalized()
			elif delta_angle > 0.1:
				# Small change — creep toward it very slowly
				_smoothed_normal = _smoothed_normal.lerp(candidate, 0.005).normalized()
			# Below 0.1 radians — deadzone, do nothing
	else:
		# Lost contact — detach
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
		# Project movement vectors onto the fish surface plane
		forward = (forward - _smoothed_normal * forward.dot(_smoothed_normal)).normalized()
		right   = (right   - _smoothed_normal * right.dot(_smoothed_normal)).normalized()

		var move_dir := forward * fwd + right * strafe
		if move_dir.length() > 1.0:
			move_dir = move_dir.normalized()

		velocity = move_dir * move_speed

		# Ride-height correction — push player to ride_height above surface
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

		# Strip any velocity pushing away from the surface
		var outward := velocity.dot(_smoothed_normal)
		if outward > 0.0:
			velocity -= _smoothed_normal * outward
	else:
		# Detached — slow sink with thruster burst available
		velocity += Vector3.DOWN * detach_gravity * delta
		velocity += Vector3.UP * 6.0 * delta  # buoyancy counteracts most of gravity
		velocity *= 0.98  # water drag
		if jumping and fish_node:
			# Thruster burst toward fish
			var to_fish: Vector3 = (fish_node.global_position - global_position).normalized()
			velocity += to_fish * jump_speed

	if not velocity.is_finite():
		velocity = Vector3.ZERO

	move_and_slide()

	# ── STEP 7: Bake position back into fish-local space ─────────────────────
	# After move_and_slide() has resolved collisions and moved the player,
	# store the new world position back into local space. This captures the
	# player's own movement so next frame's carry starts from the right place.
	if _attached and fish_node:
		_local_pos_on_fish = fish_node.to_local(global_position)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _detach() -> void:
	_attached = false
	_airborne_timer = 0.5
	_local_pos_on_fish = Vector3.ZERO
	_normal_history.clear()
	_smoothed_normal = Vector3.UP


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
