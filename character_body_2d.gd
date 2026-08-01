extends CharacterBody2D

# --- MOVIMENTO ---
const SPEED = 320.0
const ACCELERATION = 2000.0
const FRICTION = 2200.0

# --- SALTO ---
const JUMP_VELOCITY = -650.0
const JUMP_CUT_MULTIPLIER = 0.5
const GRAVITY = 900.0
const COYOTE_TIME = 0.12
const JUMP_BUFFER = 0.12

# --- DASH ---
const DASH_SPEED = 700.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.5

# --- PLANAR ---
const GLIDE_GRAVITY = 150.0
const GLIDE_MAX_FALL = 80.0

# --- COMBATE ---
const COMBO_WINDOW = 0.5
const ATTACK_DURATION = 0.25
const ATTACK_DAMAGE = [10, 12, 18]

const PROJECTILE_SCENE: PackedScene = preload("res://projectile.tscn")
const RANGED_COOLDOWN = 0.6
const PROJECTILE_OFFSET = 24.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var slash_visual: AnimatedSprite2D = $AttackHitbox/SlashVisual
@onready var sword_visual: AnimatedSprite2D = $SwordVisual

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 0.0
var is_dashing := false

var facing_direction := 1.0

var combo_step := 0
var combo_timer := 0.0
var attack_timer := 0.0
var is_attacking := false

var ranged_cooldown_timer := 0.0

var sword_base_x := 0.0
var slash_base_x := 0.0
var hitbox_base_x := 0.0


func _ready() -> void:
	sword_base_x = sword_visual.position.x
	slash_base_x = slash_visual.position.x
	hitbox_base_x = attack_hitbox.position.x

	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	attack_hitbox.body_entered.connect(_on_attack_hit)
	slash_visual.visible = false
	sword_visual.visible = true


func _physics_process(delta: float) -> void:
	dash_cooldown_timer -= delta
	combo_timer -= delta
	ranged_cooldown_timer -= delta

	_handle_attack_input(delta)

	# --- DASH ---
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		var input_dir := Input.get_axis("move_left", "move_right")
		dash_direction = input_dir if input_dir != 0 else facing_direction

	if is_dashing:
		dash_timer -= delta
		velocity = Vector2(dash_direction * DASH_SPEED, 0)
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		animated_sprite.play("dash")
		animated_sprite.flip_h = facing_direction < 0
		return

	# --- GRAVIDADE / PLANAR ---
	var is_gliding := not is_on_floor() and velocity.y > 0 and Input.is_action_pressed("jump")

	if not is_on_floor():
		if is_gliding:
			velocity.y += GLIDE_GRAVITY * delta
			velocity.y = min(velocity.y, GLIDE_MAX_FALL)
		else:
			velocity.y += GRAVITY * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME

	# --- SALTO ---
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0
		jump_buffer_timer = 0

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	# --- MOVIMENTO HORIZONTAL ---
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		facing_direction = direction
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()
	_update_animation()


func _handle_attack_input(delta: float) -> void:
	# --- ATAQUE CORPO A CORPO (combo) ---
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			attack_hitbox.monitoring = false
			slash_visual.visible = false
			sword_visual.visible = true

	if Input.is_action_just_pressed("attack"):
		if not is_attacking or combo_timer > 0:
			combo_step = (combo_step + 1) if combo_timer > 0 else 1
			combo_step = min(combo_step, 3)
			is_attacking = true
			attack_timer = ATTACK_DURATION
			combo_timer = COMBO_WINDOW
			attack_hitbox.position.x = hitbox_base_x * facing_direction
			attack_hitbox.monitoring = true
			sword_visual.visible = false
			slash_visual.visible = true
			slash_visual.play("swing")

	if combo_timer <= 0:
		combo_step = 0

	# --- ATAQUE À DISTÂNCIA ---
	if Input.is_action_just_pressed("ranged_attack") and ranged_cooldown_timer <= 0:
		ranged_cooldown_timer = RANGED_COOLDOWN
		var projectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position + Vector2(PROJECTILE_OFFSET * facing_direction, 0)
		projectile.direction = facing_direction


func _on_attack_hit(body: Node2D) -> void:
	if body.has_method("take_damage"):
		var dmg: int = ATTACK_DAMAGE[combo_step - 1]
		body.take_damage(dmg)


func _update_animation() -> void:
	if is_dashing:
		return

	if not is_on_floor():
		animated_sprite.play("fall")
	elif velocity.x != 0:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")

	animated_sprite.flip_h = facing_direction < 0

	sword_visual.flip_h = facing_direction < 0
	sword_visual.position.x = sword_base_x * facing_direction

	slash_visual.flip_h = facing_direction < 0
	slash_visual.position.x = slash_base_x * facing_direction
