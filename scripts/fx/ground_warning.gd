class_name GroundWarning
extends Node2D
## Marca en el suelo que avisa de dónde va a caer algo (el salto del mob grande).

var radius: float = 50.0
var duration: float = 1.0
var _elapsed: float = 0.0


static func spawn(parent: Node, at: Vector2, area_radius: float, time: float) -> void:
	var warning := GroundWarning.new()
	warning.position = at
	warning.radius = area_radius
	warning.duration = time
	warning.z_index = -2
	parent.add_child(warning)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration + 0.15:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(1.0, 0.3, 0.2, 0.9), 2.0)
	draw_circle(Vector2.ZERO, radius * progress, Color(1.0, 0.25, 0.15, 0.25))
