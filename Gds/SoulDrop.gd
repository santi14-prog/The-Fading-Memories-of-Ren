extends Node
class_name SoulDrop
## Utilitário estático para instanciar Almas a partir de qualquer inimigo.
## Uso no script do inimigo, ao morrer:
##
##   func die():
##       SoulDrop.drop(soul_scene, global_position, 3)   # larga 3 Almas
##       queue_free()
 
static func drop(soul_scene: PackedScene, at_position: Vector2, amount: int = 1, container: Node = null, vertical_offset: float = -20.0) -> void:
	var target_parent: Node = container if container else (Engine.get_main_loop() as SceneTree).current_scene
	var spawn_position := at_position + Vector2(0, vertical_offset)
 
	for i in amount:
		var soul := soul_scene.instantiate()
		target_parent.add_child(soul)
 
		var scatter_dir := Vector2.ZERO
		if amount > 1:
			# distribui as Almas em leque, para cima (metade negativa do círculo),
			# com um pequeno jitter para não ficarem numa linha perfeita
			var angle: float = lerp(-PI * 0.85, -PI * 0.15, float(i) / float(amount - 1))
			angle += randf_range(-0.15, 0.15)
			scatter_dir = Vector2(cos(angle), sin(angle))
 
		soul.setup(spawn_position, scatter_dir)
