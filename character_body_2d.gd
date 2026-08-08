extends CharacterBody2D

# --- MOVIMENTO ---
const SPEED = 400.0
const ACCELERATION = 2000.0
const FRICTION = 2200.0

# --- SALTO ---
const JUMP_VELOCITY = -780.0
const JUMP_CUT_MULTIPLIER = 0.5
const GRAVITY = 1300.0
const COYOTE_TIME = 0.12
const JUMP_BUFFER = 0.12
const MAX_JUMPS = 2

# --- DASH ---
const DASH_SPEED = 900.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.75

# --- PLANAR ---
const GLIDE_GRAVITY = 150.0
const GLIDE_MAX_FALL = 80.0
const GLIDE_RANGED_GRAVITY_MULTIPLIER = 9.0
const GLIDE_RANGED_MAX_FALL = 500.0

# --- COMBATE ---
const ATTACK_DURATION = 0.25
const ATTACK_DAMAGE = 10 # Dano fixo simplificado

# --- POGO (bounce ao acertar ataque para baixo no ar) ---
const POGO_BOUNCE_VELOCITY = -650.0
const POGO_REFUND_JUMPS = true

const PROJECTILE_SCENE: PackedScene = preload("res://projectile.tscn")
const RANGED_COOLDOWN = 1.2
const PROJECTILE_OFFSET = 24.0
const PROJECTILE_SPEED = 1200.0

# --- KNOCKBACK ---
const KNOCKBACK_FORCE = 320.0
const KNOCKBACK_UP = -180.0
const HIT_STUN_TIME = 0.20

# --- VIDA ---
const MAX_HEALTH = 100

# --- MORTE / RESPAWN ---
const PARTICLE_FLIGHT_SPEED = 450.0
const PARTICLE_FLIGHT_MIN_DURATION = 0.4
const PARTICLE_FLIGHT_MAX_DURATION = 4.0


signal health_changed(current_health: int, max_health: int)
signal died

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var attack_hitbox: Area2D = $Visuals/AttackHitbox
@onready var attack_shape: CollisionShape2D = $Visuals/AttackHitbox/CollisionShape2D
@onready var slash_visual: AnimatedSprite2D = $Visuals/AttackHitbox/SlashVisual
@onready var sword_visual: AnimatedSprite2D = $Visuals/SwordVisual
@onready var ranged_visual: AnimatedSprite2D = $Visuals/ranged_attack
@onready var walk_ranged_visual: AnimatedSprite2D = $Visuals/walk_ranged
@onready var dash_ranged_visual: AnimatedSprite2D = $Visuals/dash_ranged
@onready var death_particles: GPUParticles2D = $DeathParticles

@export var dash_icon: Control
@export var projectile_icon: Control

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var jumps_used := 0

var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 0.0
var is_dashing := false

var facing_direction := 1.0

var attack_timer := 0.0
var is_attacking := false

## 0 = ataque horizontal, 1 = ataque para cima, -1 = ataque para baixo
var current_attack_aim := 0

var ranged_cooldown_timer := 0.0
var is_ranged_playing := false

var current_health := MAX_HEALTH

var hit_stun_timer := 0.0

var is_dead := false


