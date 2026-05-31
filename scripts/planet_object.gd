class_name PlanetObject
extends Node3D

## The planet node used for gravity calculations and terrain collision.
@export var planet: Node3D
## Standard gravitational parameter (G * M). Adjust to scale gravity strength.
@export var gravitational_parameter: float = 4000.0
## How closely the physics snaps to the ground/air friction.
@export var drag: float = 4.0

var velocity: Vector3 = Vector3.ZERO
var is_grounded: bool = false
var up_direction: Vector3 = Vector3.UP

const GROUND_THRESHOLD: float = 0.05

func _physics_process(delta: float) -> void:
	if not planet:
		return

	var to_planet: Vector3 = planet.global_position - global_position
	var distance: float = to_planet.length()
	
	if distance < 0.001:
		return # Avoid division by zero at the absolute center

	# 1. Update local planet-relative up vector
	up_direction = -to_planet.normalized()
	
	# 2. Apply Gravity (G * M / r²)
	var gravity_strength: float = gravitational_parameter / (distance * distance)
	velocity += -up_direction * gravity_strength * delta

	# 3. Integrate Velocity
	global_position += velocity * delta

	# 4. Handle Terrain Collision & Grounding
	var altitude: float = planet.get_distance_to_terrain(global_position)
	
	if altitude <= GROUND_THRESHOLD:
		is_grounded = true
		
		# Push cleanly out of the terrain along the planet-relative up
		global_position += up_direction * -altitude
		
		# Cancel velocity component moving directly down into the planet
		var normal_velocity: float = velocity.dot(up_direction)
		if normal_velocity < 0.0:
			velocity -= up_direction * normal_velocity
			
		# Apply generic surface friction/drag
		velocity = velocity.lerp(Vector3.ZERO, drag * delta)
	else:
		is_grounded = false


## Public method allowing external nodes or forces to apply a sudden change in momentum
func apply_impulse(impulse_vector: Vector3) -> void:
	velocity += impulse_vector
