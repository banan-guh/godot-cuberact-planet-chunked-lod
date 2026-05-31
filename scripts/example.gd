## Example controller for the planet demo. Creates the HUD, handles flight
## controls (WASD + mouse), and provides a debug observer mode (Tab key).
##
## This script is NOT required for PlanetCamera + Planet to work. Delete it
## and write your own controls — just move PlanetCamera from your script and
## it handles origin shifting, terrain collision, and clip planes on its own.
class_name Example
extends Node

# ===========================================================================
#  HUD colors
# ===========================================================================

const COLOR_LABEL := Color(0.65, 0.65, 0.7)
const COLOR_BG := Color(0.1, 0.1, 0.15)
const COLOR_ON := Color(0.35, 0.75, 0.35)
const COLOR_OFF := Color(0.45, 0.45, 0.5)

# ===========================================================================
#  References (auto-discovered in _ready)
# ===========================================================================

@export var planet_camera: PlanetCamera
@export var planet: Planet
@export var yaw_node: Node3D

# ===========================================================================
# Controls state
# ===========================================================================

var speed: float = 50.0
var mouse_captured: bool = false
var mouse_sensitivity: float = 0.005

# ===========================================================================
#  Sun (visual decoration + orbiting light direction)
# ===========================================================================

var _sun_mesh: MeshInstance3D
var _sun_angle: float = PI * 0.5 + deg_to_rad(30.0)
var _sun_target_offset: float = 0.0  # accumulated manual offset, lerped into _sun_angle
var _sun_start_angle: float = PI * 0.5 + deg_to_rad(30.0)
var sun_orbit_period: float = 1200.0
var sun_distance: float = 20000.0
@export var _world_env: WorldEnvironment
var sun_radius: float = 200.0


var _initial_rel_pos: Vector3
var _initial_basis: Basis

var _collision_on: bool = true


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	if planet_camera and planet:
		_setup_start_view()
		_initial_rel_pos = planet_camera.global_position - planet.global_position
		_initial_basis = planet_camera.global_transform.basis
	_create_sun()


# ===========================================================================
#  Input handling
# ===========================================================================

var pitch: float = 0.0
func _unhandled_input(event: InputEvent) -> void:
	# ESC closes help overlay first, otherwise toggles mouse capture
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		mouse_captured = not mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE

	# Click to capture mouse
	if not mouse_captured and event is InputEventMouseButton and event.pressed:
		mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# Mouse look (pitch + yaw in local space)
	if event is InputEventMouseMotion and mouse_captured:
		if yaw_node and planet_camera:
			var mm := event as InputEventMouseMotion
			yaw_node.rotate_object_local(Vector3.UP, -mm.relative.x * mouse_sensitivity)
			pitch = clamp(pitch + (-mm.relative.y * mouse_sensitivity), deg_to_rad(-89), deg_to_rad(89))
			planet_camera.rotation.x = pitch


