extends Node3D

const FOLLOW_SPEED = 6.0
const TURN_SPEED = 2.0
const ROLL_SPEED = 3.0
const HEIGHT_OFFSET = Vector3(0, 1, 0)

const NORMAL_PITCH = -20.0   # normal camera tilt, in degrees
const TOP_PITCH = -80.0      # tilt when the view is blocked (almost straight down)
const PITCH_SPEED = 4.0      # how fast the camera tilts up and down
const CAMERA_DISTANCE = 6.0  # same as the SpringArm3D length
const HOLD_TIME = 0.4        # seconds to stay raised after the view clears

# Camera rotation targets, in degrees. Level zones can change these later.
# Rotate: 0 = looking toward -Z, positive turns the camera to the left.
# Tilt: 0 = level, positive or negative leans the view sideways.
var target_yaw_degrees = 0.0
var target_roll_degrees = 0.0

var target_pitch_degrees = NORMAL_PITCH
var raise_timer = 0.0

@onready var player = get_node("../Player")

func _ready():
	# The camera now tilts up to avoid walls, so the arm doesn't need to
	# detect anything. Turning off its collisions stops it from snapping in.
	$SpringArm3D.collision_mask = 0

# UNUSED FOR NOW: one call to change both. Example: set_view(90.0, 10.0)
func set_view(yaw_degrees, roll_degrees = 0.0):
	target_yaw_degrees = yaw_degrees
	target_roll_degrees = roll_degrees

func _physics_process(delta):
	# Where would the camera sit at its normal angle?
	var normal_basis = Basis.from_euler(Vector3(deg_to_rad(NORMAL_PITCH), rotation.y, 0))
	var normal_camera_position = global_position + normal_basis * Vector3(0, 0, CAMERA_DISTANCE)

	# Is anything solid between that spot and the player?
	var query = PhysicsRayQueryParameters3D.create(global_position, normal_camera_position)
	query.exclude = [player.get_rid()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	var blocked = not result.is_empty() and result.collider is StaticBody3D

	# Stay raised for a moment after the view clears, so it doesn't flicker
	if blocked:
		raise_timer = HOLD_TIME
	else:
		raise_timer = maxf(raise_timer - delta, 0.0)

	if raise_timer > 0.0:
		target_pitch_degrees = TOP_PITCH
	else:
		target_pitch_degrees = NORMAL_PITCH

func _process(delta):
	# Smoothly follow the player
	var target_position = player.global_position + HEIGHT_OFFSET
	global_position = global_position.lerp(target_position, FOLLOW_SPEED * delta)

	# Smoothly rotate left/right
	rotation.y = lerp_angle(rotation.y, deg_to_rad(target_yaw_degrees), TURN_SPEED * delta)

	# Smoothly tilt up or down
	rotation.x = lerp_angle(rotation.x, deg_to_rad(target_pitch_degrees), PITCH_SPEED * delta)

	# Smoothly lean sideways
	rotation.z = lerp_angle(rotation.z, deg_to_rad(target_roll_degrees), ROLL_SPEED * delta)
