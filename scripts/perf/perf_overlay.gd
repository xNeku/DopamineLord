class_name PerfOverlay
extends CanvasLayer
## Panel de métricas. F3 (acción `debug_perf`) lo enseña y lo esconde. Con `--perf` en la línea de
## comandos, además escribe una línea cada 2 segundos en la consola (sirve en modo headless).
##
## Los tiempos de cada sección son por llamada: `mob_think` por frame de física, `proj_draw` por
## frame dibujado, etc. "máx" es el peor pico de la ventana de 1 segundo.

const WINDOW := 1.0

var mobs: MobManager
var projectiles: ProjectileManager

var _label: Label
var _timer: float = 0.0
var _print_timer: float = 0.0
var _text: String = ""
var _last_physics_frame: int = 0
## Tiempo de física de cada tick de la ventana (se muestrea en todos, no en uno al azar).
var _physics_sum: float = 0.0
var _physics_max: float = 0.0
var _physics_samples: int = 0
var _print_to_console: bool = false


## Dos nodos que rodean a todos los demás en el tick de física (el primero y el último): lo que
## hay entre los dos es el tiempo de los `_physics_process` de los scripts. El resto del tick es
## el motor (servidor de física, mensajes pendientes).
var _first := Node.new()
var _last := Node.new()
var _tick_start_usec: int = 0
var _scripts_sum: float = 0.0


func _ready() -> void:
	_first.process_physics_priority = -100000
	_last.process_physics_priority = 100000
	_first.set_script(preload("res://scripts/perf/tick_marker.gd"))
	_last.set_script(preload("res://scripts/perf/tick_marker.gd"))
	_first.callback = func() -> void: _tick_start_usec = Time.get_ticks_usec()
	_last.callback = func() -> void: _scripts_sum += (Time.get_ticks_usec() - _tick_start_usec) / 1000.0
	add_child(_first)
	add_child(_last)
	layer = 100
	_print_to_console = "--perf" in OS.get_cmdline_user_args()
	if _print_to_console:
		PerfProbe.enabled = true
	_label = Label.new()
	_label.position = Vector2(4, 70)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.visible = false
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_perf"):
		_label.visible = not _label.visible
		PerfProbe.enabled = _label.visible or _print_to_console
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not PerfProbe.enabled:
		return
	var spent := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_physics_sum += spent
	_physics_max = maxf(_physics_max, spent)
	_physics_samples += 1


func _process(delta: float) -> void:
	_timer += delta
	if _timer < WINDOW:
		return
	_timer = 0.0
	if not PerfProbe.enabled:
		return
	_text = _build_text()
	_label.text = _text
	_print_timer += WINDOW
	if _print_to_console and _print_timer >= 2.0:
		_print_timer = 0.0
		print("[perf] ", _text.replace("\n", " | "))


func _build_text() -> String:
	var lines := PackedStringArray()
	lines.append("FPS %d  física %.1f ms (pico %.1f)  proceso %.1f ms  draws %d  nodos %d" % [
		Engine.get_frames_per_second(),
		_physics_sum / maxi(_physics_samples, 1),
		_physics_max,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	])
	lines.append("de ese tiempo, scripts %.1f ms; motor %.1f ms" % [_scripts_sum / maxi(_physics_samples, 1), _physics_sum / maxi(_physics_samples, 1) - _scripts_sum / maxi(_physics_samples, 1)])
	lines.append("mobs %d  proyectiles %d  cuerpos físicos activos %d  pares %d" % [
		mobs.mob_count() if mobs else 0,
		projectiles.projectile_count() if projectiles else 0,
		int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
	])
	_physics_sum = 0.0
	_physics_max = 0.0
	_physics_samples = 0
	_scripts_sum = 0.0
	var sections := PerfProbe.take()
	var physics_ticks := maxi(1, Engine.get_physics_frames() - _last_physics_frame)
	_last_physics_frame = Engine.get_physics_frames()
	var names := sections.keys()
	names.sort()
	lines.append("sección       ms por tick de física   (pico)   llamadas por tick")
	for section in names:
		var info: Dictionary = sections[section]
		if String(section).ends_with("_draw"):
			# Dibujo: va por frame dibujado, no por tick; se enseña lo que cuesta cada vez.
			lines.append("%-12s %.2f ms por dibujado   (pico %.2f)" % [section, info["avg_ms"], info["max_ms"]])
		else:
			lines.append("%-12s %.2f   (pico %.2f)   x%.1f" % [section, info["total_ms"] / physics_ticks, info["max_ms"], float(info["calls"]) / physics_ticks])
	return "\n".join(lines)
