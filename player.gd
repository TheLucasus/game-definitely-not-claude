extends CharacterBody3D

signal health_changed(health, max_health)
signal xp_changed

const SPEED = 6.0
const ACCELERATION = 30.0
const TURN_SPEED = 10.0
const JUMP_VELOCITY = 5.0
const XP_PER_LEVEL = 10
const ATTACK_ACTIVE_TIME = 0.15
const ATTACK_COOLDOWN = 0.1
const COMBO_WINDOW = 0.6
const FINISHER_COOLDOWN = 0.4
const COMBO = [
	{"kind": "horizontal", "from": -60.0, "to": 60.0},
	{"kind": "horizontal", "from": 60.0, "to": -60.0},
	{"kind": "vertical", "from": 70.0, "to": -20.0},
]
const SWING_RADIUS = 1.5
const SPECIAL_ACTIVE_TIME = 0.2
const SPECIAL_COOLDOWN = 2.0
const FlameSpirit = preload("res://flame_spirit.gd")

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
var is_swinging = false
var swing_elapsed = 0.0
var current_swing = {}
var combo_step = 0
var combo_timer = 0.0
var attack_queued = false
var hitbox_base_y = 0.0
var special_on_cooldown = false
var spirit = null
var special_hit_bodies = []

@onready var hitbox = $AttackHitbox
@onready var camera_pivot = get_node("../CameraPivot")
@onready var hitbox_visual = $AttackHitbox/Visual
@onready var special_aoe = $SpecialAOE
@onready var special_visual = $SpecialAOE/Visual

func _ready():
	start_position = global_position
	start_rotation = rotation
	hitbox_base_y = hitbox.position.y

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
	
# Places the hitbox along the current swing. t goes from 0 (start) to 1 (end).
func set_swing_pose(swing, t):
	var angle = deg_to_rad(lerpf(swing["from"], swing["to"], t))
	if swing["kind"] == "horizontal":
		hitbox.position = Vector3(-sin(angle) * SWING_RADIUS, hitbox_base_y, -cos(angle) * SWING_RADIUS)
		hitbox.rotation = Vector3(0, angle, 0)
	else:
		hitbox.position = Vector3(0, hitbox_base_y + sin(angle) * SWING_RADIUS, -cos(angle) * SWING_RADIUS)
		hitbox.rotation = Vector3(angle, 0, 0)

func reset_hitbox_pose():
	hitbox.position = Vector3(0, hitbox_base_y, -SWING_RADIUS)
	hitbox.rotation = Vector3.ZERO

func attack():
	if is_instance_valid(spirit):
		return
	if is_attacking:
		# Remember one early press and use it as soon as this swing is done
		attack_queued = true
		return
	start_swing()

func start_swing():
	is_attacking = true
	attack_queued = false
	hit_bodies.clear()

	# Continue the combo if the last swing was recent, otherwise start over
	if combo_timer <= 0.0:
		combo_step = 0
	current_swing = COMBO[combo_step]

	swing_elapsed = 0.0
	is_swinging = true
	set_swing_pose(current_swing, 0.0)
	hitbox.monitoring = true
	hitbox_visual.visible = true

	# The hitbox sweeps along the swing during this window
	await get_tree().create_timer(ATTACK_ACTIVE_TIME).timeout
	is_swinging = false
	hitbox.monitoring = false
	hitbox_visual.visible = false
	reset_hitbox_pose()

	# Move to the next swing, or finish the combo with a longer recovery
	var cooldown = ATTACK_COOLDOWN
	if combo_step >= COMBO.size() - 1:
		combo_step = 0
		combo_timer = 0.0
		cooldown = FINISHER_COOLDOWN
	else:
		combo_step += 1
		combo_timer = COMBO_WINDOW

	await get_tree().create_timer(cooldown).timeout
	is_attacking = false

	# If Z was pressed during the swing, continue straight away
	if attack_queued:
		start_swing()

func _on_hitbox_body_entered(body):
	if body == self:
		return
	if body in hit_bodies:
		return
	if body.has_method("take_damage"):
		hit_bodies.append(body)
		body.take_damage(roundi(attack_damage))

func special_attack():
	if is_attacking or special_on_cooldown or is_instance_valid(spirit):
		return
	special_on_cooldown = true
	var forward = -global_transform.basis.z
	spirit = FlameSpirit.new()
	get_parent().add_child(spirit)
	spirit.launch(global_position + Vector3(0, 0.25, 0) + forward * 1.2, forward)
	spirit.finished.connect(_on_spirit_finished)
	camera_pivot.follow_target = spirit

func _on_spirit_finished():
	camera_pivot.follow_target = null
	spirit = null
	# Recharge before the next use
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
		if event.keycode == KEY_SPACE and is_on_floor() and not is_instance_valid(spirit):
			velocity.y = JUMP_VELOCITY
			

func _physics_process(delta):
	combo_timer = maxf(combo_timer - delta, 0.0)
	if is_swinging:
		swing_elapsed += delta
		var t = clampf(swing_elapsed / ATTACK_ACTIVE_TIME, 0.0, 1.0)
		set_swing_pose(current_swing, t)
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
	# Stay still while controlling the flame spirit
	if is_instance_valid(spirit):
		input_side = 0.0
		input_forward = 0.0
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
