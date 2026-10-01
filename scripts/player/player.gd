class_name Player
extends CharacterBody2D
## Un jugador. Aquí vive la lógica (posición, movimiento); lo visual está en PlayerVisual.
## No lee el input: recibe órdenes (set_move_order). Así, en red, las órdenes de un jugador
## remoto pueden llegar de otro sitio y esta clase no cambia.

## Velocidad en píxeles de pantalla por segundo (horizontalmente).
@export var move_speed: float = 90.0
## Proporción de la velocidad vertical respecto a la horizontal. 0.5 porque el tile es 64×32.
@export var iso_y_scale: float = 0.5

## Orden actual: dirección en pantalla, con longitud de 0 a 1.
var move_order: Vector2 = Vector2.ZERO

@onready var visual: PlayerVisual = $PlayerVisual


func set_move_order(direction: Vector2) -> void:
	move_order = direction.limit_length(1.0)


func _physics_process(_delta: float) -> void:
	var motion := move_order * move_speed
	motion.y *= iso_y_scale
	velocity = motion
	move_and_slide()

	visual.set_facing(move_order)
	visual.set_walking(move_order.length())
