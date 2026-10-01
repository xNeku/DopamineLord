class_name BoomerangProjectile
extends Node2D
## La espada de Lanzada: gira mientras vuela y su área crece con cada enemigo golpeado.
## Solo se dibuja. En el host la mueve el SkillManager; en los clientes sigue lo que llega.

const SMOOTHING := 14.0

## Radio de golpeo actual, en el suelo plano.
var radius: float = 14.0

var _target_position: Vector2
var _smooth: bool = false
var _spin: float = 0.0


## `smooth` es true en los clientes, que reciben posiciones cada 0,1 s y las suavizan.
func set_state(new_position: Vector2, new_radius: float, smooth: bool) -> void:
	radius = new_radius
	_target_position = new_position
	_smooth = smooth
	if not smooth:
		position = new_position


func _process(delta: float) -> void:
	_spin += delta * 18.0
	if _smooth:
		position = position.lerp(_target_position, 1.0 - exp(-SMOOTHING * delta))
	queue_redraw()


func _draw() -> void:
	# Área de golpeo en el suelo.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.6, 0.2, 0.15))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(1.0, 0.7, 0.3, 0.6), 1.0)
	# La espada, girando en el aire.
	var length := 10.0 + radius * 0.8
	draw_set_transform(Vector2(0, -12), _spin, Vector2.ONE)
	var blade := PackedVector2Array([Vector2(-length, -2), Vector2(length, 0), Vector2(-length, 2)])
	draw_colored_polygon(blade, Color(0.85, 0.9, 1.0))
	draw_rect(Rect2(-3, -3, 6, 6), Color(0.6, 0.4, 0.2))
