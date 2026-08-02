extends CharacterBody2D

# --- CONFIGURAÇÕES DE VIDA E FÍSICA ---
const MAX_HEALTH = 50
const GRAVITY = 900.0

# --- DANO DE CONTACTO NO JOGADOR ---
@export var contact_damage: int = 15
@export var attack_cooldown: float = 0.8
var attack_cooldown_timer: float = 0.0

var player_in_range: Node2D = null

var health := MAX_HEALTH
var is_dead := false

# --- NÓS ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_fill: ColorRect = $HealthBarContainer/Fill
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Conecta os sinais da Hitbox (Area2D) por código
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# Aplica dano contínuo enquanto o jogador estiver dentro do inimigo
	if player_in_range and attack_cooldown_timer <= 0:
		_deal_damage_to_player()

	# Gravidade contínua
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	move_and_slide()


func _on_hitbox_body_entered(body: Node2D) -> void:
	# Quando o jogador (Ren) entra na área do inimigo
	if body.has_method("take_damage") and body != self:
		player_in_range = body
		if attack_cooldown_timer <= 0:
			_deal_damage_to_player()


func _on_hitbox_body_exited(body: Node2D) -> void:
	# Quando o jogador sai da área do inimigo
	if body == player_in_range:
		player_in_range = null


func _deal_damage_to_player() -> void:
	if player_in_range and player_in_range.has_method("take_damage"):
		print("💥 INIMIGO DEU DANO NO REN!")
		player_in_range.take_damage(contact_damage)
		attack_cooldown_timer = attack_cooldown


func take_damage(amount: int) -> void:
	if is_dead:
		return

	print("🛡️ O INIMIGO RECEBEU DANO DA ESPADA! Quantidade:", amount)
	health -= amount
	health = max(health, 0)
	_update_health_bar()

	if health <= 0:
		die()
	else:
		_play_hurt_animation()


func _update_health_bar() -> void:
	if health_fill:
		var ratio: float = float(health) / float(MAX_HEALTH)
		health_fill.size.x = 40.0 * ratio


func _play_hurt_animation() -> void:
	if not animated_sprite:
		return

	if animated_sprite.sprite_frames.has_animation("hurt"):
		animated_sprite.play("hurt")
	elif animated_sprite.sprite_frames.has_animation("hit"):
		animated_sprite.play("hit")


func die() -> void:
	is_dead = true
	print("☠️ Inimigo morreu!")

	# Desativa a Hitbox para parar de dar dano quando morre
	if hitbox:
		hitbox.monitoring = false

	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
		elif animated_sprite.sprite_frames.has_animation("die"):
			animated_sprite.play("die")
		else:
			queue_free()
	else:
		queue_free()


func _on_animation_finished() -> void:
	if not animated_sprite:
		return

	var current_anim = animated_sprite.animation

	if current_anim == "hurt" or current_anim == "hit":
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
	elif current_anim == "death" or current_anim == "die":
		queue_free()
