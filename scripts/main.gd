extends Node2D
## Escena de prueba del andamiaje: muestra la versión de Godot y qué acciones
## del Input Map están pulsadas, para comprobar teclado, ratón y mando.

const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"jump", "attack", "interact",
	"skill_1", "skill_2", "skill_3", "skill_4",
]

@onready var label: Label = $Label


func _process(_delta: float) -> void:
	var pressed := PackedStringArray()
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			pressed.append(action)
	label.text = "DopamineLord\nGodot %s\nAcciones: %s" % [
		Engine.get_version_info()["string"],
		", ".join(pressed),
	]