func _ready() -> void:
	print("TESTE 123")
	if is_instance_valid(attack_hitbox):
		attack_hitbox.monitoring = false

		if attack_hitbox.body_entered.is_connected(_on_attack_hit):
			attack_hitbox.body_entered.disconnect(_on_attack_hit)
		attack_hitbox.body_entered.connect(_on_attack_hit)

		if attack_hitbox.area_entered.is_connected(_on_attack_area_hit):
			attack_hitbox.area_entered.disconnect(_on_attack_area_hit)
		attack_hitbox.area_entered.connect(_on_attack_area_hit)

	_reset_attack_transform()

	if is_instance_valid(ranged_visual):
		ranged_visual.visible = false
		ranged_visual.animation_finished.connect(_on_ranged_animation_finished)

	if is_instance_valid(walk_ranged_visual):
		walk_ranged_visual.visible = false
	if is_instance_valid(dash_ranged_visual):
		dash_ranged_visual.visible = false

	if is_instance_valid(animated_sprite):
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("died"):
			animated_sprite.sprite_frames.set_animation_loop("died", false)

	current_health = MAX_HEALTH
	health_changed.emit(current_health, MAX_HEALTH)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if hit_stun_timer > 0:
		hit_stun_timer -= delta
		velocity.y += GRAVITY * delta
		move_and_slide()
		_update_animation()
		_update_facing()
		return

	dash_cooldown_timer -= delta
	ranged_cooldown_timer -= delta

	_handle_attack_input(delta)

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		var input_dir := Input.get_axis("move_left", "move_right")
		dash_direction = input_dir if input_dir != 0 else facing_direction

		if dash_icon and dash_icon.has_method("start_cooldown"):
			dash_icon.start_cooldown(DASH_COOLDOWN)

	if is_dashing:
		dash_timer -= delta
		velocity = Vector2(dash_direction * DASH_SPEED, 0)
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		_update_animation()
		_update_facing()
		return

	var is_gliding := not is_on_floor() and velocity.y > 0 and Input.is_action_pressed("jump")

	if not is_on_floor():
		if is_gliding:
			var glide_gravity := GLIDE_GRAVITY
			var glide_max_fall := GLIDE_MAX_FALL
			if is_ranged_playing:
				glide_gravity *= GLIDE_RANGED_GRAVITY_MULTIPLIER
				glide_max_fall = GLIDE_RANGED_MAX_FALL
			velocity.y += glide_gravity * delta
			velocity.y = min(velocity.y, glide_max_fall)
		else:
			velocity.y += GRAVITY * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME
		jumps_used = 0

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0
		jump_buffer_timer = 0
		jumps_used = 1
	elif jump_buffer_timer > 0 and jumps_used < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		jumps_used += 1

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		facing_direction = direction
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()
	_update_animation()
	_update_facing()


func _update_facing() -> void:
	if is_instance_valid(visuals):
		visuals.scale.x = facing_direction


func _handle_attack_input(delta: float) -> void:
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			_reset_attack_transform()

	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		attack_timer = ATTACK_DURATION

		if is_instance_valid(sword_visual):
			sword_visual.visible = false
		if is_instance_valid(slash_visual):
			slash_visual.visible = true

		# Verifica Input Map e também teclas diretas (S e Seta para Baixo)
		var press_down := Input.is_action_pressed("aim_down") or Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		var press_up := Input.is_action_pressed("aim_up") or Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)

		if press_down:
			current_attack_aim = -1
			# ATAQUE PARA BAIXO:
			# Move a espada mais para baixo (Y: 45) e um pouco para a frente (X: 10) para afastar da cabeça/pés
			_set_attack_transform(Vector2(10, 45), 135.0)
		elif press_up:
			current_attack_aim = 1
			# ATAQUE PARA CIMA:
			# Move a espada bem para cima (Y: -50) para sair da cabeça e alinhar com a mão
			_set_attack_transform(Vector2(10, -50), -45.0)
		else:
			current_attack_aim = 0
			# ATAQUE HORIZONTAL (LADOS):
			# Move a espada para a frente no eixo X (X: 35) e alinha na altura da mão (Y: 5)
			_set_attack_transform(Vector2(35, 5), 0.0)

		if is_instance_valid(slash_visual):
			slash_visual.play("swing")

		if is_instance_valid(attack_hitbox):
			attack_hitbox.monitoring = true
			_check_overlapping_attacks()

	if Input.is_action_just_pressed("ranged_attack") and ranged_cooldown_timer <= 0:
		ranged_cooldown_timer = RANGED_COOLDOWN

		if projectile_icon and projectile_icon.has_method("start_cooldown"):
			projectile_icon.start_cooldown(RANGED_COOLDOWN)

		is_ranged_playing = true
		if is_instance_valid(ranged_visual):
			ranged_visual.visible = true
			ranged_visual.play("ranged_attack")

		var projectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position + Vector2(PROJECTILE_OFFSET * facing_direction, 0)

		projectile.direction = facing_direction
		if "speed" in projectile:
			projectile.speed = PROJECTILE_SPEED


