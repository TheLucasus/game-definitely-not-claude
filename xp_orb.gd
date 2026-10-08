extends RigidBody3D

var collected = false

func _ready():
	# Settle down after bouncing
	linear_damp = 1.0
	angular_damp = 2.0
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.4
	physics_material.friction = 1.0
	physics_material_override = physics_material

	# Visual: a small glowing yellow ball
	var mesh_instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.2)
	mesh_instance.material_override = material
	add_child(mesh_instance)

	# Solid body so it bounces off floors and platforms
	var body_shape_node = CollisionShape3D.new()
	var body_shape = SphereShape3D.new()
	body_shape.radius = 0.15
	body_shape_node.shape = body_shape
	add_child(body_shape_node)

	# Pickup zone (bigger than the ball so it's easy to collect)
	var area = Area3D.new()
	var area_shape_node = CollisionShape3D.new()
	var area_shape = SphereShape3D.new()
	area_shape.radius = 0.8
	area_shape_node.shape = area_shape
	area.add_child(area_shape_node)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

	# Orbs never push or block the player
	add_collision_exception_with(get_tree().current_scene.get_node("Player"))

func launch(launch_velocity):
	linear_velocity = launch_velocity

func _physics_process(_delta):
	# Safety: remove orbs that fall out of the world
	if global_position.y < -20.0:
		queue_free()

func _on_body_entered(body):
	if collected:
		return
	if body.has_method("add_xp"):
		collected = true
		body.add_xp(1)
		queue_free()
