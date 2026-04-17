# ForceAccumulator.gd
# Two-mode force model:
# ATTACHED — surface-relative, fish is your world
# DETACHED — world-space gravity modified by buoyancy and drag

class_name ForceAccumulator

# ── Tunable ────────────────────────────────────────────────────────────────
@export var gravity_strength: float = 9.8
@export var buoyancy_strength: float = 6.0      # upward force when detached/submerged
@export var drag_coefficient: float = 0.8       # water resistance — higher = slower sink
@export var surface_pull_strength: float = 12.0 # how strongly attached player hugs surface

# ── State ──────────────────────────────────────────────────────────────────
var attached: bool = false
var surface_normal: Vector3 = Vector3.UP  # current fish surface normal at player contact
var _velocity: Vector3 = Vector3.ZERO
var _thruster_force: Vector3 = Vector3.ZERO
var _behavior_forces: Array[Vector3] = []

# ── Public API ─────────────────────────────────────────────────────────────

func set_velocity(v: Vector3) -> void:
	_velocity = v

func set_surface_normal(n: Vector3) -> void:
	# Called each frame by the player when attached — fish surface normal at feet
	surface_normal = n

func set_thruster_force(f: Vector3) -> void:
	_thruster_force = f

func add_behavior_force(f: Vector3) -> void:
	_behavior_forces.append(f)

func resolve(delta: float) -> Vector3:
	var net := Vector3.ZERO

	if attached:
		# Pull player toward fish surface along its normal
		# This is the SotC model — fish is your world while connected
		net += -surface_normal * surface_pull_strength

		# Behavior forces still apply in full — fish shaking fights your attachment
		for f in _behavior_forces:
			net += f

		# Thruster input is relative to surface normal when attached
		# (full camera-relative movement comes later)
		net += _thruster_force

	else:
		# Detached — world gravity, heavily damped by water
		net += Vector3(0.0, -gravity_strength, 0.0)

		# Buoyancy opposes gravity — net sink rate is slow
		net += Vector3(0.0, buoyancy_strength, 0.0)

		# Fluid drag opposes all velocity — water slows everything
		if _velocity.length() > 0.01:
			net += -_velocity.normalized() * (_velocity.length_squared() * drag_coefficient * delta)

		# Behavior forces still apply — fish tail sweep can hit a detached player
		for f in _behavior_forces:
			net += f

		# Thruster input — player can fight the sink, try to re-engage
		net += _thruster_force

	# Clear per-frame state
	_behavior_forces.clear()
	_thruster_force = Vector3.ZERO

	return net