func _set_attack_transform(pos: Vector2, rot: float) -> void:
	if is_instance_valid(attack_hitbox):
		attack_hitbox.position = pos
		attack_hitbox.rotation_degrees = rot


func _reset_attack_transform() -> void:
	if is_instance_valid(attack_hitbox):
		attack_hitbox.monitoring = false
		attack_hitbox.position = Vector2.ZERO
		attack_hitbox.rotation_degrees = 0
	if is_instance_valid(slash_visual):
		slash_visual.visible = false
		slash_visual.position = Vector2.ZERO
		slash_visual.rotation_degrees = 0
	if is_instance_valid(sword_visual):
		sword_visual.visible = true


func _check_overlapping_attacks() -> void:
	if not is_attacking or not is_instance_valid(attack_hitbox):
		return
	for body in attack_hitbox.get_overlapping_bodies():
		_on_attack_hit(body)
	for area in attack_hitbox.get_overlapping_areas():
		_on_attack_area_hit(area)


func _on_ranged_animation_finished() -> void:
	if is_instance_valid(ranged_visual):
		ranged_visual.visible = false
	if is_instance_valid(walk_ranged_visual):
		walk_ranged_visual.visible = false
	if is_instance_valid(dash_ranged_visual):
		dash_ranged_visual.visible = false
	is_ranged_playing = false
	if is_instance_valid(animated_sprite):
		animated_sprite.visible = true


func _on_walk_ranged_finished() -> void:
	if is_instance_valid(walk_ranged_visual):
		walk_ranged_visual.visible = false
	is_ranged_playing = false


func _on_dash_ranged_finished() -> void:
	if is_instance_valid(dash_ranged_visual):
		dash_ranged_visual.visible = false
	is_ranged_playing = false


func _on_attack_hit(body: Node2D) -> void:
	if body == self:
		return

	if body.has_method("take_damage"):
		body.take_damage(ATTACK_DAMAGE)
		_try_pogo()


func _on_attack_area_hit(area: Area2D) -> void:
	if area == attack_hitbox:
		return

	var target: Node = null
	if area.has_method("take_damage"):
		target = area
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		target = area.get_parent()

	if target:
		target.take_damage(ATTACK_DAMAGE)
		_try_pogo()


func _try_pogo() -> void:
	if current_attack_aim == -1 and not is_on_floor():
		velocity.y = POGO_BOUNCE_VELOCITY
		if POGO_REFUND_JUMPS:
			jumps_used = 0


func take_damage(amount: int, source_position: Vector2 = global_position) -> void:
	if is_dead:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, MAX_HEALTH)

	if current_health <= 0:
		died.emit()
		_start_death()
		return

	var knock_dir: float = sign(global_position.x - source_position.x)
	if knock_dir == 0:
		knock_dir = -facing_direction
	velocity.x = knock_dir * KNOCKBACK_FORCE
	velocity.y = KNOCKBACK_UP
	hit_stun_timer = HIT_STUN_TIME


