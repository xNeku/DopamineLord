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
## Registro en archivo de las dos últimas partidas (ver `_open_log`).
const LOG_MAX_BYTES := 400000
var _log: FileAccess
var _log_bytes: int = 0
var _log_timer: float = 0.0
var _start_msec: int = 0
var _last_stats: Dictionary = {}
## Frames que han tardado demasiado (más de 40 ms) y el peor de la ventana de registro.
var _slow_frames: int = 0
var _worst_frame_ms: float = 0.0


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
	# Las sondas están siempre activas (cuestan muy poco) para que el registro tenga datos.
	PerfProbe.enabled = true
	_start_msec = Time.get_ticks_msec()
	if not "--no-log" in OS.get_cmdline_user_args():
		_open_log()
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
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not PerfProbe.enabled:
		return
	var spent := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_physics_sum += spent
	_physics_max = maxf(_physics_max, spent)
	_physics_samples += 1


func _process(delta: float) -> void:
	if delta > 0.04:
		_slow_frames += 1
	_worst_frame_ms = maxf(_worst_frame_ms, delta * 1000.0)
	_timer += delta
	if _timer < WINDOW:
		return
	_timer = 0.0
	_text = _build_text()
	_label.text = _text
	_log_timer += WINDOW
	if _log_timer >= 2.0:
		_log_timer = 0.0
		_write_log(_text)
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


## Abre `metricas/actual.log` (la partida de ahora) y deja la anterior en `metricas/anterior.log`.
## Así siempre quedan las dos últimas partidas, para poder mirarlas después. Si la carpeta del
## proyecto no se puede escribir (juego exportado), va a la carpeta de datos del usuario.
func _open_log() -> void:
	var folder := ProjectSettings.globalize_path("res://metricas")
	if DirAccess.make_dir_recursive_absolute(folder) != OK or not _can_write(folder):
		folder = ProjectSettings.globalize_path("user://metricas")
		DirAccess.make_dir_recursive_absolute(folder)
	if FileAccess.file_exists(folder + "/actual.log"):
		DirAccess.rename_absolute(folder + "/actual.log", folder + "/anterior.log")
	_log = FileAccess.open(folder + "/actual.log", FileAccess.WRITE)
	if _log == null:
		return
	var info := "%s | %s | %s | %s | ventana %s | motor %s" % [
		Time.get_datetime_string_from_system(), OS.get_name(), Engine.get_architecture_name(),
		RenderingServer.get_video_adapter_name(), get_window().size, ProjectSettings.get_setting("rendering/renderer/rendering_method")]
	_log.store_line("# DopamineLord, métricas. " + info)
	_log.store_line("# Una línea cada 2 s. fis = tiempo del tick de física, draws = llamadas de dibujo.")
	_log.store_line("# aparecidos_a_la_vista debería ser 0. proyectiles_alargados = proyectiles que habrían desaparecido sin
# dibujarse. frames_lentos = frames de más de 40 ms (acumulado en la ventana de 2 s).")


func _can_write(folder: String) -> bool:
	var probe := FileAccess.open(folder + "/.prueba", FileAccess.WRITE)
	if probe == null:
		return false
	probe.close()
	DirAccess.remove_absolute(folder + "/.prueba")
	return true


func _write_log(text: String) -> void:
	if _log == null or _log_bytes > LOG_MAX_BYTES:
		return
	var stats := {
		"aparecidos": mobs.stat_spawned if mobs else 0,
		"aparecidos_a_la_vista": mobs.stat_spawned_in_view if mobs else 0,
		"proyectiles_disparados": projectiles.stat_fired if projectiles else 0,
		"proyectiles_instantáneos": projectiles.stat_instant if projectiles else 0,
		"proyectiles_alargados": projectiles.stat_unseen if projectiles else 0,
		"frames_lentos": _slow_frames,
	}
	var extra := ""
	for key in stats:
		extra += "  %s=%d" % [key, stats[key] - int(_last_stats.get(key, 0))]
	_last_stats = stats
	extra += "  peor_frame=%.0fms" % _worst_frame_ms
	_worst_frame_ms = 0.0
	if projectiles:
		extra += "  dibujados=%d" % projectiles.stat_drawn
	var line := "t=%ds  %s%s" % [(Time.get_ticks_msec() - _start_msec) / 1000, text.replace("\n", " | "), extra]
	_log.store_line(line)
	_log.flush()
	_log_bytes += line.length() + 1
