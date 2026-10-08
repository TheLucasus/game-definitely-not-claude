extends CharacterBody3D

signal health_changed(health, max_health)
signal xp_changed

const SPEED = 6.0
const ACCELERATION = 30.0
const TURN_SPEED = 10.0
const JUMP_VELOCITY = 5.0
const XP_PER_LEVEL = 10
const ATTACK_ACTIVE_TIME = 0.15
const ATTACK_COOLDOWN = 0.35
const SPECIAL_ACTIVE_TIME = 0.2
const SPECIAL_COOLDOWN = 2.0

var max_health = 100
var level = 1
var xp = 0
var is_leveling = false
var attack_damage = 25.0
var special_damage = 30.0
var health = 100
var start_position = Vector3.ZERO
var start_rotation = Vector3.ZERO
var is_attacking = false
var hit_bodies = []
var special_on_cooldown = false
var special_hit_bodies = []

@onready var hitbox = $AttackHitbox
@onready var hitbox_visual = $AttackHitbox/Visual
@onready var special_aoe = $SpecialAOE
@onready var special_visual = $SpecialAOE/Visual

func _ready():
	start_position = global_position
	start_rotation = rotation

	# The hitboxes start switched off and hidden
	hitbox.monitoring = false
	hitbox_visual.visible = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	special_aoe.monitoring = false
	special_visual.visible = false
	special_aoe.body_entered.connect(_on_special_body_entered)

	# TEMPORARY: see-through orange color so you can watch the swing
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.5, 0.0, 0.4)
	hitbox_visual.material_override = material

	# TEMPORARY: see-through cyan color for the special move
	var special_material = StandardMaterial3D.new()
	special_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	special_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	special_material.albedo_color = Color(0.0, 0.8, 1.0, 0.3)
	special_visual.material_override = special_material

func add_xp(amount):
	xp += amount
	xp_changed.emit()
	if is_leveling:
		return
	is_leveling = true
	# Brief pause so the bar visibly shows 10 / 10 before it resets
	while xp >= XP_PER_LEVEL:
		await get_tree().create_timer(0.3).timeout
		level_up()
	is_leveling = false

func level_up():
	level += 1
	xp -= XP_PER_LEVEL
	attack_damage *= 1.05
	special_damage *= 1.05
	max_health = roundi(max_health * 1.1)
	health = max_health
	health_changed.emit(health, max_health)
	xp_changed.emit()

func take_damage(amount):
	health = maxi(health - amount, 0)
	if health == 0:
		respawn()
	health_changed.emit(health, max_health)

func respawn():
	health = max_health
	global_position = start_position
	rotation = start_rotation
	velocity = Vector3.ZERO

func attack():
	if is_attacking:
		return
	is_attacking = true
	hit_bodies.clear()
	hitbox.monitoring = true
	hitbox_visual.visible = true

	# Hitbox is active for a short window
	await get_tree().create_timer(ATTACK_ACTIVE_TIME).timeout
	hitbox.monitoring = false
	hitbox_visual.visible = false

	# Then a cooldown before the next attack is allowed
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	is_attacking = false

func _on_hitbox_body_entered(body):
	if body == self:
		return
	if body in hit_bodies:
		return
	if body.has_method("take_damage"):
		hit_bodies.append(body)
		body.take_damage(roundi(attack_damage))

func special_attack():
	if is_attacking or special_on_cooldown:
		return
	is_attacking = true
	special_on_cooldown = true
	special_hit_bodies.clear()
	special_aoe.monitoring = true
	special_visual.visible = true

	# The area is active for a short window
	await get_tree().create_timer(SPECIAL_ACTIVE_TIME).timeout
	special_aoe.monitoring = false
	special_visual.visible = false
	is_attacking = false

	# The special move needs time to recharge
	await get_tree().create_timer(SPECIAL_COOLDOWN).timeout
	special_on_cooldown = false

func _on_special_body_entered(body):
	if body == self:
		return
	if body in special_hit_bodies:
		return
	if body.has_method("take_damage"):
		special_hit_bodies.append(body)
		body.take_damage(roundi(special_damage))

# TEMPORARY test keys: K = lose 10 health, Space = attack, Q = special move
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			take_damage(10)
		if event.keycode == KEY_COMMA:
			attack()
		if event.keycode == KEY_PERIOD:
			special_attack()
		if event.keycode == KEY_SPACE and is_on_floor():
			velocity.y = JUMP_VELOCITY
			

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	if global_position.y < -20.0:
		respawn()

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

	var camera = get_viewport().get_camera_3d()
	var forward = -camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right = camera.global_transform.basis.x
	right.y = 0
	right = right.normalized()

	var direction = (right * input_side + forward * input_forward).normalized()

	if direction != Vector3.ZERO:
		var target_angle = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

	var target_velocity = direction * SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)

	move_and_slide()
