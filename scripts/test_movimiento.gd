extends Node2D
## Escena de prueba de movimiento: una cuadrícula isométrica (tile 64×32) y un jugador
## que se mueve con las acciones del Input Map. La cámara lo sigue.

const TILE_HALF := Vector2(32, 16)
const GRID_SIZE := 12

@onready var _camera: Camera2D = $Camera2D

## Lista de jugadores (nunca uno global).
var players: Array[Player] = []


func _ready() -> void:
	players.append($Player)


func _process(_delta: float) -> void:
	_camera.position = players[0].position


func _draw() -> void:
	var color := Color(1, 1, 1, 0.12)
	for k in range(-GRID_SIZE, GRID_SIZE + 1):
		var along_u := k * Vector2(-TILE_HALF.x, TILE_HALF.y)
		draw_line(along_u + GRID_SIZE * -TILE_HALF, along_u + GRID_SIZE * TILE_HALF, color)
		var along_v := k * TILE_HALF
		draw_line(along_v + GRID_SIZE * Vector2(TILE_HALF.x, -TILE_HALF.y), along_v + GRID_SIZE * Vector2(-TILE_HALF.x, TILE_HALF.y), color)
