class_name Projectile
extends Node2D
## Proyectil de un mob a distancia. Vuela en línea recta, igual en todas las máquinas: se
## manda una vez al disparar (origen y velocidad), no su posición. El host decide si da.

var velocity: Vector2 = Vector2.ZERO
var radius: float = 4.0
var damage: int = 5
var _left: float = 3.0


func setup(origin: Vector2, new_velocity: Vector2, new_radius: float, new_damage: int, lifetime: float) -> void:
	position = origin
	velocity = new_velocity
	radius = new_radius
	damage = new_damage
	_left = lifetime
	z_index = 40


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_left -= delta
	if _left <= 0.0:
		queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	draw_circle(Vector2(0, 14), radius, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, radius + 1.5, Color(1.0, 0.95, 0.5, 0.35))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.85, 0.2))
