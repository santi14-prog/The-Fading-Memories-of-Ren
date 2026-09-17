extends Area2D
# --- Estrutura da cena esperada ---
# Soul (Area2D)
# ├── Sprite2D (AnimatedSprite2D)
# └── CollisionShape2D
@export var value: int = 1                # quantas Almas vale este pickup
@export var magnet_radius: float = 250.0  # distância a que começa a ser atraída
@export var magnet_speed: float = 380.0
@export var bob_height: float = 4.0
@export var bob_speed: float = 3.0
@export var pulse_scale: float = 0.15     # variação percentual do pulso (0.15 = ±15%)
@export var pulse_speed: float = 4.0
@export var base_scale: float = 10.0      # tamanho base da Alma (1.0 = original)

const ORB_TEXTURES := [
	preload("res://assets/souls/orb_anim_2_pulso_azul_royal_8x_1.png"),
	preload("res://assets/souls/orb_anim_3_pulso_ciano_8x_1.png"),
]
const ORB_FRAME_COUNT := 4
const ORB_FPS := 8.0

static var _cached_frames: SpriteFrames = null

static func _get_shared_frames() -> SpriteFrames:
	if _cached_frames == null:
		_cached_frames = SpriteFrames.new()
		for i in ORB_TEXTURES.size():
			var tex: Texture2D = ORB_TEXTURES[i]
			var frame_size := Vector2i(tex.get_width() / ORB_FRAME_COUNT, tex.get_height())
			var anim_name := "orb_%d" % i
			_cached_frames.add_animation(anim_name)
			_cached_frames.set_animation_speed(anim_name, ORB_FPS)
			_cached_frames.set_animation_loop(anim_name, true)
			for f in ORB_FRAME_COUNT:
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(f * frame_size.x, 0, frame_size.x, frame_size.y)
				_cached_frames.add_frame(anim_name, atlas)
	return _cached_frames

var _player: Node2D = null
var _is_attracted: bool = false
var _base_position: Vector2
var _time: float = 0.0
var _spawn_scatter_done: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	sprite.sprite_frames = _get_shared_frames()
	sprite.animation = "orb_%d" % (randi() % ORB_TEXTURES.size())
	sprite.play()
	sprite.scale = Vector2(base_scale, base_scale)   # aplica já, mesmo antes do scatter acabar
	print("base_scale=", base_scale, " sprite.scale=", sprite.scale, " soul.scale=", scale, " global_scale=", global_scale)
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
