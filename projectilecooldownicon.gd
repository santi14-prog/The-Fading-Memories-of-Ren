extends Control

@onready var overlay: TextureRect = $CooldownOverlayProjectile

var cooldown_time: float = 0.0
var timer: float = 0.0
var active: bool = false

func _ready() -> void:
	overlay.visible = false

	var material: ShaderMaterial = overlay.material as ShaderMaterial
	if material:
		material.set_shader_parameter("progress", 0.0)

func start_cooldown(duration: float) -> void:
	cooldown_time = duration
	timer = duration
	active = true
	overlay.visible = true

	var material: ShaderMaterial = overlay.material as ShaderMaterial
	if material:
		material.set_shader_parameter("progress", 1.0)

func _process(delta: float) -> void:
	if !active:
		return

	timer -= delta

	if cooldown_time > 0.0:
		var progress: float = clamp(timer / cooldown_time, 0.0, 1.0)

		var material: ShaderMaterial = overlay.material as ShaderMaterial
		if material:
			material.set_shader_parameter("progress", progress)

	if timer <= 0.0:
		active = false
		overlay.visible = false

		var material: ShaderMaterial = overlay.material as ShaderMaterial
		if material:
			material.set_shader_parameter("progress", 0.0)
