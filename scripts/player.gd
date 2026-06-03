## First-person player controller. Extends PlanetObject for planetary gravity.
## Handles camera, mouse look, and WASD movement.
## Extend this class as Astronaut to add survival stats.
class_name Player
extends CharacterBody3D

@export var planet_camera: PlanetCamera
@export var yaw_node: Node3D
@export var mouse_sensitivity: float = 0.005
@export var move_speed: float = 20.0
@export var jump_strength: float = 5.0

@export var planet_physics: PlanetPhysics
@export var planet: Planet

# ===========================================================================
#  Input state
# ===========================================================================

var mouse_captured: bool = false
var _pitch: float = 0.0

# ===========================================================================
#  Lifecycle
# ===========================================================================

# global vars:
@onready var up: Vector3 = planet_physics.get_up()

func _update_vars() -> void:
	up = planet_physics.get_up()

func _ready() -> void:
	if planet_camera:
		planet_camera.register_shifted_node(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_set_mouse_captured(not mouse_captured)
		return
	if not mouse_captured and event is InputEventMouseButton and event.pressed:
		_set_mouse_captured(true)
		return
	if event is InputEventMouseMotion and mouse_captured:
		if yaw_node:
			yaw_node.rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch + (-event.relative.y * mouse_sensitivity), deg_to_rad(-89.0), deg_to_rad(89.0))
		if planet_camera:
			planet_camera.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	_update_vars()
	move_and_slide()

func _process(delta: float) -> void:
	if not planet_camera:
		return
	
	_handle_movement(delta)
	# Align player root to planet surface normal
	var forward := global_transform.basis.z
	if abs(forward.dot(up)) > 0.99:
		forward = global_transform.basis.x
	var right := up.cross(forward).normalized()
	forward = right.cross(up).normalized()
	global_transform.basis = Basis(right, up, forward)
	planet_camera.update(delta)

# ===========================================================================
#  Movement
# ===========================================================================

func _handle_movement(delta: float) -> void:
	var direction := Vector3.ZERO
	var player_basis = planet_camera.global_transform.basis
	if Input.is_key_pressed(KEY_W):
		direction -= player_basis.z
	if Input.is_key_pressed(KEY_S):
		direction += player_basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= player_basis.x
	if Input.is_key_pressed(KEY_D):
		direction += player_basis.x
	if Input.is_action_just_pressed("ui_select") and planet_physics.is_on_ground:
		velocity += up * jump_strength
		planet_physics.is_on_ground = false

	if direction.length_squared() > 0.0:
		# Project movement onto the planet surface plane so we don't fight gravity
		direction = (direction - up * direction.dot(up)).normalized()
		velocity += direction * move_speed * delta

	# Dampen horizontal velocity when on ground (friction)
	if planet_physics.is_on_ground:
		var horiz := velocity - up * velocity.dot(up)
		velocity -= horiz * minf(10.0 * delta, 1.0)

# ===========================================================================
#  Helpers
# ===========================================================================

func _set_mouse_captured(captured: bool) -> void:
	mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
