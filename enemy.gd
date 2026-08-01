extends CharacterBody2D

const MAX_HEALTH = 50
const GRAVITY = 900.0

var health := MAX_HEALTH
var is_dead := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_fill: ColorRect = $HealthBarContainer/Fill
var fill_full_width: float


func _ready() -> void:
	fill_full_width = health_fill.size.x
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	move_and_slide()


func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	health = max(health, 0)
	_update_health_bar()

	if health <= 0:
		die()
	else:
		animated_sprite.play("hurt")


func _update_health_bar() -> void:
	var ratio: float = float(health) / float(MAX_HEALTH)
	health_fill.size.x = fill_full_width * ratio


func die() -> void:
	is_dead = true
	animated_sprite.play("death")


func _on_animation_finished() -> void:
	if animated_sprite.animation == "hurt":
		animated_sprite.play("idle")
	elif animated_sprite.animation == "death":
		queue_free()
