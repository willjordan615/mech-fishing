# ForceAccumulator.gd
# Two-mode force model:
# ATTACHED — surface-relative, fish is your world
# DETACHED — world-space gravity modified by buoyancy and drag

extends Resource
class_name ForceAccumulator

# ── Tunable ────────────────────────────────────────────────────────────────
@export var gravity_strength: float = 9.8
@export var buoyancy_strength: float = 6.0
@export var drag_coefficient: float = 0.8
@export var surface_pull_strength: float = 12.0

const WARNING_THRESHOLD := 0.8
const TETHER_SLACK_FRACTION := 0.94
const TETHER_PULL_SCALE := 3.8

# ── State ──────────────────────────────────────────────────────────────────
var attached: bool = false
var surface_normal: Vector3 = Vector3.UP
var _velocity: Vector3 = Vector3.ZERO
var _thruster_force: Vector3 = Vector3.ZERO
var _behavior_forces: Array[Vector3] = []

var attachment_manager = null

# ── Public API ─────────────────────────────────────────────────────────────
func set_velocity(v: Vector3) -> void:
	_velocity = v

func set_surface_normal(n: Vector3) -> void:
	surface_normal = n

func set_thruster_force(f: Vector3) -> void:
	_thruster_force = f

func add_behavior_force(f: Vector3) -> void:
	_behavior_forces.append(f)

func resolve(delta: float) -> Vector3:
	var net := Vector3.ZERO

	if attached:
		net += -surface_normal * surface_pull_strength
		for f in _behavior_forces:
			net += _apply_load(f)
		net += _resolve_tether_forces()
		net += _thruster_force
	else:
		net += Vector3(0.0, -gravity_strength, 0.0)
		net += Vector3(0.0, buoyancy_strength, 0.0)
		if _velocity.length() > 0.01:
			net += -_velocity.normalized() * (_velocity.length_squared() * drag_coefficient * delta)
		for f in _behavior_forces:
			net += f
		net += _thruster_force

	_behavior_forces.clear()
	_thruster_force = Vector3.ZERO

	return net


# ── Load Distribution ──────────────────────────────────────────────────────

## Distribute a scalar drain amount across active pitons.
## Returns the leftover drain that bleeds through to the player's grip pool.
## Use this for grip-stability drain, separate from vector force transfer.
func absorb_drain(amount: float) -> float:
	if not attachment_manager:
		return amount

	var connections: Array = attachment_manager.connections
	if connections.is_empty():
		return amount

	var remaining := amount

	var sorted := connections.duplicate()
	sorted.sort_custom(func(a, b): return a.load_max < b.load_max)

	for conn in sorted:
		if conn.failed:
			continue

		var available: float = float(conn.load_max) - float(conn.load_current)

		if remaining <= available:
			conn.load_current += remaining
			remaining = 0.0
			break
		else:
			remaining -= available
			conn.failed = true
			print("[Piton] SNAP — anchor failed under drain. Remaining: %.2f" % remaining)
			if conn.visual:
				conn.visual.queue_free()

	attachment_manager.connections = attachment_manager.connections.filter(
		func(c): return not c.failed
	)

	return remaining


func _apply_load(force: Vector3) -> Vector3:
	if not attachment_manager:
		return force

	var connections: Array = attachment_manager.connections
	if connections.is_empty():
		return force

	var force_magnitude := force.length()
	var remaining := force_magnitude

	var sorted := connections.duplicate()
	sorted.sort_custom(func(a, b): return a.load_max < b.load_max)

	for conn in sorted:
		if conn.failed:
			continue

		var available: float = float(conn.load_max) - float(conn.load_current)

		if conn.load_current / conn.load_max >= WARNING_THRESHOLD:
			print("[Piton] WARNING — anchor near limit (%.0f%% load)" % (conn.load_current / conn.load_max * 100))

		if remaining <= available:
			conn.load_current += remaining
			remaining = 0.0
			break
		else:
			remaining -= available
			conn.failed = true
			print("[Piton] SNAP — anchor failed. Remaining force: %.2f" % remaining)
			if conn.visual:
				conn.visual.queue_free()

	attachment_manager.connections = attachment_manager.connections.filter(
		func(c): return not c.failed
	)

	if force_magnitude > 0.0:
		return force.normalized() * remaining
	return Vector3.ZERO


# ── Tether Forces ──────────────────────────────────────────────────────────
func _resolve_tether_forces() -> Vector3:
	if not attachment_manager:
		return Vector3.ZERO

	var player_node = attachment_manager.player_node
	var fish_node   = attachment_manager.fish_node
	if not player_node or not fish_node:
		return Vector3.ZERO

	var net := Vector3.ZERO

	for conn in attachment_manager.connections:
		if conn.failed:
			continue

		var anchor_world: Vector3 = fish_node.to_global(conn.anchor_local)
		var player_world: Vector3 = player_node.global_position + Vector3(0, -attachment_manager.foot_offset, 0)
		var to_anchor: Vector3 = anchor_world - player_world
		var distance: float     = to_anchor.length()
		var slack_distance: float = attachment_manager.max_rope_length * TETHER_SLACK_FRACTION
		var max_distance: float   = attachment_manager.max_rope_length

		if distance <= slack_distance:
			continue

		var tension: float = clamp(
			(distance - slack_distance) / (max_distance - slack_distance),
			0.0, 1.0
		)

		var pull_strength: float = conn.load_max * TETHER_PULL_SCALE * tension
		net += to_anchor.normalized() * pull_strength

	return net
