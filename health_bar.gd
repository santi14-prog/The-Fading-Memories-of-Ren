extends Control

# Ajusta este caminho ao node real do Ren, ex: "../../Ren"
@export var player_path: NodePath
@export var gradient: Gradient

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var trail_bar: ProgressBar = $TrailFill
@onready var hit_particles: CPUParticles2D = $"../CPUParticles2D"
@onready var mask_icons: Array[MaskIcon] = [
	$"../MaskIcons/MaskIcon",
	$"../MaskIcons/MaskIcon2",
	$"../MaskIcons/MaskIcon3",
	$"../MaskIcons/MaskIcon4",
	$"../MaskIcons/MaskIcon5"
]

var max_health: int = 100
var current_health: int = 100
var _exploded_count: int = 0


func _ready() -> void:
	var player := get_node(player_path)
	if player:
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.current_health, player.MAX_HEALTH)

	# garante que o trail arranca sincronizado, sem animar na primeira carga
	trail_bar.max_value = progress_bar.max_value
	trail_bar.value = progress_bar.value


func _on_health_changed(new_health: int, max_hp: int) -> void:
	var took_damage := new_health < current_health
	current_health = new_health
	max_health = max_hp

	progress_bar.max_value = max_hp
	progress_bar.value = new_health
	trail_bar.max_value = max_hp

	update_fill_color(float(new_health) / float(max_hp))

	# o trail demora a "apanhar" o valor real, dando o efeito de dano
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(trail_bar, "value", float(new_health), 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if took_damage:
		flash_damage()

	_update_mask_icons(took_damage)


func update_fill_color(ratio: float) -> void:
	if not gradient:
		return
	var sb := progress_bar.get_theme_stylebox("fill")
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).bg_color = gradient.sample(ratio)


func flash_damage() -> void:
	if hit_particles:
		hit_particles.restart()
		hit_particles.emitting = true

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.05, 1.1), 0.06)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_ELASTIC)


func _update_mask_icons(took_damage: bool) -> void:
	if not took_damage:
		return
	if _exploded_count >= mask_icons.size():
		return

	mask_icons[_exploded_count].explode()
	_exploded_count += 1
