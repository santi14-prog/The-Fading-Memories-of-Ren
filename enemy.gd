extends CharacterBody2D
 
# --- CONFIGURAÇÕES DE VIDA E FÍSICA ---
const MAX_HEALTH = 80
const GRAVITY = 900.0
 
# --- PERSEGUIÇÃO A SALTAR (tipo "slime": carrega, depois dá um pulo) ---
@export var hop_speed: float = 380.0          # velocidade horizontal durante o pulo
@export var hop_height: float = -340.0        # força vertical do pulo (mais negativo = salta mais alto)
@export var charge_time: float = 1.5          # tempo "a carregar" parado antes de saltar
@export var detection_range: float = 500.0    # distância a partir da qual começa a perseguir
var charge_timer: float = 0.0
var is_airborne: bool = false
var player: Node2D = null
 
# --- DANO DE CONTACTO NO JOGADOR ---
@export var contact_damage: int = 10
@export var attack_cooldown: float = 0.8
var attack_cooldown_timer: float = 0.0
var player_in_range: Node2D = null
 
# --- ALMAS (NOVO) ---
@export var soul_scene: PackedScene              # arrasta a Soul.tscn para aqui no Inspector
@export var min_souls: int = 1
@export var max_souls: int = 3
@export var soul_spawn_offset_y: float = -40.0    # quanto mais negativo, mais alto nasce (ajusta ao vivo)
 
var health := MAX_HEALTH
var is_dead := false
 
# --- NÓS ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sprite: AnimatedSprite2D = $AnimatedSprite2D2   # sprite dedicado ao salto, com escala própria
@onready var health_fill: ColorRect = $HealthBarContainer/Fill
@onready var hitbox: Area2D = $Hitbox
 
 
func _ready() -> void:
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
 
	if jump_sprite:
		jump_sprite.visible = false  # começa escondido; só aparece durante o salto
 
	# Conecta os sinais da Hitbox (Area2D) por código
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)
 
	# Procura o jogador pelo grupo "player"
	# (no nó Ren: seleciona-o, vai ao painel "Grupos" ao lado de "Nós",
	# escreve "player" e clica em "Adicionar")
	player = get_tree().get_first_node_in_group("player")
 
	charge_timer = charge_time
 
 
func _physics_process(delta: float) -> void:
	if is_dead:
		return
 
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
 
	# Aplica dano contínuo enquanto o jogador estiver dentro do inimigo
	if player_in_range and attack_cooldown_timer <= 0:
		_deal_damage_to_player()
 
	# se ainda não tem referência ao jogador, tenta encontrar de novo
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
 
	_handle_chase(delta)
 
	# Gravidade contínua
	if not is_on_floor():
		velocity.y += GRAVITY * delta
 
	move_and_slide()
	_update_animation()
 
 
func _handle_chase(delta: float) -> void:
	if not is_instance_valid(player):
		velocity.x = 0
		return
 
	var distance := global_position.distance_to(player.global_position)
	if distance > detection_range:
		velocity.x = 0
		charge_timer = charge_time # fica "resetado" à espera até o jogador voltar a entrar no alcance
		return
 
	if is_on_floor():
		if is_airborne:
			# acabou de aterrar: para completamente e começa a carregar o próximo pulo
			is_airborne = false
			velocity.x = 0
			charge_timer = charge_time
		else:
			# fase de "carregar" — fica parado a olhar para o jogador
			velocity.x = 0
			var look_dir: float = sign(player.global_position.x - global_position.x)
			if look_dir != 0:
				animated_sprite.flip_h = look_dir < 0
				jump_sprite.flip_h = look_dir < 0
 
			charge_timer -= delta
			if charge_timer <= 0:
				var hop_dir: float = sign(player.global_position.x - global_position.x)
				if hop_dir == 0:
					hop_dir = 1.0 if not animated_sprite.flip_h else -1.0
				velocity.y = hop_height
				velocity.x = hop_dir * hop_speed
				is_airborne = true
	# enquanto está no ar, mantém a velocidade horizontal definida no momento do pulo
	# (não faz nada aqui de propósito — deixa a gravidade e o move_and_slide tratarem do resto)
 
 
func _update_animation() -> void:
	if not animated_sprite or is_dead:
		return
	if animated_sprite.animation in ["hurt", "hit", "death", "die"]:
		jump_sprite.visible = false
		return # não interrompe estas animações
 
	if not is_on_floor() or is_airborne:
		# --- SALTO: usa o sprite dedicado, esconde o principal ---
		animated_sprite.visible = false
		jump_sprite.visible = true
		jump_sprite.flip_h = animated_sprite.flip_h
 
		if jump_sprite.sprite_frames.has_animation("jump_up") and velocity.y < 0:
			jump_sprite.play("jump_up")
		elif jump_sprite.sprite_frames.has_animation("jump_fall") and velocity.y >= 0:
			jump_sprite.play("jump_fall")
		elif jump_sprite.sprite_frames.has_animation("jump"):
			jump_sprite.play("jump")
		return
	else:
		# --- QUALQUER OUTRO ESTADO: volta ao sprite principal ---
		animated_sprite.visible = true
		jump_sprite.visible = false
 
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= detection_range \
			and animated_sprite.sprite_frames.has_animation("charge"):
		# está parado a "carregar" o próximo pulo — usa animação dedicada, se existir
		animated_sprite.play("charge")
	elif velocity.x != 0:
		if animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")
	else:
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
 
 
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
		player_in_range.take_damage(contact_damage, global_position)
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
	jump_sprite.visible = false
	animated_sprite.visible = true
	if animated_sprite.sprite_frames.has_animation("hurt"):
		animated_sprite.play("hurt")
	elif animated_sprite.sprite_frames.has_animation("hit"):
		animated_sprite.play("hit")
 
 
func die() -> void:
	is_dead = true
	print("☠️ Inimigo morreu!")
	print("📍 Morreu em: ", global_position, " | Estava no ar? ", is_airborne)
	# Desativa a Hitbox para parar de dar dano quando morre
	if hitbox:
		hitbox.monitoring = false
 
	_drop_souls()  # NOVO — larga as Almas assim que morre, antes da animação terminar
 
	jump_sprite.visible = false
	animated_sprite.visible = true
 
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
		elif animated_sprite.sprite_frames.has_animation("die"):
			animated_sprite.play("die")
		else:
			queue_free()
	else:
		queue_free()
 
 
# NOVO — larga uma quantidade aleatória de Almas na posição do inimigo
func _drop_souls() -> void:
	if soul_scene == null:
		push_warning("enemy.gd: 'soul_scene' não está definida no Inspector — nenhuma Alma foi largada.")
		return
	var amount: int = randi_range(min_souls, max_souls)
	SoulDrop.drop(soul_scene, global_position, amount, null, soul_spawn_offset_y)
 
 
func _on_animation_finished() -> void:
	if not animated_sprite:
		return
	var current_anim = animated_sprite.animation
	if current_anim == "hurt" or current_anim == "hit":
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
	elif current_anim == "death" or current_anim == "die":
		queue_free()
