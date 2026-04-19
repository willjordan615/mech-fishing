extends Node

# AttachmentManager.gd
# Owns all active connection objects between the player's Gear and the fish.

# --------------------------------------------------------------------------- #
# CONNECTION DATA                                                               #
# --------------------------------------------------------------------------- #

class Connection:
	var type: String          # "piton" | "drag_line" | "grapple" | etc.
	var anchor_local: Vector3 # Position in fish-local space — moves with the fish
	var load_current: float   # Force currently on this connection
	var load_max: float       # Max before failure
	var is_dynamic: bool      # Static anchor vs. dynamic (drag line, grapple)
	var failed: bool          # Has this connection snapped?
	var visual: Node3D        # Anchor mesh at piton point
	var rope: Node3D          # Rope line from anchor to player

	func _init(
		p_type: String,
		p_anchor_local: Vector3,
		p_load_max: float,
		p_is_dynamic: bool,
		p_visual: Node3D
	) -> void:
		type         = p_type
		anchor_local = p_anchor_local
		load_current = 0.0
		load_max     = p_load_max
		is_dynamic   = p_is_dynamic
		failed       = false
		visual       = p_visual
		rope         = null


# --------------------------------------------------------------------------- #
# STATE                                                                         #
# --------------------------------------------------------------------------- #

var connections: Array[Connection] = []

@export var fish_node: Node3D
@export var player_node: Node3D   # Assign in editor — needed for rope endpoints

# --------------------------------------------------------------------------- #
# PITON CONFIG                                                                  #
# --------------------------------------------------------------------------- #

const PITON_LOAD_MAX := 300.0
@export var piton_scene: PackedScene
@export var max_rope_length: float = 15.0   # Tune once real fish scale is known
@export var foot_offset: float = 1.0        # Half player capsule height

const RopeScript = preload("res://scripts/PitonRope.gd")

# --------------------------------------------------------------------------- #
# PUBLIC API                                                                    #
# --------------------------------------------------------------------------- #

func add_piton(world_pos: Vector3, normal: Vector3) -> Connection:
	if not fish_node:
		push_error("AttachmentManager: fish_node not assigned.")
		return null

	var local_pos := fish_node.to_local(world_pos)

	# Spawn anchor visual
	var visual: Node3D = null
	if piton_scene:
		visual = piton_scene.instantiate()
		get_tree().current_scene.add_child(visual)
		visual.global_position = world_pos
		visual.look_at(world_pos + normal, Vector3.UP)
	else:
		visual = _make_debug_sphere(world_pos)

	var conn := Connection.new(
		"piton",
		local_pos,
		PITON_LOAD_MAX,
		false,
		visual
	)

	# Spawn rope
	var rope := MeshInstance3D.new()
	rope.set_script(RopeScript)
	get_tree().current_scene.add_child(rope)
	rope.player_node     = player_node
	rope.fish_node       = fish_node
	rope.connection      = conn
	rope.max_rope_length = max_rope_length
	rope.foot_offset     = foot_offset
	conn.rope = rope

	connections.append(conn)
	print("[AttachmentManager] Piton placed. Total anchors: %d" % connections.size())
	return conn


func remove_connection(conn: Connection) -> void:
	if conn.visual:
		conn.visual.queue_free()
	if conn.rope:
		conn.rope.queue_free()
	connections.erase(conn)


func clear_all() -> void:
	for conn in connections:
		if conn.visual:
			conn.visual.queue_free()
		if conn.rope:
			conn.rope.queue_free()
	connections.clear()


func total_load() -> float:
	var sum := 0.0
	for conn in connections:
		sum += conn.load_current
	return sum


func total_capacity() -> float:
	var sum := 0.0
	for conn in connections:
		if not conn.failed:
			sum += conn.load_max
	return sum


# --------------------------------------------------------------------------- #
# INTERNAL                                                                      #
# --------------------------------------------------------------------------- #

func _update_visual_positions() -> void:
	if not fish_node:
		return
	for conn in connections:
		if conn.visual and not conn.failed:
			conn.visual.global_position = fish_node.to_global(conn.anchor_local)


func _physics_process(_delta: float) -> void:
	_update_visual_positions()


func _make_debug_sphere(pos: Vector3) -> Node3D:
	var sphere := CSGSphere3D.new()
	sphere.radius = 0.15
	get_tree().current_scene.add_child(sphere)
	sphere.global_position = pos
	return sphere
