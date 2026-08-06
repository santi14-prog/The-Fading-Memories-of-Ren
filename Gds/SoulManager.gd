extends Node

# --- Autoload / Singleton ---
# Godot: Projeto > Configurações do Projeto > Autoload > adiciona este script como "SoulManager"

signal souls_changed(total: int, delta: int)

var total_souls: int = 0


func add_souls(amount: int) -> void:
	if amount <= 0:
		return
	total_souls += amount
	souls_changed.emit(total_souls, amount)


func spend_souls(amount: int) -> bool:
	if amount <= 0 or amount > total_souls:
		return false
	total_souls -= amount
	souls_changed.emit(total_souls, -amount)
	return true


func can_afford(amount: int) -> bool:
	return total_souls >= amount
