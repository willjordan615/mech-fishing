# PitonRope.gd
# Draws a catenary rope between a piton anchor point and the player's center.
# Slack decreases and color shifts white → red as load approaches the limit.

extends MeshInstance3D

# ── Config ─────────────────────────────────────────────────────────────────
const SEGMENTS       := 20          # curve resolution
const MAX_SAG        := 1.5         # meters of slack at zero load
const COLOR_SLACK    := Color(1.0, 1.0, 1.0)   # white — rope at rest
const COLOR_TAUT     := Color(1.0, 0.0, 0.0)   # red   — rope at limit

# ── References set by AttachmentManager on spawn ───────────────────────────
var player_node: Node3D = null
var fish_node:   Node3D = null
var connection   = null   # The Connection object this rope belongs to
var max_rope_length: float = 15.0   # Set by AttachmentManager
var foot_offset: float = 1.0        # Set by AttachmentManager — half capsule height

# ── Internal ───────────────────────────────────────────────────────────────
var _mesh: ImmediateMesh
var _material: StandardMaterial3D


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	self.mesh = _mesh

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true


func _process(_delta: float) -> void:
	if not player_node or not fish_node or not connection:
		return
	if connection.failed:
		queue_free()
		return

	var anchor_world := fish_node.to_global(connection.anchor_local)
	# Connect to player feet rather than center
	var player_world := player_node.global_position

	# Distance snap — rope has a maximum length
	if player_world.distance_to(anchor_world) > max_rope_length:
		connection.failed = true
		print("[Piton] SNAP — player exceeded rope length.")
		queue_free()
		return

	# Load fraction — 0.0 at rest, 1.0 at snap
	var load_fraction: float = clamp(connection.load_current / connection.load_max, 0.0, 1.0)

	# Distance fraction — starts showing strain at 50% of max rope length
	var distance: float = player_world.distance_to(anchor_world)
	var distance_fraction: float = clamp((distance - max_rope_length * 0.5) / (max_rope_length * 0.5), 0.0, 1.0)

	# Combined strain — whichever is worse drives color and sag
	var strain: float = max(load_fraction, distance_fraction)

	# Sag decreases as strain increases — rope goes taut under load or distance
	var sag: float = MAX_SAG * (1.0 - strain)

	# Color shifts white → red as strain increases
	var rope_color: Color = COLOR_SLACK.lerp(COLOR_TAUT, strain)

	_draw_catenary(anchor_world, player_world, sag, rope_color)


# ── Catenary curve ─────────────────────────────────────────────────────────
# Approximates a catenary as a quadratic arc between two points with a
# sag offset perpendicular to the chord, pulled downward by gravity.

func _draw_catenary(
	from: Vector3,
	to: Vector3,
	sag: float,
	color: Color
) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for i in range(SEGMENTS + 1):
		var t: float = float(i) / float(SEGMENTS)

		# Lerp along the chord
		var point := from.lerp(to, t)

		# Parabolic sag — peaks at t=0.5, zero at endpoints
		# Pull sag downward (world -Y) regardless of rope orientation
		var sag_offset: float = sag * 4.0 * t * (1.0 - t)
		point.y -= sag_offset

		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(point)

	_mesh.surface_end()
	_mesh.surface_set_material(0, _material)
