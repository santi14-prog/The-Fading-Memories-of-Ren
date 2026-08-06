extends Label

# Anexa a um nó Label no teu HUD.
# Liga-se ao SoulManager (autoload) e atualiza o texto sempre que o total muda.

func _ready() -> void:
	SoulManager.souls_changed.connect(_on_souls_changed)
	_update_text(SoulManager.total_souls)


func _on_souls_changed(total: int, delta: int) -> void:
	_update_text(total)
	if delta > 0:
		_pulse()


func _update_text(total: int) -> void:
	text = "%d Almas" % total


func _pulse() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)
