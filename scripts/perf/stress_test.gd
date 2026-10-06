class_name StressTest
extends Node
## Modo estrés para medir: mantiene N mobs y N proyectiles vivos a la vez, mueran o no.
## F4 (`debug_stress_mobs`) y F5 (`debug_stress_proj`) suben el objetivo por escalones.
## Por línea de comandos: `--stress-mobs=200 --stress-proj=200`.
## Solo hace algo en el host. Los proyectiles son de prueba (`debug_stress_bolt`).

const STEPS: Array[int] = [0, 100, 200, 400]
const BOLT := &"debug_stress_bolt"

var mobs: MobManager
var projectiles: ProjectileManager
var player: Player

var target_mobs: int = 0
var target_projectiles: int = 0

var _angle: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stress-mobs="):
			target_mobs = int(arg.get_slice("=", 1))
		elif arg.begins_with("--stress-proj="):
			target_projectiles = int(arg.get_slice("=", 1))
	_apply_limits()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_stress_mobs"):
		target_mobs = _next_step(target_mobs)
		print("[stress] mobs objetivo: ", target_mobs)
	elif event.is_action_pressed("debug_stress_proj"):
		target_projectiles = _next_step(target_projectiles)
		_apply_limits()
		print("[stress] proyectiles objetivo: ", target_projectiles)


func _next_step(current: int) -> int:
	var index := STEPS.find(current)
	return STEPS[(index + 1) % STEPS.size()]


func _apply_limits() -> void:
	if projectiles != null:
		projectiles.max_per_player = maxi(projectiles.max_per_player, target_projectiles)
		projectiles.max_total = maxi(projectiles.max_total, target_projectiles + 100)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or player == null:
		return
	var missing_mobs := target_mobs - mobs.mob_count()
	if missing_mobs > 0:
		mobs.debug_spawn(mini(missing_mobs, 40), player.position)
	var missing_projectiles := target_projectiles - projectiles.projectile_count()
	for i in clampi(missing_projectiles, 0, 40):
		_angle += 0.61803 * TAU
		projectiles.fire(multiplayer.get_unique_id(), BOLT, player.position + Vector2(0, -12), Vector2.from_angle(_angle), 0.05)
