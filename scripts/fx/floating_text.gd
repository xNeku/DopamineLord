class_name FloatingText
extends Node2D
## Número que sube y se desvanece (daño recibido o hecho).


static func spawn(parent: Node, at: Vector2, text: String, color: Color) -> void:
	var fx := FloatingText.new()
	fx.position = at
	fx.z_index = 100
	fx.set_meta("text", text)
	fx.set_meta("color", color)
	parent.add_child(fx)
	var tween := fx.create_tween().set_parallel(true)
	tween.tween_property(fx, "position:y", at.y - 22.0, 0.7)
	tween.tween_property(fx, "modulate:a", 0.0, 0.7)
	tween.finished.connect(fx.queue_free)


func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-8, 0), get_meta("text"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, get_meta("color"))
