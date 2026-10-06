class_name FloatingText
extends Node2D
## Números que suben y se desvanecen (daño hecho o recibido, curación). Un solo nodo por
## "padre" los dibuja todos, y hay un tope de números a la vez: con cientos de golpes por
## segundo no se crea un nodo por número.

const LIFETIME := 0.7
const RISE := 22.0
const MAX_ACTIVE := 80

var _items: Array[Dictionary] = []


## Escribe un número en `at` (coordenadas del mundo). `parent` es quien lo pide; el nodo que
## los dibuja se crea la primera vez.
static func spawn(parent: Node, at: Vector2, text: String, color: Color) -> void:
	var layer := parent.get_node_or_null("FloatingTexts") as FloatingText
	if layer == null:
		layer = FloatingText.new()
		layer.name = "FloatingTexts"
		layer.z_index = 100
		parent.add_child(layer)
	layer._add(at, text, color)


func _add(at: Vector2, text: String, color: Color) -> void:
	if _items.size() >= MAX_ACTIVE:
		_items.remove_at(0)
	_items.append({"position": at, "text": text, "color": color, "age": 0.0})
	set_process(true)


func _process(delta: float) -> void:
	var i := _items.size() - 1
	while i >= 0:
		_items[i]["age"] += delta
		if _items[i]["age"] >= LIFETIME:
			_items.remove_at(i)
		i -= 1
	queue_redraw()
	if _items.is_empty():
		set_process(false)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for item in _items:
		var t: float = item["age"] / LIFETIME
		var color: Color = item["color"]
		color.a = 1.0 - t
		var spot: Vector2 = item["position"] + Vector2(-8, -RISE * t)
		draw_string(font, spot, item["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
