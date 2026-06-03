## Camera designed to work with Planet. Handles origin shifting, dynamic clip
## planes, terrain collision, and auto-leveling — everything needed to orbit
## or walk on a large-radius planet without floating-point jitter.
##
## Place this camera as a sibling of a Planet node. Set the "planet" export
## in the inspector to point at the Planet. The camera handles the rest.
##
## This script contains NO input handling and NO _process() — it is fully
## passive. Move the camera however you like (keyboard, gamepad, scripted
## animation) from an external script, then call update(delta) each frame.
class_name PlanetCamera
extends Camera3D

## Reference to the Planet node (sibling). Set in the inspector.
@export var planet: Planet
@export var player: Node3D
@export var yaw_node: Node3D

## Minimum height above terrain surface (same units as planet radius).
@export var min_altitude: float = 10

var _shifted_nodes: Array[Node3D] = []

func register_shifted_node(node: Node3D) -> void:
	if not _shifted_nodes.has(node):
		_shifted_nodes.append(node)

func unregister_shifted_node(node: Node3D) -> void:
	_shifted_nodes.erase(node)

## Call this once per frame AFTER moving/rotating the camera.
## Performs origin shifting, auto-leveling, clip plane adjustment, and
## triggers Planet LOD update — in the correct order, all in one call.
func update(_delta: float) -> void:
	if not planet:
		push_warning("PlanetCamera: 'planet' is not set. Assign a Planet node in the inspector.")
		return
	
	# krakensbane origin shift
	var shift := player.global_position if player else global_position
	if shift.length_squared() > 1000.0 * 1000.0:
		print("SHIFT: ", shift.length(), "m  planet now at: ", planet.global_position)
		if player:
			player.global_position = Vector3.ZERO
		planet.global_position -= shift
		for node in _shifted_nodes:
			if is_instance_valid(node):
				node.global_position -= shift
	# Dynamically adjust near/far clip planes based on PlanetCamera altitude.
	var surface_dist := absf(planet.get_distance_to_terrain(global_position))
	var dist := (global_position - planet.global_position).length()
	var max_far := maxf(100000.0, dist * 3.0)
	far = clampf(maxf(surface_dist * 100000.0, dist * 3.0), 1000.0, max_far)
	near = clampf(far * 0.0000001, 0.001, 10.0) # Near = far × 1e-7 for depth precision
	# Update planet LOD and shader uniforms — must happen AFTER shifting.
	planet.update(self)

## Distance from the terrain surface (always positive, works both above and
## inside the planet). Used for speed scaling and clip plane adjustment.
func get_surface_distance() -> float:
	if not planet:
		return global_position.length()
	return absf(planet.get_distance_to_terrain(global_position))

## Altitude above terrain surface (negative when inside the planet).
func get_altitude() -> float:
	if not planet:
		return global_position.length()
	return planet.get_distance_to_terrain(global_position)
