extends Node3D

func _ready():
	build_level()

# Creates one box. pos = center of the box, size = (width, height, depth)
func add_block(block_name, pos, size, color, solid = true):
	var body = StaticBody3D.new()
	body.name = block_name
	body.position = pos

	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	if solid:
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)

	add_child(body)

func build_level():
	# Start area marker (visual only, no collision)
	add_block("StartPad", Vector3(0, 0.01, 16), Vector3(8, 0.02, 8), Color(0.2, 0.7, 0.3), false)

	# Platform 1: low step
	add_block("Platform1", Vector3(0, 0.4, 2), Vector3(4, 0.8, 4), Color(0.6, 0.6, 0.7))

	# Wall A: blocks the left side, leaving a gap on the right
	add_block("WallA", Vector3(-9, 1, 10), Vector3(22, 2, 1), Color(0.4, 0.4, 0.45))

	# Wall B: blocks the right side, leaving a gap on the left
	add_block("WallB", Vector3(9, 1, 7), Vector3(22, 2, 1), Color(0.4, 0.4, 0.45))
	
	# Platform 2: higher step, with a 2-unit gap after Platform 1
	add_block("Platform2", Vector3(0, 0.8, -4), Vector3(4, 1.6, 4), Color(0.6, 0.6, 0.7))
	
	# Final area: large platform after a 2-unit gap from Platform 2
	add_block("FinalArea", Vector3(0, 0.8, -14), Vector3(16, 1.6, 12), Color(0.5, 0.5, 0.6))
