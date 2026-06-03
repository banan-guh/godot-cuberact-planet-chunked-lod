## Planetary gravity component. Add as a child of any physics body.
## Supports CharacterBody3D (player, NPCs) and RigidBody3D (props, crates).
## Ground detection uses Planet terrain height query — no collider needed.
class_name PlanetPhysics
extends Node

@export var planet: Planet

#rails
@export var planet_camera: PlanetCamera
## Distance at which this object goes on-rails (stops simulating).
@export var physics_range: float = 2500.0

var _on_rails: bool = false
var _rails_position: Vector3
var _rails_basis: Basis

## Minimum distance above terrain to consider the parent grounded.
const GROUND_THRESHOLD: float = 0.1

var is_on_ground: bool = false

func _go_on_rails(parent: Node3D) -> void:
	_on_rails = true
	_rails_position = parent.global_position
	_rails_basis = parent.global_transform.basis
	if parent is RigidBody3D:
		(parent as RigidBody3D).freeze = true
	elif parent is CharacterBody3D:
		(parent as CharacterBody3D).set_physics_process(false)
	planet_camera.register_shifted_node(parent)

func _come_off_rails(parent: Node3D) -> void:
	_on_rails = false
	if parent is RigidBody3D:
		var rb := parent as RigidBody3D
		rb.freeze = false
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	elif parent is CharacterBody3D:
		(parent as CharacterBody3D).set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not planet:
		return
	var parent := get_parent()
	
	# === On-rails check ===
	if planet_camera:
		var dist = parent.global_position.distance_to(planet_camera.global_position)
		if not _on_rails and dist > physics_range:
			_go_on_rails(parent)
			return
		elif _on_rails and dist < physics_range * 0.9:  # 10% hysteresis
			_come_off_rails(parent)
		elif _on_rails:
			return  # stay frozen
	if parent is CharacterBody3D:
		_process_character(parent as CharacterBody3D, delta)
	elif parent is RigidBody3D:
		_process_rigid(parent as RigidBody3D)

func _process_character(body: CharacterBody3D, delta: float) -> void:
	var rel_pos := body.global_position - planet.global_position
	var up := rel_pos.normalized()
	var r := rel_pos.length()
	if r > 0.0:
		body.velocity -= up * (planet.gm / (r * r)) * delta
	is_on_ground = body.is_on_floor()

func _process_rigid(body: RigidBody3D) -> void:
	var rel_pos := body.global_position - planet.global_position
	var up := rel_pos.normalized()
	var r := rel_pos.length()
	if r > 0.0:
		var g := planet.gm / (r * r)
		body.apply_central_force(-up * g * body.mass)

# =============
# Wrappers!!

func get_up() -> Vector3:
	return planet.to_local(get_parent().global_position).normalized()

func get_surface_dist() -> float:
	print(get_parent().global_position, ", ", planet.global_position)
	return planet.get_distance_to_terrain(get_parent().global_position)

func get_gravity() -> float:
	var r: float = (get_parent().global_position - planet.global_position).length()
	return planet.gm / (r * r) if r > 0.0 else 0.0

func apply_jump(strength: float) -> void:
	var parent := get_parent()
	if parent is CharacterBody3D:
		(parent as CharacterBody3D).velocity += get_up() * strength
		is_on_ground = false
