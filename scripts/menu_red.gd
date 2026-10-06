extends Control
## Menú inicial: jugar solo, alojar una partida o unirse a la de un amigo.
## Se navega con foco (flechas, cruceta o stick) y se acepta con Enter o el botón A.
##
## Para pruebas con varias instancias, argumentos tras `--`:
##   --host          aloja y entra directamente
##   --join=IP       se une a esa IP y entra directamente
##   --bot           el jugador local lo lleva un bot
##   --class=ID      elige esa rama sin pasar por el selector (melee, rango, mago)

const WORLD_SCENE := "res://scenes/test_movimiento.tscn"
const CLASS_SCENE := "res://scenes/seleccion_clase.tscn"

var _forced_class: StringName = &""

@onready var _solo: Button = $Centro/Caja/Solo
@onready var _host: Button = $Centro/Caja/Alojar
@onready var _address: LineEdit = $Centro/Caja/Direccion
@onready var _join: Button = $Centro/Caja/Unirse
@onready var _status: Label = $Centro/Caja/Estado


func _ready() -> void:
	_solo.pressed.connect(_start_solo)
	_host.pressed.connect(_start_host)
	_join.pressed.connect(_start_join)
	Net.connected.connect(_enter_world)
	Net.connection_failed.connect(_on_connection_failed)
	_solo.grab_focus()
	_run_command_line.call_deferred()


func _run_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--bot":
			Net.bot_mode = true
		if argument.begins_with("--class="):
			_forced_class = StringName(argument.trim_prefix("--class="))
	if Net.bot_mode and _forced_class == &"":
		_forced_class = &"melee"
	for argument in OS.get_cmdline_user_args():
		if argument == "--host":
			_start_host()
			return
		if argument.begins_with("--join="):
			_address.text = argument.trim_prefix("--join=")
			_start_join()
			return


func _start_solo() -> void:
	_enter_world()


func _start_host() -> void:
	var error := Net.host()
	if error != OK:
		_status.text = "No se pudo alojar (error %d)" % error
		return
	_enter_world()


func _start_join() -> void:
	_status.text = "Conectando..."
	var error := Net.join(_address.text.strip_edges())
	if error != OK:
		_status.text = "Dirección no válida (error %d)" % error
		Net.leave()


func _on_connection_failed() -> void:
	_status.text = "No se pudo conectar"
	Net.leave()


## Con --class o --bot se salta el selector; si no, se elige la rama antes de entrar.
func _enter_world() -> void:
	if _forced_class != &"" and GameData.CLASS_IDS.has(_forced_class):
		Net.choose_class(_forced_class)
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		get_tree().change_scene_to_file(CLASS_SCENE)
