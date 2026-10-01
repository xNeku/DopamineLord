extends Node2D
## Escena de prueba del personaje. El de abajo gira con las acciones de movimiento
## (teclado o mando); los cuatro de arriba enseñan las cuatro diagonales.

const FACINGS: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]

## Lista de personajes (nunca uno global), igual que será con varios jugadores.
var players: Array[Node] = []


func _ready() -> void:
	players.append($Jugador)
	for i in FACINGS.size():
		get_node("Fijo%d" % i).set_facing(FACINGS[i])


func _process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	for player: PlayerVisual in players:
		player.set_facing(direction)
