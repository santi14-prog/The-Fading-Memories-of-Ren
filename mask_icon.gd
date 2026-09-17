extends Node2D
class_name MaskIcon

## Ícone de vida em forma de máscara (healthbar).
## - Idle: leve "respiração" (bob + pulse) em loop
## - explode(): parte a própria textura em fragmentos e dispersa-os,
##   sem precisar de sprite-sheet de explosão feito à mão.

@onready var idle_sprite: Sprite2D = $Idle

@export_group("Idle")
@export var idle_bob_amount: float = 2.0
@export var idle_bob_speed: float = 1.6
@export var idle_pulse_amount: float = 0.04
@export var idle_pulse_speed: float = 1.2

@export_group("Explosão")
@export var fragment_grid_size: int = 4          # divide a textura em grid_size x grid_size pedaços
@export var explosion_force_min: float = 80.0
@export var explosion_force_max: float = 220.0
@export var explosion_gravity: float = 500.0
@export var explosion_spin_max: float = 8.0        # rad/s
@export var explosion_duration: float = 0.7
@export var fragment_fade_start: float = 0.35       # % da duração em que começa a desaparecer (0-1)

signal explosion_finished

var _idle_tween: Tween
var _base_position: Vector2
var _is_exploding: bool = false


func _ready() -> void:
	_base_position = idle_sprite.position
	_start_idle_animation()


func _start_idle_animation() -> void:
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_idle_tween.tween_property(
		idle_sprite, "position:y",
		_base_position.y - idle_bob_amount, idle_bob_speed
	)
	_idle_tween.parallel().tween_property(
		idle_sprite, "scale",
		Vector2.ONE * (1.0 + idle_pulse_amount), idle_pulse_speed
	)
	_idle_tween.tween_property(
		idle_sprite, "position:y",
		_base_position.y, idle_bob_speed
	)
	_idle_tween.parallel().tween_property(
		idle_sprite, "scale",
		Vector2.ONE, idle_pulse_speed
	)


## Chama isto quando o jogador perde uma vida.
func explode() -> void:
	if _is_exploding:
		return
	_is_exploding = true

	if _idle_tween:
		_idle_tween.kill()

	var texture: Texture2D = idle_sprite.texture
	if texture == null:
		_is_exploding = false
		return

	idle_sprite.visible = false

	var tex_size: Vector2 = texture.get_size()
	var piece_size: Vector2 = tex_size / fragment_grid_size

	for y in range(fragment_grid_size):
		for x in range(fragment_grid_size):
			_spawn_fragment(texture, piece_size, x, y)

	await get_tree().create_timer(explosion_duration).timeout
	explosion_finished.emit()


func _spawn_fragment(texture: Texture2D, piece_size: Vector2, grid_x: int, grid_y: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		grid_x * piece_size.x, grid_y * piece_size.y,
		piece_size.x, piece_size.y
	)

	var frag := Sprite2D.new()
	frag.texture = atlas
	frag.centered = true
	frag.position = idle_sprite.position + Vector2(
		(grid_x + 0.5) * piece_size.x - (piece_size.x * fragment_grid_size) / 2.0,
		(grid_y + 0.5) * piece_size.y - (piece_size.y * fragment_grid_size) / 2.0
	) * idle_sprite.scale
	frag.scale = idle_sprite.scale
	add_child(frag)

	# Direção radial a partir do centro da máscara + aleatoriedade
	var center_offset: Vector2 = frag.position - idle_sprite.position
	var dir: Vector2 = center_offset.normalized() if center_offset.length() > 0.1 \
		else Vector2.RIGHT.rotated(randf() * TAU)
	dir = dir.rotated(randf_range(-0.5, 0.5))

	var speed: float = randf_range(explosion_force_min, explosion_force_max)
	var velocity: Vector2 = dir * speed
	var spin: float = randf_range(-explosion_spin_max, explosion_spin_max)

	var elapsed := 0.0
	var start_pos := frag.position
	var fade_delay := explosion_duration * fragment_fade_start

	var tick_tween := create_tween()
	tick_tween.tween_method(
		func(t: float):
			elapsed = t
			var pos: Vector2 = start_pos + velocity * t + 0.5 * Vector2(0, explosion_gravity) * t * t
			frag.position = pos
			frag.rotation += spin * get_process_delta_time()
			if t > fade_delay:
				var fade_t: float = (t - fade_delay) / (explosion_duration - fade_delay)
				frag.modulate.a = clamp(1.0 - fade_t, 0.0, 1.0)
			,
		0.0, explosion_duration, explosion_duration
	)
	tick_tween.finished.connect(frag.queue_free)


## Repõe o ícone (ex: ao reiniciar o jogo / nova vida ganha).
func reset() -> void:
	_is_exploding = false
	idle_sprite.visible = true
	idle_sprite.modulate.a = 1.0
	idle_sprite.position = _base_position
	idle_sprite.scale = Vector2.ONE
	_start_idle_animation()
