## Drives sun orbit, sky rotation, and exposes sun_direction to the planet.
## Attach this to WorldEnvironment node.
extends WorldEnvironment

@export var planet: Planet
@export var planet_camera: PlanetCamera

@export var sun_orbit_period: float = 1200.0
@export var sun_distance: float = 20000.0
@export var sun_radius: float = 200.0

var sun_direction: Vector3 = Vector3(0.0, 0.0, 1.0)

var _sun_mesh: MeshInstance3D
var _sun_angle: float = PI * 0.5 + deg_to_rad(30.0)
var _sun_start_angle: float = PI * 0.5 + deg_to_rad(30.0)


func _ready() -> void:
	_create_sun()


func _process(delta: float) -> void:
	if not planet_camera:
		return
	_sun_angle += (TAU / sun_orbit_period) * delta
	_sun_angle = fmod(_sun_angle, TAU)
	sun_direction = Vector3(sin(_sun_angle) * sun_distance, 0.0, cos(_sun_angle) * sun_distance).normalized()
	if planet:
		planet.sun_direction = sun_direction
	if _sun_mesh:
		var visual_dist: float = planet_camera.far * 0.8
		var visual_radius: float = visual_dist * 0.02
		_sun_mesh.global_position = planet_camera.global_position + sun_direction * visual_dist
		_sun_mesh.mesh.radius = visual_radius
		_sun_mesh.mesh.height = visual_radius * 2.0
	if environment:
		environment.sky_rotation = Vector3(0.0, _sun_angle - _sun_start_angle, 0.0)


## Manually nudge the time of day (e.g. from player input or HUD buttons).
func offset_sun_angle(delta_radians: float) -> void:
	_sun_angle += delta_radians


func _create_sun() -> void:
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
	if planet_camera:
		planet_camera.add_child(_sun_mesh)
	else:
		add_child(_sun_mesh)
