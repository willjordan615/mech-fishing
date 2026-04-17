# Player.gd
# CharacterBody3D. Two-mode physics via ForceAccumulator.
# Attached: surface-relative, oriented to fish.
# Detached: world gravity modified by buoyancy and drag.

extends CharacterBody3D

# ── Tunable ────────────────────────────────────────────────────────────────
@export var thruster_strength: float = 12.0
@export var raycast_length: float = 2.0

# ── Node References ────────────────────────────────────────────────────────
@onready var _raycast: RayCast3D = $RayCast3D

# ── State ──────────────────────────────────────────────────────────────────
var _accumulator: ForceAccumulator
var _attached: bool = false

# ── Setup ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	print(get_children())
	_accumulator = ForceAccumulator.new()

# ── Physics ────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_update_attachment()

	_accumulator.set_velocity(velocity)
	_accumulator.attached = _attached

	if _attached and _raycast.is_colliding():
		_accumulator.set_surface_normal(_raycast.get_collision_normal())

	# Input
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")

	if Input.is_action_pressed("thruster"):
		input.y += 1.0

	_accumulator.set_thruster_force(input * thruster_strength)

	# Resolve
	var net_force := _accumulator.resolve(delta)
	velocity += net_force * delta

	# Damp velocity into the surface when attached to stop bouncing
	if _attached:
		var normal := _accumulator.surface_normal
		var into_surface := velocity.dot(normal)
		if into_surface < 0:
			velocity -= normal * into_surface
			
	# Damp lateral velocity when attached and not actively thrusting
	if _attached:
		var normal := _accumulator.surface_normal
		# Get the velocity component along the surface (lateral)
		var lateral := velocity - normal * velocity.dot(normal)
		# Bleed it off each frame
		velocity -= lateral * 0.05

	move_and_slide()

# ── Attachment Detection ───────────────────────────────────────────────────
func _update_attachment() -> void:
	if _raycast.is_colliding():
		_attached = true
	else:
		_attached = false
