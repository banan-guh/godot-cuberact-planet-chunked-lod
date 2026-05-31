class_name PlanetPlayer
extends PlanetObject

## Impulse force applied when jumping.
@export var jump_impulse: float = 12.0
## Movement acceleration speed on the surface.
@export var move_speed: float = 10.0
## Reference to the active planetary camera tracking this player.
@export var camera: PlanetCamera
## Height of the camera view above the player base position.
@export var head_height: float = 1.8
## Mouse sensitivity for looking around.
@export var mouse_sensitivity: float = 0.003

# Accumulators for mouse look rotation
var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	# Capture the mouse for first-person gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse look look input updates
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -deg_to_rad(85.0), deg_to_rad(85.0))


func _physics_process(delta: float) -> void:
	if not planet or not camera:
		return

	# 1. Update core physics, gravity, and terrain collision from PlanetObject parent
	super._physics_process(delta)

	# 2. Align the player body transform to the planet's surface orientation
	_align_transform_to_surface()

	# 3. Handle walking input mechanics inside the physics frame loop
	_handle_movement_input(delta)
	if Input.is_action_just_pressed("ui_accept"): # Map to Spacebar / Jump
		_handle_jump()

	# 4. Position the camera at head level, then apply mouse look orientation
	_update_camera_transform()

	# 5. Tick passive camera mechanics and resolve origin shifts safely
	_sync_origin_shift(delta)


func _align_transform_to_surface() -> void:
	# Calculate a surface orientation basis using up_direction from base class
	var new_up := up_direction
	var old_forward := -global_transform.basis.z
	
	# Project the old forward direction onto the new local horizontal plane
	var new_forward := (old_forward - new_up * old_forward.dot(new_up)).normalized()
	if new_forward.length_squared() < 0.001:
		# Fallback plan if looking directly down/up at poles
		new_forward = global_transform.basis.y
		
	var new_right := new_up.cross(new_forward).normalized()
	
	# Rebuild a clean orthonormal basis matching the curve of the sphere
	global_transform.basis = Basis(new_right, new_up, -new_forward).orthonormalized()


func _handle_movement_input(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length_squared() < 0.001:
		return

	# Determine looking vectors relative to the current horizon surface plane
	var forward_dir := -global_transform.basis.z
	var right_dir := global_transform.basis.x
	
	# Rotate those vectors to account for the camera's local horizontal mouse look (yaw)
	var look_forward := (forward_dir * cos(_yaw) + right_dir * sin(_yaw)).normalized()
	var look_right := look_forward.cross(up_direction).normalized()
	
	# Compute world-space direction vector matching current key combinations
	var movement_dir := (look_right * input_dir.x - look_forward * input_dir.y).normalized()
	
	var acceleration := move_speed * (2.0 if is_grounded else 0.5)
	velocity += movement_dir * acceleration * delta


func _handle_jump() -> void:
	if is_grounded:
		velocity += up_direction * jump_impulse
		is_grounded = false


func _update_camera_transform() -> void:
	# Set base position at the eyes/head height
	camera.global_position = global_position + (up_direction * head_height)
	
	# Build independent camera looking transform matching both body rotation and look inputs
	var base_basis := global_transform.basis
	var look_basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	camera.global_transform.basis = (base_basis * look_basis).orthonormalized()


func _sync_origin_shift(delta: float) -> void:
	# Cache the camera position immediately before it updates
	var pos_before_update := camera.global_position
	
	# Force the passive camera to process its calculations explicitly
	camera.update(delta)
	
	# Measure if a large teleport shift occurred during this physics update step
	var shift_delta := camera.global_position - pos_before_update
	if shift_delta.length_squared() > 1.0:
		# Compensate position mapping instantly to match floating-point origin shifts
		global_position += shift_delta