func _process(delta: float) -> void:
	if not planet_camera:
		return
	
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction -= planet_camera.transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += planet_camera.transform.basis.z
	if Input.is_key_pressed(KEY_R):
		direction += planet_camera.transform.basis.y
	if Input.is_key_pressed(KEY_F):
		direction -= planet_camera.transform.basis.y
	if Input.is_key_pressed(KEY_A):
		direction -= planet_camera.transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += planet_camera.transform.basis.x

	# Q/E = roll
	if Input.is_key_pressed(KEY_Q):
		planet_camera.rotate_object_local(Vector3.FORWARD, -2.0 * delta)
	if Input.is_key_pressed(KEY_E):
		planet_camera.rotate_object_local(Vector3.FORWARD, 2.0 * delta)

	# O/P = time of day (hold to rotate sun continuously)
	if Input.is_key_pressed(KEY_O):
		_sun_angle -= (TAU / 96.0) * delta * 5.0
	if Input.is_key_pressed(KEY_P):
		_sun_angle += (TAU / 96.0) * delta * 5.0

	# Auto speed based on distance from ideal sphere (ignoring terrain to avoid
	# speed jitter over mountains). Works above and inside the planet.
	var surface_dist := absf((planet_camera.global_position - planet.global_position).length() - planet.radius)
	speed = maxf(clampf(surface_dist * 0.5, 0.5, 50000.0), 0.05)

	if direction.length_squared() > 0.0:
		var offset := direction.normalized() * speed * delta
		planet_camera.move(offset, _collision_on)

	# Orbit the sun and update planet's light direction
	if planet and _sun_mesh and sun_orbit_period > 0.0:
		# Smoothly apply manual time offset (from +/- buttons)
		if absf(_sun_target_offset) > 0.001:
			var step := _sun_target_offset * minf(5.0 * delta, 1.0)
			_sun_angle += step
			_sun_target_offset -= step
		_sun_angle += (TAU / sun_orbit_period) * delta
		_sun_angle = fmod(_sun_angle, TAU)
		# Compute sun direction from orbit around Y axis
		var sun_orbit_pos := Vector3(
			sin(_sun_angle) * sun_distance,
			0.0,
			cos(_sun_angle) * sun_distance
		)
		planet.sun_direction = sun_orbit_pos.normalized()
		# Place visual sun in the right direction, but close enough to be inside far plane
		var visual_dist: float = planet_camera.far * 0.8
		var visual_radius: float = visual_dist * 0.02
		_sun_mesh.global_position = planet_camera.global_position + planet.sun_direction * visual_dist
		_sun_mesh.mesh.radius = visual_radius
		_sun_mesh.mesh.height = visual_radius * 2.0
		# Rotate skybox to match sun orbit (simulates planet rotation)
		if _world_env and _world_env.environment:
			var sky_angle := _sun_angle - _sun_start_angle
			_world_env.environment.sky_rotation = Vector3(0.0, sky_angle, 0.0)

	# Update camera (origin shift, auto-level, clip planes) and planet (LOD, shaders).
	# Must be called AFTER all movement and rotation is done this frame.
	planet_camera.update(delta)


# ===========================================================================
#  Starting camera view — positions camera to show the planet beautifully
# ===========================================================================

func _setup_start_view() -> void:
	# Camera distance: planet + atmosphere fills ~80% of the screen
	var atm_radius := planet.radius + planet.atmosphere_height
	var view_dist := atm_radius * 1.8

	# Sun starts at _sun_start_angle in the XZ plane
	# Offset camera 45° from sun direction so the terminator is visible
	var cam_horizontal_angle := _sun_start_angle + deg_to_rad(50.0)
	var cam_elevation := deg_to_rad(25.0)

	# Spherical to cartesian (Y = up)
	var cam_pos := Vector3(
		sin(cam_horizontal_angle) * cos(cam_elevation) * view_dist,
		sin(cam_elevation) * view_dist,
		cos(cam_horizontal_angle) * cos(cam_elevation) * view_dist
	)

	planet_camera.global_position = planet.global_position + cam_pos
	planet_camera.look_at(planet.global_position, Vector3.UP)


# ===========================================================================
#  Sun (visual decoration — orbiting emissive sphere)
# ===========================================================================

func _create_sun() -> void:
	if not planet:
		return
	_sun_mesh = MeshInstance3D.new()
	_sun_mesh.name = "Sun"
	var sphere := SphereMesh.new()
	sphere.radius = sun_radius
	sphere.height = sun_radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	_sun_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.8)
	mat.emission_energy_multiplier = 3.0
	_sun_mesh.material_override = mat
	planet_camera.add_child(_sun_mesh)



# ===========================================================================
#  Camera reset
# ===========================================================================

func _reset_camera() -> void:
	if not planet:
		return
	planet_camera.global_position = planet.global_position + _initial_rel_pos
	planet_camera.global_transform.basis = _initial_basis
	planet_camera.move(Vector3.ZERO, _collision_on)
