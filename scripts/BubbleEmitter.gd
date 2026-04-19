extends GPUParticles3D

## BubbleEmitter.gd
## Two modes:
##   STREAM — continuous rising cloud, for fish anchor points
##   BURST  — volumetric box cloud, for player displacement events
##
## Uses a low-poly SphereMesh + Fresnel spatial shader instead of billboard quads.
## Transparent center, bright rim — matches real underwater bubble refraction.
##
## Call burst(intensity) from Fish.gd or Player.gd.

enum Mode { STREAM, BURST }

@export var mode: Mode = Mode.STREAM

## Stream: particles per second at idle
@export var stream_rate: float = 60.0

## Burst: base particle count (scales with intensity)
@export var burst_count: int = 200

## Burst: intensity multiplier
@export var burst_intensity_scale: float = 1.0

## Rise speed
@export var rise_speed: float = 2.8

## Lifetime
@export var bubble_lifetime: float = 1.2

## Size range — real geometry so keep small. Wide ratio for variation.
@export var bubble_size_min: float = 0.006
@export var bubble_size_max: float = 0.08

## Path to the Fresnel shader — must be saved at this location
const SHADER_PATH := "res://shaders/bubble_fresnel.gdshader"

# ── internal ──────────────────────────────────────────────────────────────────

var _mat: ParticleProcessMaterial

func _ready() -> void:
	_setup_material()
	_setup_draw()
	# Prevent culling when emitter is outside camera frustum —
	# without this, emitters on the far side of the fish stop processing
	visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))

	if mode == Mode.STREAM:
		amount = max(1, int(stream_rate * bubble_lifetime))
		emitting = true
		one_shot = false
		explosiveness = 0.0
		randomness = 0.8
	else:
		amount = burst_count
		emitting = false
		one_shot = true
		explosiveness = 1.0


func _setup_material() -> void:
	_mat = ParticleProcessMaterial.new()

	if mode == Mode.STREAM:
		_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_mat.emission_sphere_radius = 0.3
		_mat.direction = Vector3(0, 1, 0)
		_mat.spread = 45.0
		_mat.flatness = 0.0
		_mat.initial_velocity_min = rise_speed * 0.5
		_mat.initial_velocity_max = rise_speed * 1.5
		_mat.gravity = Vector3(0, 1.0, 0)
	else:
		_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_mat.emission_box_extents = Vector3(0.5, 0.5, 0.5)
		_mat.direction = Vector3(0, 1, 0)
		_mat.spread = 60.0
		_mat.initial_velocity_min = 0.1
		_mat.initial_velocity_max = 0.6
		_mat.gravity = Vector3(0, 0.3, 0)

	_mat.lifetime_randomness = 0.8

	# Scale over lifetime — grow in, hold, shrink out
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))
	scale_curve.add_point(Vector2(0.15, 1.0))
	scale_curve.add_point(Vector2(0.85, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	_mat.scale_curve = scale_tex as Texture2D
	_mat.scale_min = bubble_size_min
	_mat.scale_max = bubble_size_max

	# Alpha curve — Fresnel handles per-pixel alpha, this is the lifetime fade
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.12, 1.0))
	if mode == Mode.BURST:
		alpha_curve.add_point(Vector2(0.5, 0.8))
		alpha_curve.add_point(Vector2(1.0, 0.0))
	else:
		alpha_curve.add_point(Vector2(0.8, 0.9))
		alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_tex := CurveTexture.new()
	alpha_tex.curve = alpha_curve
	_mat.alpha_curve = alpha_tex as Texture2D

	process_material = _mat
	lifetime = bubble_lifetime if mode == Mode.STREAM else bubble_lifetime * 0.45


func _setup_draw() -> void:
	# Low-poly sphere — 6 radial, 4 rings. Enough to read as a sphere,
	# low enough to fit the PS1 aesthetic and be cheap at high counts.
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 4
	sphere.radius = 0.5   # scaled by particle scale_min/max
	sphere.height = 1.0
	draw_pass_1 = sphere

	# Load Fresnel shader
	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		push_error("BubbleEmitter: could not load shader at " + SHADER_PATH)
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	sphere.surface_set_material(0, mat)


## Call from Fish.gd or Player.gd. intensity: 0.0–1.0
func burst(intensity: float = 1.0) -> void:
	var scaled: float = clamp(intensity * burst_intensity_scale, 0.1, 1.0)
	amount = max(8, int(burst_count * scaled))
	var ext_xz: float = lerpf(0.3, 0.8, scaled)
	var ext_y: float  = lerpf(0.4, 1.0, scaled)
	_mat.emission_box_extents = Vector3(ext_xz, ext_y, ext_xz)
	emitting = false
	await get_tree().process_frame
	emitting = true
