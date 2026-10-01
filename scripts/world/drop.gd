class_name Drop
extends Node2D
## Algo en el suelo que se puede recoger. Solo guarda datos y se dibuja; el LootManager del
## host decide quién se lo queda.

var drop_id: int = 0
var kind: StringName = &"money"
var amount: int = 0
## Segundos que lleva en el suelo (solo lo cuenta el host).
var age: float = 0.0

var _phase: float = randf() * TAU


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var lift := sin(Time.get_ticks_msec() * 0.006 + _phase) * 1.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, -6 + lift), 4.0, Color(1.0, 0.82, 0.2))
	draw_arc(Vector2(0, -6 + lift), 4.0, 0.0, TAU, 12, Color(0.7, 0.5, 0.05), 1.0)
