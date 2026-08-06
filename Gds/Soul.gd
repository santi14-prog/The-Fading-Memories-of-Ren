extends Area2D
# --- Estrutura da cena esperada ---
# Soul (Area2D)
# ├── Sprite2D (ou AnimatedSprite2D)
# └── CollisionShape2D
@export var value: int = 1                # quantas Almas vale este pickup
@export var magnet_radius: float = 250.0  # distância a que começa a ser atraída
@export var magnet_speed: float = 380.0
@export var bob_height: float = 4.0
@export var bob_speed: float = 3.0
@export var pulse_scale: float = 0.15     # variação percentual do pulso (0.15 = ±15%)
@export var pulse_speed: float = 4.0
@export var base_scale: float = 1.0       # tamanho base da Alma (1.0 = original)
 
var _player: Node2D = null
var _is_attracted: bool = false
var _base_position: Vector2
var _time: float = 0.0
var _spawn_scatter_done: bool = false
 
@onready var sprite: Node2D = $Sprite2D
 
func _ready() -> void:
	z_index = 100  # garante que aparece por cima do chão/TileMap
	area_entered.connect(_on_area_entered)
 
# Chamado pelo SoulDrop logo após a Alma entrar na árvore de cena,
# já com a posição final correta (posição do inimigo morto).
# scatter_dir opcional: direção forçada para espalhar múltiplas Almas em leque.
func setup(spawn_pos: Vector2, scatter_dir: Vector2 = Vector2.ZERO) -> void:
	global_position = spawn_pos
	_base_position = spawn_pos
	_scatter_on_spawn(scatter_dir)
 
# pequeno "salto" para fora do inimigo ao spawnar, para não empilhar tudo no mesmo pixel
func _scatter_on_spawn(forced_dir: Vector2 = Vector2.ZERO) -> void:
	var dir: Vector2
	if forced_dir != Vector2.ZERO:
		dir = forced_dir
	else:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, -0.3)).normalized()
	var target := global_position + dir * randf_range(10.0, 20.0)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", target, 0.35)
	tw.finished.connect(func():
		_base_position = global_position
		_spawn_scatter_done = true
	)
 
func _physics_process(delta: float) -> void:
	_time += delta
	if _is_attracted and _player:
		global_position = global_position.move_toward(_player.global_position, magnet_speed * delta)
		if global_position.distance_to(_player.global_position) < 6.0:
			_collect()
		return
 
	if not _spawn_scatter_done:
		return
 
	# flutuação (bob) + pulsar
	global_position.y = _base_position.y + sin(_time * bob_speed) * bob_height
	var s := base_scale * (1.0 + sin(_time * pulse_speed) * pulse_scale)
	sprite.scale = Vector2(s, s)
 
	# procura o jogador dentro do raio de magnetismo
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p: Node2D = players[0]
			if global_position.distance_to(p.global_position) <= magnet_radius:
				_player = p
				_is_attracted = true
 
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox") or area.is_in_group("player"):
		_collect()
 
func _collect() -> void:
	SoulManager.add_souls(value)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ZERO, 0.12)
	tw.finished.connect(queue_free)
	set_physics_process(false)
	monitoring = false
