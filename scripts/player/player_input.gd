class_name PlayerInput
extends Node
## Convierte el input del jugador local en órdenes para su Player.
## Solo debe existir en el jugador que controla este dispositivo.

## Con el stick derecho por debajo de esto se considera que no apunta.
const AIM_DEADZONE := 0.35

var _use_mouse: bool = true

@onready var _player: Player = get_parent()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey:
		_use_mouse = true
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_use_mouse = false


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_player.set_move_order(direction)
	if Input.is_action_just_pressed("jump"):
		_player.request_jump(direction)
	if Input.is_action_pressed("attack"):
		_player.request_attack(_aim_direction())


## Hacia dónde apunta: el stick derecho con mando, o el cursor con ratón. Si no hay nada,
## hacia donde mira. La dirección va en el suelo plano.
func _aim_direction() -> Vector2:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if not _use_mouse and stick.length() > AIM_DEADZONE:
		return stick
	if _use_mouse:
		var offset := _player.get_global_mouse_position() - _player.global_position
		if offset.length() > 4.0:
			return Iso.to_ground(offset).normalized()
	return _player.facing
