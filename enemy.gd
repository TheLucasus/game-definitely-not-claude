extends CharacterBody3D

const XpOrb = preload("res://xp_orb.gd")

const BAR_WIDTH = 1.5
const DETECTION_RANGE = 5.0
const STOP_DISTANCE = 1.2
const MOVE_SPEED = 3.0
const TURN_SPEED = 10.0
const ATTACK_RANGE = 2.0
const ATTACK_DAMAGE = 15
const ATTACK_ACTIVE_TIME = 0.15
const ATTACK_COOLDOWN = 1.0
const ORB_COUNT = 10

var max_health = 50
var health = 50
var attack_time_left = 0.0
var attack_cooldown_left = 0.0
var hit_bodies = []

@onready var player = get_tree().current_scene.get_node("Player")
@onready var health_bar = $HealthBar
@onready var fill = $HealthBar/Fill
@onready var outline = $HealthBar/Outline
@onready var hitbox = $AttackHitbox
@onready var hitbox_visual = $AttackHitbox/Visual

func _ready():
	# The enemy never collides with the player's body (fixes the landing bug)
	add_collision_exception_with(player)

	# Give the bar its own plain (unlit) material so the colors show clearly
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.material_override = material

	# Black, unlit material for the outline
	var outline_material = StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color.BLACK
	outline.material_override = outline_material

	# The attack hitbox starts switched off and hidden
	hitbox.monitoring = false
	hitbox_visual.visible = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	# TEMPORARY: see-through purple color so you can watch the enemy swing
	var attack_material = StandardMaterial3D.new()
	attack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	attack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	attack_material.albedo_color = Color(0.6, 0.0, 1.0, 0.4)
	hitbox_visual.material_override = attack_material

	update_health_bar()

func take_damage(amount):
	if health <= 0:
		return

	health = maxi(health - amount, 0)
	update_health_bar()

	if health <= 0:
		die()

func die():
	# Stop acting right away, then drop the orbs at a safe moment
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hide()
	spawn_orbs.call_deferred()

func spawn_orbs():
	for i in ORB_COUNT:
		var angle = (TAU / ORB_COUNT) * i + randf_range(-0.2, 0.2)
		var outward = randf_range(2.5, 4.5)
		var orb = XpOrb.new()
		get_tree().current_scene.add_child(orb)
		orb.global_position = global_position + Vector3(cos(angle) * 0.3, 0.5, sin(angle) * 0.3)
		orb.add_collision_exception_with(self)
		orb.launch(Vector3(cos(angle) * outward, randf_range(4.0, 6.0), sin(angle) * outward))
	queue_free()

func update_health_bar():
	var ratio = float(health) / float(max_health)

	# Shrink the bar, keeping its left edge fixed
	fill.scale.x = maxf(ratio, 0.001)
	fill.position.x = -(1.0 - ratio) * BAR_WIDTH / 2.0

	# Pick the color
	var material = fill.material_override
	if ratio >= 0.5:
		material.albedo_color = Color.GREEN
	elif ratio > 0.25:
		material.albedo_color = Color.YELLOW
	else:
		material.albedo_color = Color.RED

func _process(_delta):
	# Face the bar toward the camera so it can be read from any angle
	var camera = get_viewport().get_camera_3d()
	if camera:
		health_bar.global_basis = camera.global_basis

func start_attack():
	hit_bodies.clear()
	hitbox.monitoring = true
	hitbox_visual.visible = true
	attack_time_left = ATTACK_ACTIVE_TIME
	attack_cooldown_left = ATTACK_ACTIVE_TIME + ATTACK_COOLDOWN

func end_attack():
	hitbox.monitoring = false
	hitbox_visual.visible = false

func _on_hitbox_body_entered(body):
	if body != player:
		return
	if body in hit_bodies:
		return
	hit_bodies.append(body)
	body.take_damage(ATTACK_DAMAGE)

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Count down the timers
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	if attack_time_left > 0.0:
		attack_time_left -= delta
		if attack_time_left <= 0.0:
			end_attack()

	# Work out how far away the player is (ignoring height)
	var to_player = player.global_position - global_position
	to_player.y = 0
	var distance = to_player.length()

	velocity.x = 0
	velocity.z = 0

	if distance <= DETECTION_RANGE and distance > 0.05:
		# Player is noticed: turn toward them
		var direction = to_player.normalized()
		var target_angle = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

		# Walk toward them, but stop once close (this also stops it chasing
		# a player who is standing on top of it)
		if distance > STOP_DISTANCE:
			velocity.x = direction.x * MOVE_SPEED
			velocity.z = direction.z * MOVE_SPEED

		# Close enough and not on cooldown: swing
		if distance <= ATTACK_RANGE and attack_cooldown_left <= 0.0:
			start_attack()

	move_and_slide()

# TEMPORARY: press J to lose 10 enemy health (for testing only)
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			take_damage(10)
