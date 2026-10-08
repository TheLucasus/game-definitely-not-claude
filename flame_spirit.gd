extends CharacterBody3D

signal finished

const SPEED = 7.0
const ACCELERATION = 30.0
const LAUNCH_SPEED = 14.0
const LIFETIME = 3.0
const RADIUS = 0.5
const HEIGHT = 1.5

var time_left = LIFETIME

func _ready():
	# Visual: translucent red cylinder
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = HEIGHT
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.15, 0.1, 0.5)
	mesh_instance.material_override = material
	add_child(mesh_instance)

	# Solid shape (so walls and platforms block it)
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	collision.shape = shape
	add_child(collision)

	# The spirit and the other characters (player, enemies) pass through each other
	for node in get_tree().current_scene.get_children():
		if node is CharacterBody3D and node != self:
			add_collision_exception_with(node)
			node.add_collision_exception_with(self)

func launch(start_position, direction):
	global_position = start_position
	velocity = direction.normalized() * LAUNCH_SPEED

func _physics_process(delta):
	# End after 3 seconds
	time_left -= delta
	if time_left <= 0.0:
		finished.emit()
		queue_free()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_side = 0.0
	var input_forward = 0.0
	if Input.is_physical_key_pressed(KEY_W):
		input_forward += 1
	if Input.is_physical_key_pressed(KEY_S):
		input_forward -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input_side += 1
	if Input.is_physical_key_pressed(KEY_A):
		input_side -= 1

	# Movement is relative to the camera, same as the player
	var camera = get_viewport().get_camera_3d()
	var forward = -camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right = camera.global_transform.basis.x
	right.y = 0
	right = right.normalized()

	var direction = (right * input_side + forward * input_forward).normalized()
	var target_velocity = direction * SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)

	move_and_slide()