func _start_death() -> void:
	is_dead = true

	is_attacking = false
	is_dashing = false
	is_ranged_playing = false
	velocity = Vector2.ZERO

	if is_instance_valid(attack_hitbox):
		attack_hitbox.monitoring = false
	if is_instance_valid(slash_visual):
		slash_visual.visible = false
	if is_instance_valid(sword_visual):
		sword_visual.visible = false
	if is_instance_valid(ranged_visual):
		ranged_visual.visible = false
	if is_instance_valid(walk_ranged_visual):
		walk_ranged_visual.visible = false
	if is_instance_valid(dash_ranged_visual):
		dash_ranged_visual.visible = false

	if is_instance_valid(animated_sprite):
		animated_sprite.visible = true
		animated_sprite.play("died")

		var frames := animated_sprite.sprite_frames
		if frames and frames.has_animation("died"):
			var frame_count := frames.get_frame_count("died")
			var fps := frames.get_animation_speed("died")
			if fps <= 0:
				fps = 1.0
			var duration := (frame_count / fps) + 0.2
			await get_tree().create_timer(duration).timeout
			if is_dead:
				animated_sprite.visible = false
				_fly_particles_to_respawn()


func _fly_particles_to_respawn() -> void:
	var respawn_node = get_tree().current_scene.find_child("RespawnPoint", true, false)
	var target_pos: Vector2 = respawn_node.global_position if respawn_node else global_position

	if is_instance_valid(death_particles):
		death_particles.restart()

	var collision_shape := $CollisionShape2D
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)

	var distance := global_position.distance_to(target_pos)
	var flight_duration: float = clamp(distance / PARTICLE_FLIGHT_SPEED, PARTICLE_FLIGHT_MIN_DURATION, PARTICLE_FLIGHT_MAX_DURATION)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_pos, flight_duration)
	tween.tween_callback(func():
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", false)
		_die()
	)


func _on_animated_sprite_animation_finished() -> void:
	pass


func _die() -> void:
	if not is_dead:
		return

	var respawn_node = get_tree().current_scene.find_child("RespawnPoint", true, false)
	if respawn_node:
		global_position = respawn_node.global_position

	current_health = MAX_HEALTH
	health_changed.emit(current_health, MAX_HEALTH)

	if is_instance_valid(sword_visual):
		sword_visual.visible = true
	is_dead = false
	if is_instance_valid(animated_sprite):
		animated_sprite.play("idle")


func _update_animation() -> void:
	if is_dashing:
		if is_ranged_playing and dash_ranged_visual:
			if is_instance_valid(animated_sprite): animated_sprite.visible = false
			if is_instance_valid(ranged_visual): ranged_visual.visible = false
			if is_instance_valid(walk_ranged_visual): walk_ranged_visual.visible = false
			dash_ranged_visual.visible = true
			dash_ranged_visual.play("dash_ranged")
		else:
			if is_instance_valid(animated_sprite):
				animated_sprite.visible = true
				animated_sprite.play("dash")
			if is_instance_valid(walk_ranged_visual): walk_ranged_visual.visible = false
			if is_instance_valid(dash_ranged_visual): dash_ranged_visual.visible = false
			if is_instance_valid(ranged_visual): ranged_visual.visible = false
		return

	if is_ranged_playing:
		if is_on_floor() and velocity.x != 0:
			if is_instance_valid(ranged_visual): ranged_visual.visible = false
			if is_instance_valid(animated_sprite): animated_sprite.visible = false
			if is_instance_valid(dash_ranged_visual): dash_ranged_visual.visible = false
			if is_instance_valid(walk_ranged_visual):
				walk_ranged_visual.visible = true
				walk_ranged_visual.play("walk_ranged")
			return
		else:
			if is_instance_valid(ranged_visual): ranged_visual.visible = true
			if is_instance_valid(animated_sprite): animated_sprite.visible = false
			if is_instance_valid(walk_ranged_visual): walk_ranged_visual.visible = false
			if is_instance_valid(dash_ranged_visual): dash_ranged_visual.visible = false
			return
	else:
		if is_instance_valid(animated_sprite): animated_sprite.visible = true
		if is_instance_valid(walk_ranged_visual): walk_ranged_visual.visible = false
		if is_instance_valid(dash_ranged_visual): dash_ranged_visual.visible = false

	if is_instance_valid(animated_sprite):
		if not is_on_floor():
			animated_sprite.play("fall")
		elif velocity.x != 0:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")
