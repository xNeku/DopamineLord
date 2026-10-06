class_name PerfProbe
extends RefCounted
## Cronómetros baratos para medir el coste de cada parte del juego. Si no está activado
## (`enabled`), `begin` y `end` no hacen casi nada, así que se pueden dejar puestos en el código.
##
## Uso: PerfProbe.begin(&"mob_think") ... PerfProbe.end(&"mob_think")
## Cada sección guarda cuántas veces se ha llamado, el tiempo total y el peor caso (picos).

static var enabled: bool = false

static var _starts: Dictionary = {}
static var _total_usec: Dictionary = {}
static var _max_usec: Dictionary = {}
static var _calls: Dictionary = {}


static func begin(section: StringName) -> void:
	if enabled:
		_starts[section] = Time.get_ticks_usec()


static func end(section: StringName) -> void:
	if not enabled:
		return
	var spent := Time.get_ticks_usec() - int(_starts.get(section, 0))
	_total_usec[section] = int(_total_usec.get(section, 0)) + spent
	_calls[section] = int(_calls.get(section, 0)) + 1
	if spent > int(_max_usec.get(section, 0)):
		_max_usec[section] = spent


## Devuelve {sección: {avg_ms, max_ms, calls}} desde la última vez y lo pone a cero.
static func take() -> Dictionary:
	var result := {}
	for section in _total_usec:
		var calls: int = _calls[section]
		result[section] = {
			"avg_ms": _total_usec[section] / 1000.0 / maxi(calls, 1),
			"total_ms": _total_usec[section] / 1000.0,
			"max_ms": _max_usec.get(section, 0) / 1000.0,
			"calls": calls,
		}
	_total_usec.clear()
	_max_usec.clear()
	_calls.clear()
	return result
