extends Control
## Selector de rama al entrar en la partida. Se navega con foco (flechas, cruceta o stick) y se
## acepta con Enter o el botón A; Esc o B vuelve al menú. Los botones se crean aquí, así que la
## escena solo tiene la raíz.

const MENU_SCENE := "res://scenes/menu_red.tscn"
const WORLD_SCENE := "res://scenes/test_movimiento.tscn"

var _description: Label


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)

	var title := Label.new()
	title.text = "Elige tu rama"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var first: Button
	for class_id in GameData.CLASS_IDS:
		var data := GameData.char_class(class_id)
		var button := Button.new()
		button.text = data.display_name if data.playable else "%s (próximamente)" % data.display_name
		button.disabled = not data.playable
		button.add_theme_color_override("font_color", data.color)
		button.focus_entered.connect(_show_description.bind(data))
		button.mouse_entered.connect(_show_description.bind(data))
		button.pressed.connect(_choose.bind(class_id))
		box.add_child(button)
		if first == null and data.playable:
			first = button

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(300, 48)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_description)

	Net.disconnected.connect(_back)
	if first != null:
		first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _show_description(data: ClassData) -> void:
	_description.text = data.description


func _choose(class_id: StringName) -> void:
	Net.choose_class(class_id)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _back() -> void:
	Net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)
