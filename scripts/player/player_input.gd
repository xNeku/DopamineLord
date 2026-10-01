class_name PlayerInput
extends Node
## Convierte el input del jugador local en órdenes para su Player.
## Solo debe existir en el jugador que controla este dispositivo.

@onready var _player: Player = get_parent()


func _physics_process(_delta: float) -> void:
	_player.set_move_order(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
