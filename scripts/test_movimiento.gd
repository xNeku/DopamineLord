extends Node2D
## Escena de prueba de movimiento y salto: una cuadrícula isométrica (tile 64×32), un jugador
## y unos obstáculos. La pared (gris) bloquea el salto; los árboles (verdes) y el "mob" (rojo)
## se saltan por encima, pero no se puede aterrizar encima. La cámara sigue al jugador.

const TILE_HALF := Vector2(32, 16)
const GRID_SIZE := 12

@onready var _camera: Camera2D = $Camera2D
@onready var _hud: Label = $Hud/Estado

## Lista de jugadores (nunca uno global).
var players: Array[Player] = []


func _ready() -> void:
	players.append($Player)
	# Pared: capa 1 (mundo). Cuerpos: capa 2.
	_add_obstacle(Vector2(150, 0), Vector2(12, 70), 1, Color(0.55, 0.55, 0.6), false)
	_add_obstacle(Vector2(-80, 0), Vector2(16, 16), 2, Color(0.2, 0.55, 0.25), true)
	_add_obstacle(Vector2(-110, 12), Vector2(16, 16), 2, Color(0.2, 0.55, 0.25), true)
	_add_obstacle(Vector2(60, -50), Vector2(16, 16), 2, Color(0.2, 0.55, 0.25), true)
	_add_obstacle(Vector2(0, 60), Vector2(18, 18), 2, Color(0.75, 0.2, 0.2), true)


func _process(_delta: float) -> void:
	var player := players[0]
	_camera.position = player.position
	if player.is_jumping:
		_hud.text = "Salto: en el aire"
	elif player.jump_cooldown_left > 0.0:
		_hud.text = "Salto: recarga %.1f s" % player.jump_cooldown_left
	else:
		_hud.text = "Salto: listo"


func _draw() -> void:
	var color := Color(1, 1, 1, 0.12)
	for k in range(-GRID_SIZE, GRID_SIZE + 1):
		var along_u := k * Vector2(-TILE_HALF.x, TILE_HALF.y)
		draw_line(along_u + GRID_SIZE * -TILE_HALF, along_u + GRID_SIZE * TILE_HALF, color)
		var along_v := k * TILE_HALF
		draw_line(along_v + GRID_SIZE * Vector2(TILE_HALF.x, -TILE_HALF.y), along_v + GRID_SIZE * Vector2(-TILE_HALF.x, TILE_HALF.y), color)


## Obstáculo de prueba. `layer` es el número de capa (1 = mundo, 2 = cuerpos).
func _add_obstacle(pos: Vector2, size: Vector2, layer: int, color: Color, round_shape: bool) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1 << (layer - 1)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var polygon := Polygon2D.new()
	polygon.color = color
	if round_shape:
		var circle := CircleShape2D.new()
		circle.radius = size.x * 0.5
		shape.shape = circle
		var points := PackedVector2Array()
		for i in 16:
			points.append(Vector2.from_angle(TAU * i / 16.0) * circle.radius)
		polygon.polygon = points
	else:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
		var half := size * 0.5
		polygon.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	body.add_child(shape)
	body.add_child(polygon)
	add_child(body)
