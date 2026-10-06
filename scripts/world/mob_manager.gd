class_name MobManager
extends Node
## Mobs y combate de la partida.
##
## Manda el host: él hace aparecer a los mobs, los mueve, resuelve los golpes y el daño. Los
## clientes reciben eventos (aparece, golpeado, muerto) y una foto de las posiciones unas
## 10 veces por segundo, que suavizan. Offline, el jugador es su propio host y todo funciona
## igual.

## Cada cuánto se reparte la vida que se ha juntado.
const HEAL_INTERVAL := 0.25
## Lado de las celdas de la rejilla espacial (suelo plano) y mayor radio de mob que se espera.
const GRID_CELL := 48.0
const MAX_MOB_RADIUS := 24.0
## Cuánto pueden solaparse dos mobs antes de empujarse (1 = nada, 0.85 = un poco, como una muchedumbre).
const SEPARATION := 0.85
## La separación se reparte en tantas fases (cada tick toca una parte de las celdas) y empuja a lo
## sumo MAX_PUSH píxeles por pasada.
const SEPARATION_PHASES := 3
const MAX_PUSH := 4.0
## Las celdas se numeran con un entero (más barato que un Vector2i como clave del diccionario).
const KEY_SPAN := 32768
const KEY_OFFSET := 16384
## Foto de posiciones para los clientes: zona que se manda (mitad, en pantalla; el doble de lo que
## se ve), tamaño de cada mob en el paquete y tope del paquete (bajo el MTU de 1392 bytes).
const SNAPSHOT_HALF := Vector2(660, 380)
const SNAPSHOT_HEADER := 8
const SNAPSHOT_MOB_BYTES := 10
const SNAPSHOT_MAX_BYTES := 1200
## Cada cuánto se mandan a los clientes los golpes y muertes juntos.
const EVENT_INTERVAL := 0.1

## Solo en el host: un mob ha muerto, con su tipo, su posición y quién lo mató.
signal mob_killed(kind: StringName, position: Vector2, killer_peer: int)
## Solo en el host: un jugador ha muerto.
signal player_died(peer_id: int)

## Qué mobs hacen aparecer, por su id. Cada uno trae su peso, tamaño de grupo y máximo.
@export var mob_table: Array[StringName] = [&"blob", &"archer", &"brute", &"elite"]
@export var max_mobs: int = 40
## Cada cuántos segundos llega un grupo nuevo, si no se ha llegado al máximo.
@export var spawn_interval: float = 2.5
## Mitad del tamaño de lo que se ve en pantalla, en píxeles. Los mobs aparecen más allá, fuera
## de la vista, y vienen hacia el jugador.
@export var spawn_view_half: Vector2 = Vector2(400, 260)
## Distancia (en el suelo plano) a la que un mob que se ha quedado atrás desaparece.
@export var despawn_distance: float = 900.0
@export var snapshot_interval: float = 0.1
@export var respawn_seconds: float = 3.0

## Todos los jugadores de la partida. Lo rellena el mundo.
var players: Array[Player] = []
var spawn_point: Vector2 = Vector2.ZERO
## Para las métricas: mobs que han aparecido dentro de la vista de algún jugador (no debería pasar).
var stat_spawned_in_view: int = 0
var stat_spawned: int = 0
## Contadores para las pruebas con bots.
var stats: Dictionary = {"hits": 0, "kills": 0, "damage_taken": 0}

var _mobs: Dictionary = {}
var _next_id: int = 1
var _spawn_timer: float = 0.0
var _despawn_timer: float = 0.0
var _projectiles: Dictionary = {}
var _snapshot_timer: float = 0.0
var _probe := CircleShape2D.new()
## Vida pendiente de curar por jugador (robo de vida y regeneración). Se junta y se manda en
## paquetes, no un mensaje por golpe.
var _heal_pool: Dictionary = {}
var _heal_timer: float = 0.0
## Rejilla espacial de los mobs: celda -> mobs. Se rehace cada frame, solo en el host.
var _grid: Dictionary = {}
## Obstáculos fijos (árboles, menas, paredes) en el suelo plano. Los mobs no son cuerpos físicos,
## así que chocan contra esto a mano. Círculos por celda de rejilla; rectángulos en una lista corta.
var _static_grid: Dictionary = {}
var _static_rects: Array[Rect2] = []
var _tick: int = 0
var _renderer: MobRenderer
## Cuántos mobs vivos hay de cada tipo (para respetar `max_alive` sin recorrerlos todos).
var _alive_by_kind: Dictionary = {}
## Golpes y muertes que se mandan a los clientes en un solo paquete.
var _pending_hits: Dictionary = {}
var _pending_deaths: PackedInt32Array = PackedInt32Array()
var _event_timer: float = 0.0
## Proyectiles de los jugadores. Lo rellena el mundo.
var projectiles: ProjectileManager


func _ready() -> void:
	_renderer = MobRenderer.new()
	_renderer.name = "MobRenderer"
	_renderer.mobs = _mobs
	_renderer.players = players
	add_child(_renderer)
	_probe.radius = 9.0
	if not multiplayer.is_server():
		_request_sync.rpc_id(1)


func mob_count() -> int:
	return _mobs.size()


func all_mobs() -> Array:
	return _mobs.values()


## Los mobs que tocan un círculo de `ground_radius` (en el suelo plano) alrededor de `center`
## (en pantalla). Usa la rejilla, así que cuesta lo mismo con 40 mobs que con 400.
func mobs_in_circle(center: Vector2, ground_radius: float) -> Array[Mob]:
	var ground_center := Iso.to_ground(center)
	var result: Array[Mob] = []
	for mob in mobs_near_ground(ground_center, ground_radius):
		if mob.ground_position.distance_to(ground_center) <= ground_radius + mob.data.radius:
			result.append(mob)
	return result


## Candidatos de la rejilla cerca de un punto del suelo plano. No comprueba la distancia exacta:
## quien llama debe hacerlo (es la parte barata de la consulta).
func mobs_near_ground(ground_center: Vector2, ground_radius: float) -> Array[Mob]:
	var result: Array[Mob] = []
	var reach := ground_radius + MAX_MOB_RADIUS
	var low_x := floori((ground_center.x - reach) / GRID_CELL)
	var low_y := floori((ground_center.y - reach) / GRID_CELL)
	var high_x := floori((ground_center.x + reach) / GRID_CELL)
	var high_y := floori((ground_center.y + reach) / GRID_CELL)
	for cx in range(low_x, high_x + 1):
		for cy in range(low_y, high_y + 1):
			var cell: Variant = _grid.get((cx + KEY_OFFSET) * KEY_SPAN + cy + KEY_OFFSET)
			if cell == null:
				continue
			for mob: Mob in cell:
				if not mob.dying:
					result.append(mob)
	return result


## Solo para pruebas de rendimiento: hace aparecer `count` mobs de golpe, igual que el reparto
## normal: siempre fuera de la vista, alrededor de un jugador.
func debug_spawn(count: int, anchor_position: Vector2) -> void:
	for i in count:
		var kind := _pick_kind()
		if kind == &"":
			return
		var spot := _offscreen_spot(anchor_position) + Iso.to_screen(Vector2.from_angle(randf() * TAU) * randf_range(0.0, 60.0))
		var id := _next_id
		_next_id += 1
		_note_spawn(spot)
		_spawn_mob.rpc(id, kind, spot)


## Un punto (en pantalla) justo fuera de la vista de quien está en `anchor_position`, en una
## dirección al azar. Los mobs nunca deben aparecer a la vista del jugador.
func _offscreen_spot(anchor_position: Vector2) -> Vector2:
	var direction := Vector2.from_angle(randf() * TAU)
	var out_x := spawn_view_half.x / maxf(absf(direction.x), 0.001)
	var out_y := spawn_view_half.y / maxf(absf(direction.y) * Iso.Y_SCALE, 0.001)
	return anchor_position + Iso.to_screen(direction * (minf(out_x, out_y) + randf_range(30.0, 90.0)))


func _rebuild_grid() -> void:
	_grid.clear()
	for mob: Mob in _mobs.values():
		var position := mob.position
		var ground := Vector2(position.x, position.y * 2.0)
		mob.ground_position = ground
		var key := (floori(ground.x / GRID_CELL) + KEY_OFFSET) * KEY_SPAN + floori(ground.y / GRID_CELL) + KEY_OFFSET
		var cell: Variant = _grid.get(key)
		if cell == null:
			_grid[key] = [mob]
		else:
			cell.append(mob)


## Obstáculo redondo fijo (un árbol, una mena). `screen_position` en pantalla; el radio en el suelo
## plano. Los mobs no lo atraviesan.
func add_obstacle_circle(screen_position: Vector2, radius: float) -> void:
	var center := Iso.to_ground(screen_position)
	var reach := radius + MAX_MOB_RADIUS
	for cx in range(floori((center.x - reach) / GRID_CELL), floori((center.x + reach) / GRID_CELL) + 1):
		for cy in range(floori((center.y - reach) / GRID_CELL), floori((center.y + reach) / GRID_CELL) + 1):
			var key := (cx + KEY_OFFSET) * KEY_SPAN + cy + KEY_OFFSET
			if not _static_grid.has(key):
				_static_grid[key] = []
			_static_grid[key].append(Vector3(center.x, center.y, radius))
	_renderer.sort_anchors.append(screen_position.y)


## Pared rectangular fija. `screen_center` y `screen_size` en pantalla. Se guarda como el
## rectángulo que la envuelve en el suelo plano. Pocas paredes: cada mob las recorre todas.
func add_obstacle_rect(screen_center: Vector2, screen_size: Vector2) -> void:
	var center := Iso.to_ground(screen_center)
	var size := Iso.to_ground(screen_size)
	_static_rects.append(Rect2(center - size * 0.5, size))
	_renderer.sort_anchors.append(screen_center.y)


## El jugador local ha atacado. Si somos el host se resuelve aquí; si no, se lo pedimos.
func request_attack(position: Vector2, direction: Vector2) -> void:
	if multiplayer.is_server():
		_resolve_attack(multiplayer.get_unique_id(), position, direction)
	else:
		_attack_request.rpc_id(1, position, direction)


func _physics_process(delta: float) -> void:
	PerfProbe.begin(&"mob_all")
	_physics_tick(delta)
	PerfProbe.end(&"mob_all")


func _physics_tick(delta: float) -> void:
	if not multiplayer.is_server():
		for mob: Mob in _mobs.values():
			mob.step(delta)
		return
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		if _mobs.size() < max_mobs:
			_try_spawn()
	_despawn_timer += delta
	if _despawn_timer >= 1.0:
		_despawn_timer = 0.0
		_despawn_far_mobs()
	PerfProbe.begin(&"mob_think")
	for mob: Mob in _mobs.values():
		if not mob.dying:
			_think(mob, delta)
	PerfProbe.end(&"mob_think")
	PerfProbe.begin(&"mob_move")
	_integrate(delta)
	PerfProbe.end(&"mob_move")
	PerfProbe.begin(&"mob_grid")
	_rebuild_grid()
	PerfProbe.end(&"mob_grid")
	PerfProbe.begin(&"mob_push")
	_separate()
	_finish_move()
	PerfProbe.end(&"mob_push")
	PerfProbe.begin(&"mob_shots")
	_check_projectiles()
	PerfProbe.end(&"mob_shots")
	_tick_healing(delta)
	PerfProbe.begin(&"mob_net")
	_event_timer += delta
	if _event_timer >= EVENT_INTERVAL:
		_event_timer = 0.0
		_flush_events()
	_snapshot_timer += delta
	if _snapshot_timer >= snapshot_interval:
		_snapshot_timer = 0.0
		_send_snapshot()
	PerfProbe.end(&"mob_net")


# --- Lógica del host -------------------------------------------------------------------

func _try_spawn() -> void:
	var alive: Array[Player] = []
	for player in players:
		if not player.is_dead:
			alive.append(player)
	if alive.is_empty():
		return
	var kind := _pick_kind()
	if kind == &"":
		return
	var data := GameData.mob(kind)
	var anchor: Player = alive.pick_random()
	# Fuera de la vista: el radio mínimo para que esté más allá del borde de la pantalla.
	var center := _offscreen_spot(anchor.position)
	var count := mini(randi_range(data.group_min, data.group_max), max_mobs - _mobs.size())
	if data.max_alive > 0:
		count = mini(count, data.max_alive - _alive_of(kind))
	for i in count:
		var spot := center + Iso.to_screen(Vector2.from_angle(randf() * TAU) * randf_range(0.0, 28.0))
		if _blocked(spot):
			continue
		var id := _next_id
		_next_id += 1
		_note_spawn(spot)
		_spawn_mob.rpc(id, kind, spot)


## Elige qué mob toca, según el peso de cada uno y respetando su máximo.
func _pick_kind() -> StringName:
	var total := 0.0
	for kind in mob_table:
		var data := GameData.mob(kind)
		if data.max_alive == 0 or _alive_of(kind) < data.max_alive:
			total += data.spawn_weight
	if total <= 0.0:
		return &""
	var roll := randf() * total
	for kind in mob_table:
		var data := GameData.mob(kind)
		if data.max_alive > 0 and _alive_of(kind) >= data.max_alive:
			continue
		roll -= data.spawn_weight
		if roll <= 0.0:
			return kind
	return mob_table[0]


func _alive_of(kind: StringName) -> int:
	return _alive_by_kind.get(kind, 0)


## Quita un mob de la lista y de los contadores. Devuelve false si ya no estaba.
func _forget_mob(id: int) -> bool:
	var mob: Mob = _mobs.get(id)
	if mob == null:
		return false
	_mobs.erase(id)
	_alive_by_kind[mob.data.id] = maxi(0, _alive_by_kind.get(mob.data.id, 1) - 1)
	return true


## Los mobs que se han quedado muy lejos de todos los jugadores desaparecen, para no
## acumular y que sigan llegando de nuevos.
func _despawn_far_mobs() -> void:
	for mob: Mob in _mobs.values().duplicate():
		var nearest := _nearest_player(mob.position)
		if nearest == null:
			continue
		if Iso.to_ground(nearest.position - mob.position).length() > despawn_distance:
			_mob_despawn.rpc(mob.mob_id)


func _blocked(spot: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _probe
	query.transform = Transform2D(0.0, spot)
	query.collision_mask = 3
	return not get_viewport().world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _think(mob: Mob, delta: float) -> void:
	if mob.is_leaping():
		return
	if mob.knock_left > 0.0:
		mob.knock_left -= delta
		mob.windup = false
		mob.velocity = mob.knock_velocity
		if mob.knock_left <= 0.0:
			_end_knock(mob)
		return
	var target := _nearest_player(mob.position)
	if target == null:
		mob.velocity = Vector2.ZERO
		mob.windup = false
		return
	var to_target := Iso.to_ground(target.position - mob.position)
	var distance := to_target.length()
	mob.leap_cooldown_left -= delta

	if mob.data.ai == MobData.Ai.RANGED:
		_think_ranged(mob, target, to_target, distance, delta)
	else:
		if mob.data.ai == MobData.Ai.LEAPER and _try_leap(mob, target, distance):
			return
		_think_melee(mob, target, to_target, distance, delta)

	if mob.slow_left > 0.0:
		mob.slow_left -= delta
		mob.velocity *= mob.slow_mult
		if mob.slow_left <= 0.0:
			mob.slow_mult = 1.0
	# Las skills pueden arrastrar al mob mientras hace otra cosa.
	mob.velocity += mob.pull_velocity


func _think_melee(mob: Mob, target: Player, to_target: Vector2, distance: float, delta: float) -> void:
	if mob.windup:
		mob.velocity = Vector2.ZERO
		mob.windup_left -= delta
		if mob.windup_left <= 0.0:
			mob.windup = false
			mob.attack_cooldown_left = mob.data.attack_cooldown
			# El golpe solo da si el jugador sigue cerca: se puede esquivar o saltar fuera.
			if distance <= mob.data.attack_range * 1.5:
				_damage_player(target, mob.data.damage)
	elif distance > mob.data.attack_range:
		mob.velocity = Iso.to_screen(to_target / distance * mob.data.move_speed)
	else:
		mob.velocity = Vector2.ZERO
		mob.attack_cooldown_left -= delta
		if mob.attack_cooldown_left <= 0.0:
			mob.windup = true
			mob.windup_left = mob.data.attack_windup


func _think_ranged(mob: Mob, target: Player, to_target: Vector2, distance: float, delta: float) -> void:
	mob.attack_cooldown_left -= delta
	if mob.windup:
		mob.velocity = Vector2.ZERO
		mob.windup_left -= delta
		if mob.windup_left <= 0.0:
			mob.windup = false
			mob.attack_cooldown_left = mob.data.attack_cooldown
			_fire_projectile(mob, target)
		return
	var heading := to_target / maxf(distance, 0.001)
	if distance > mob.data.preferred_distance + 15.0:
		mob.velocity = Iso.to_screen(heading * mob.data.move_speed)
	elif distance < mob.data.preferred_distance - 25.0:
		mob.velocity = Iso.to_screen(-heading * mob.data.move_speed)
	else:
		mob.velocity = Vector2.ZERO
	if mob.attack_cooldown_left <= 0.0 and distance <= mob.data.attack_range:
		mob.windup = true
		mob.windup_left = mob.data.attack_windup


func _fire_projectile(mob: Mob, target: Player) -> void:
	var heading := Iso.to_ground(target.position - mob.position).normalized()
	var velocity := Iso.to_screen(heading * mob.data.projectile_speed)
	var id := _next_id
	_next_id += 1
	_spawn_projectile.rpc(id, mob.position + Vector2(0, -8), velocity, mob.data.projectile_radius, mob.data.damage, mob.data.projectile_lifetime)


## Mueve a cada mob según la velocidad que le ha puesto su IA. Sin física: solo suma.
func _integrate(delta: float) -> void:
	for mob: Mob in _mobs.values():
		if mob.is_leaping():
			mob.step(delta)
		elif not mob.dying and mob.velocity != Vector2.ZERO:
			mob.position += mob.velocity * delta


## Separa a los mobs que se solapan, usando la rejilla. Cada pareja se mira una sola vez (misma
## celda, o la celda de la derecha y las tres de abajo) y solo una de cada SEPARATION_PHASES celdas
## por tick: es un ajuste suave, no hace falta cada frame. Los pesados empujan a los ligeros.
func _separate() -> void:
	const AHEAD: Array[int] = [KEY_SPAN, KEY_SPAN * -1 + 1, 1, KEY_SPAN + 1]
	_tick += 1
	for key: int in _grid:
		if (key + _tick) % SEPARATION_PHASES != 0:
			continue
		var cell: Array = _grid[key]
		var count := cell.size()
		for i in count:
			var a: Mob = cell[i]
			var ax := a.ground_position.x
			var ay := a.ground_position.y
			var ar := a.sep_radius
			for j in range(i + 1, count):
				var b: Mob = cell[j]
				var dx := ax - b.ground_position.x
				var dy := ay - b.ground_position.y
				var reach := ar + b.sep_radius
				if dx * dx + dy * dy < reach * reach:
					_resolve_overlap(a, b, dx, dy, reach)
					ax = a.ground_position.x
					ay = a.ground_position.y
			for step in AHEAD:
				var other: Variant = _grid.get(key + step)
				if other == null:
					continue
				for b: Mob in other:
					var dx := ax - b.ground_position.x
					var dy := ay - b.ground_position.y
					var reach := ar + b.sep_radius
					if dx * dx + dy * dy < reach * reach:
						_resolve_overlap(a, b, dx, dy, reach)
						ax = a.ground_position.x
						ay = a.ground_position.y


## Aparta a dos mobs que se solapan. El empujón por tick está limitado: si salen apilados
## (un grupo recién aparecido) se abren poco a poco, sin saltos.
func _resolve_overlap(a: Mob, b: Mob, dx: float, dy: float, reach: float) -> void:
	if a.is_leaping() or b.is_leaping():
		return
	var distance := sqrt(dx * dx + dy * dy)
	if distance < 0.01:
		dx = randf() - 0.5
		dy = randf() - 0.5
		distance = sqrt(dx * dx + dy * dy) + 0.0001
	var overlap := minf(reach - distance, MAX_PUSH)
	# Reparto del empujón según el tamaño; un mob empujado (knockback) no cede.
	var share_a := b.radius / (a.radius + b.radius)
	if a.knock_left > 0.0:
		share_a = 0.0
	elif b.knock_left > 0.0:
		share_a = 1.0
	var nx := dx / distance
	var ny := dy / distance
	var pa := a.ground_position
	var pb := b.ground_position
	a.ground_position = Vector2(pa.x + nx * overlap * share_a, pa.y + ny * overlap * share_a)
	b.ground_position = Vector2(pb.x - nx * overlap * (1.0 - share_a), pb.y - ny * overlap * (1.0 - share_a))
	a.pushed = true
	b.pushed = true


## Choca a los mobs con los obstáculos fijos y escribe la posición final de los que se han movido.
func _finish_move() -> void:
	var has_static := not _static_grid.is_empty() or not _static_rects.is_empty()
	for mob: Mob in _mobs.values():
		if mob.dying:
			continue
		if has_static and not mob.is_leaping():
			_collide_static(mob)
		if mob.pushed:
			mob.pushed = false
			mob.position = Vector2(mob.ground_position.x, mob.ground_position.y * Iso.Y_SCALE)


func _collide_static(mob: Mob) -> void:
	var g := mob.ground_position
	var radius := mob.data.radius
	var cell: Variant = _static_grid.get((floori(g.x / GRID_CELL) + KEY_OFFSET) * KEY_SPAN + floori(g.y / GRID_CELL) + KEY_OFFSET)
	if cell != null:
		for obstacle: Vector3 in cell:
			var dx := g.x - obstacle.x
			var dy := g.y - obstacle.y
			var min_distance := obstacle.z + radius
			var d2 := dx * dx + dy * dy
			if d2 < min_distance * min_distance:
				var distance := sqrt(d2)
				if distance < 0.01:
					g.x += min_distance
				else:
					g.x = obstacle.x + dx / distance * min_distance
					g.y = obstacle.y + dy / distance * min_distance
				mob.pushed = true
	for rect in _static_rects:
		var grown := rect.grow(radius)
		if not grown.has_point(g):
			continue
		var left := g.x - grown.position.x
		var right := grown.end.x - g.x
		var top := g.y - grown.position.y
		var bottom := grown.end.y - g.y
		var nearest := minf(minf(left, right), minf(top, bottom))
		if nearest == left:
			g.x = grown.position.x
		elif nearest == right:
			g.x = grown.end.x
		elif nearest == top:
			g.y = grown.position.y
		else:
			g.y = grown.end.y
		mob.pushed = true
	if mob.pushed:
		mob.ground_position = g


## Si toca, el mob grande avisa y salta sobre el jugador. Devuelve true si empieza el salto.
func _try_leap(mob: Mob, target: Player, distance: float) -> bool:
	var data := mob.data
	if mob.leap_cooldown_left > 0.0 or mob.windup:
		return false
	if distance < data.leap_min_distance or distance > data.leap_max_distance:
		return false
	mob.leap_cooldown_left = data.leap_cooldown
	mob.velocity = Vector2.ZERO
	_mob_leap.rpc(mob.mob_id, mob.position, target.position, data.leap_windup, data.leap_duration)
	return true


## El mob grande ha aterrizado: daña a los jugadores del área y los lanza hacia fuera.
func _on_leap_landed(mob: Mob) -> void:
	var data := mob.data
	for player in players:
		if player.is_dead:
			continue
		var offset := Iso.to_ground(player.position - mob.position)
		if offset.length() > data.leap_radius + 8.0:
			continue
		_damage_player(player, data.leap_damage)
		var away := offset if offset.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		var kick := away.normalized() * (data.leap_radius + 18.0) - offset
		_player_knockback.rpc(player.peer_id, kick)


func _check_projectiles() -> void:
	for id in _projectiles.keys():
		var raw: Variant = _projectiles[id]
		if not is_instance_valid(raw):
			_projectiles.erase(id)
			continue
		var node: Projectile = raw
		if _blocked_by_wall(node.position):
			_projectile_end.rpc(id)
			continue
		for player in players:
			if player.is_dead:
				continue
			if Iso.to_ground(player.position - node.position + Vector2(0, -8)).length() <= node.radius + 8.0:
				_damage_player(player, node.damage)
				_projectile_end.rpc(id)
				break


func _blocked_by_wall(spot: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = spot
	query.collision_mask = 1
	return not get_viewport().world_2d.direct_space_state.intersect_point(query, 1).is_empty()


func _nearest_player(from: Vector2) -> Player:
	var best: Player = null
	var best_distance := INF
	for player in players:
		if player.is_dead:
			continue
		var distance := from.distance_squared_to(player.position)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


## Manda a cada cliente solo los mobs que tiene cerca (el doble de lo que se ve), en paquetes que
## caben en un datagrama. Por mob: id (4 bytes), posición relativa al jugador en cuartos de
## píxel (2 + 2), vida en 0..255 y bit de aviso de golpe (1 + 1) = 10 bytes.
func _send_snapshot() -> void:
	PerfProbe.begin(&"mob_snap")
	for peer_id in multiplayer.get_peers():
		var viewer := _player_by_peer(peer_id)
		if viewer == null:
			continue
		var origin := viewer.position
		var low := origin - SNAPSHOT_HALF
		var high := origin + SNAPSHOT_HALF
		var packet := PackedByteArray()
		var used := SNAPSHOT_HEADER
		packet.resize(SNAPSHOT_MAX_BYTES)
		packet.encode_s32(0, roundi(origin.x))
		packet.encode_s32(4, roundi(origin.y))
		for mob: Mob in _mobs.values():
			var position := mob.position
			if position.x < low.x or position.x > high.x or position.y < low.y or position.y > high.y:
				continue
			packet.encode_s32(used, mob.mob_id)
			packet.encode_s16(used + 4, roundi((position.x - roundi(origin.x)) * 4.0))
			packet.encode_s16(used + 6, roundi((position.y - roundi(origin.y)) * 4.0))
			packet.encode_u8(used + 8, clampi(roundi(255.0 * mob.health / mob.data.max_health), 0, 255))
			packet.encode_u8(used + 9, 1 if mob.windup else 0)
			used += SNAPSHOT_MOB_BYTES
			if used + SNAPSHOT_MOB_BYTES > SNAPSHOT_MAX_BYTES:
				packet.resize(used)
				_snapshot.rpc_id(peer_id, packet)
				packet = PackedByteArray()
				packet.resize(SNAPSHOT_MAX_BYTES)
				packet.encode_s32(0, roundi(origin.x))
				packet.encode_s32(4, roundi(origin.y))
				used = SNAPSHOT_HEADER
		if used > SNAPSHOT_HEADER:
			packet.resize(used)
			_snapshot.rpc_id(peer_id, packet)
	PerfProbe.end(&"mob_snap")


func _resolve_attack(peer_id: int, position: Vector2, direction: Vector2) -> void:
	var attacker := _player_by_peer(peer_id)
	if attacker == null or attacker.is_dead:
		return
	var aim := Iso.to_ground(direction) if direction.length_squared() > 0.0 else Vector2.RIGHT
	aim = aim.normalized()
	if attacker.basic_projectile_id() != &"":
		if projectiles != null:
			projectiles.fire(peer_id, attacker.basic_projectile_id(), position, aim)
		return
	var half_arc := deg_to_rad(attacker.attack_arc_degrees) * 0.5
	for mob in mobs_near_ground(Iso.to_ground(position), attacker.effective_attack_range()):
		var offset := Iso.to_ground(mob.position - position)
		var reach := attacker.effective_attack_range() + mob.data.radius
		if offset.length() > reach:
			continue
		if offset.length() > mob.data.radius and absf(aim.angle_to(offset)) > half_arc:
			continue
		hit_mob(mob, attacker.attack_damage, peer_id)


## Hace daño a un mob (solo el host). Lo usan el ataque básico, las skills y los proyectiles.
## Devuelve true si lo mata.
## El mob se actualiza al instante en el host; los clientes reciben los golpes y muertes
## juntos cada EVENT_INTERVAL, no uno por golpe.
func hit_mob(mob: Mob, damage: int, attacker_peer: int, is_crit: bool = false) -> bool:
	if mob.dying:
		return false
	var attacker := _player_by_peer(attacker_peer)
	if attacker != null and attacker.life_steal > 0.0:
		# Robo de vida sobre el daño real, sin contar lo que sobra al rematar.
		_heal_pool[attacker_peer] = _heal_pool.get(attacker_peer, 0.0) + minf(damage, mob.health) * attacker.life_steal
	mob.health = maxi(mob.health - damage, 0)
	mob.flash()
	stats["hits"] += 1
	var entry: Array = _pending_hits.get(mob.mob_id, [0, 0, mob.position, false])
	entry[0] += damage
	entry[1] = mob.health
	entry[2] = mob.position
	entry[3] = entry[3] or is_crit
	_pending_hits[mob.mob_id] = entry
	if mob.health > 0:
		return false
	mob.dying = true
	_renderer.add_ghost(mob)
	_forget_mob(mob.mob_id)
	_pending_deaths.append(mob.mob_id)
	stats["kills"] += 1
	mob_killed.emit(mob.data.id, mob.position, attacker_peer)
	return true


## Manda a los clientes los golpes y las muertes acumulados, en un solo mensaje cada uno.
func _flush_events() -> void:
	if _pending_hits.is_empty() and _pending_deaths.is_empty():
		return
	var ids := PackedInt32Array()
	var damages := PackedInt32Array()
	var remainings := PackedInt32Array()
	var positions := PackedVector2Array()
	var crits := PackedByteArray()
	for id in _pending_hits:
		var entry: Array = _pending_hits[id]
		ids.append(id)
		damages.append(entry[0])
		remainings.append(entry[1])
		positions.append(entry[2])
		crits.append(1 if entry[3] else 0)
	var deaths := _pending_deaths
	_pending_hits = {}
	_pending_deaths = PackedInt32Array()
	if multiplayer.get_peers().is_empty():
		_mob_events(ids, damages, remainings, positions, crits, deaths)
	else:
		_mob_events.rpc(ids, damages, remainings, positions, crits, deaths)


## Ralentiza a un mob (solo el host). Se queda con la lentitud más fuerte.
func slow_mob(mob: Mob, mult: float, seconds: float) -> void:
	if mob.slow_left <= 0.0 or mult <= mob.slow_mult:
		mob.slow_mult = mult
	mob.slow_left = maxf(mob.slow_left, seconds)


## Empuja a un mob `ground_offset` (suelo plano) en `duration` segundos. Los pesados se mueven
## menos. Si el empujón acaba fuera de la vista de `crit_peer`, recibe `crit_damage` de crítico.
func knock_mob(mob: Mob, ground_offset: Vector2, duration: float, crit_damage: int = 0, crit_peer: int = 0) -> void:
	var factor := 1.0 - mob.data.knockback_resist
	if mob.dying or mob.is_leaping() or factor <= 0.0 or duration <= 0.0:
		return
	mob.knock_velocity = Iso.to_screen(ground_offset * factor) / duration
	mob.knock_left = duration
	mob.windup = false
	if crit_damage > mob.knock_crit_damage:
		mob.knock_crit_damage = crit_damage
		mob.knock_crit_peer = crit_peer


func _end_knock(mob: Mob) -> void:
	var damage := mob.knock_crit_damage
	var peer := mob.knock_crit_peer
	mob.knock_crit_damage = 0
	mob.knock_crit_peer = 0
	if damage <= 0:
		return
	var player := _player_by_peer(peer)
	if player != null and not ViewRange.contains(player.position, mob.position):
		hit_mob(mob, damage, peer, true)


## Junta la regeneración y reparte la vida pendiente cada HEAL_INTERVAL. Solo el host.
func _tick_healing(delta: float) -> void:
	for player in players:
		if player.health_regen > 0.0 and not player.is_dead:
			_heal_pool[player.peer_id] = _heal_pool.get(player.peer_id, 0.0) + player.health_regen * delta
	_heal_timer += delta
	if _heal_timer < HEAL_INTERVAL:
		return
	_heal_timer = 0.0
	for peer_id in _heal_pool.keys():
		var player := _player_by_peer(peer_id)
		if player == null or player.is_dead:
			_heal_pool.erase(peer_id)
			continue
		var whole := int(_heal_pool[peer_id])
		if whole < 1:
			continue
		var healed := mini(whole, player.max_health - player.health)
		_heal_pool[peer_id] -= whole
		if healed > 0:
			_player_health.rpc(peer_id, player.health + healed, -healed)


func _damage_player(target: Player, amount: int) -> void:
	var remaining := maxi(target.health - amount, 0)
	stats["damage_taken"] += amount
	_player_health.rpc(target.peer_id, remaining, amount)
	if remaining <= 0:
		_player_died.rpc(target.peer_id)
		player_died.emit(target.peer_id)
		var peer_id := target.peer_id
		get_tree().create_timer(respawn_seconds).timeout.connect(
			func() -> void: _player_respawn.rpc(peer_id, spawn_point)
		)


func _player_by_peer(peer_id: int) -> Player:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null


# --- Mensajes: del host a todos --------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _spawn_mob(id: int, mob_id: StringName, spot: Vector2) -> void:
	_create_mob(id, mob_id, spot, -1)


@rpc("authority", "unreliable_ordered")
func _snapshot(packet: PackedByteArray) -> void:
	var origin := Vector2(packet.decode_s32(0), packet.decode_s32(4))
	var at := SNAPSHOT_HEADER
	while at + SNAPSHOT_MOB_BYTES <= packet.size():
		var mob: Mob = _mobs.get(packet.decode_s32(at))
		if mob != null:
			var position := origin + Vector2(packet.decode_s16(at + 4), packet.decode_s16(at + 6)) * 0.25
			var health := roundi(packet.decode_u8(at + 8) * mob.data.max_health / 255.0)
			mob.apply_snapshot(position, health, packet.decode_u8(at + 9))
		at += SNAPSHOT_MOB_BYTES


## Golpes y muertes de los últimos EVENT_INTERVAL segundos, juntos. En el host el mob ya está
## actualizado: aquí solo se enseñan los números. Los clientes ponen la vida y quitan los muertos.
@rpc("authority", "call_local", "reliable")
func _mob_events(ids: PackedInt32Array, damages: PackedInt32Array, remainings: PackedInt32Array, positions: PackedVector2Array, crits: PackedByteArray, deaths: PackedInt32Array) -> void:
	var is_host := multiplayer.is_server()
	for i in ids.size():
		var mob: Mob = _mobs.get(ids[i])
		var at := positions[i]
		if mob != null:
			if not is_host:
				mob.set_health(remainings[i])
				mob.flash()
			at = mob.position
		if crits[i] != 0:
			FloatingText.spawn(self, at + Vector2(0, -30), "%d!" % damages[i], Color(1.0, 0.45, 0.15))
		else:
			FloatingText.spawn(self, at + Vector2(0, -26), str(damages[i]), Color(1.0, 0.9, 0.4))
	if is_host:
		return
	for id in deaths:
		var dead: Mob = _mobs.get(id)
		if dead != null:
			_renderer.add_ghost(dead)
			_forget_mob(id)


@rpc("authority", "call_local", "reliable")
func _player_health(peer_id: int, health: int, damage: int) -> void:
	var player := _player_by_peer(peer_id)
	if player == null:
		return
	player.set_health(health)
	if damage > 0:
		FloatingText.spawn(self, player.position + Vector2(0, -60), str(damage), Color(1.0, 0.35, 0.35))
	elif damage <= -3:
		FloatingText.spawn(self, player.position + Vector2(0, -60), "+%d" % -damage, Color(0.4, 1.0, 0.5))


@rpc("authority", "call_local", "reliable")
func _player_died(peer_id: int) -> void:
	var player := _player_by_peer(peer_id)
	if player != null:
		player.die()


@rpc("authority", "call_local", "reliable")
func _player_respawn(peer_id: int, spot: Vector2) -> void:
	var player := _player_by_peer(peer_id)
	if player != null:
		player.respawn(spot)


@rpc("authority", "call_local", "reliable")
func _mob_leap(id: int, from: Vector2, to: Vector2, windup_time: float, duration: float) -> void:
	var mob: Mob = _mobs.get(id)
	if mob == null:
		return
	mob.start_leap(from, to, windup_time, duration)
	GroundWarning.spawn(self, to, mob.data.leap_radius, windup_time + duration)


@rpc("authority", "call_local", "reliable")
func _mob_despawn(id: int) -> void:
	var mob: Mob = _mobs.get(id)
	if mob != null:
		_forget_mob(id)


@rpc("authority", "call_local", "reliable")
func _spawn_projectile(id: int, origin: Vector2, velocity: Vector2, radius: float, damage: int, lifetime: float) -> void:
	var projectile := Projectile.new()
	projectile.setup(origin, velocity, radius, damage, lifetime)
	add_child(projectile)
	_projectiles[id] = projectile


@rpc("authority", "call_local", "reliable")
func _projectile_end(id: int) -> void:
	var raw: Variant = _projectiles.get(id)
	_projectiles.erase(id)
	if is_instance_valid(raw):
		raw.queue_free()


## Un golpe fuerte te lanza. Lo aplica el dueño del jugador; en los demás se ve por su
## movimiento normal.
@rpc("authority", "call_local", "reliable")
func _player_knockback(peer_id: int, ground_offset: Vector2) -> void:
	var player := _player_by_peer(peer_id)
	if player != null and not player.is_remote:
		player.apply_knockback(ground_offset)


# --- Mensajes: de un cliente al host ---------------------------------------------------

@rpc("any_peer", "reliable")
func _attack_request(position: Vector2, direction: Vector2) -> void:
	if multiplayer.is_server():
		_resolve_attack(multiplayer.get_remote_sender_id(), position, direction)


## Un cliente acaba de entrar al mundo y pide lo que ya existe.
@rpc("any_peer", "reliable")
func _request_sync() -> void:
	if not multiplayer.is_server():
		return
	var ids := PackedInt32Array()
	var kinds := PackedStringArray()
	var positions := PackedVector2Array()
	var healths := PackedInt32Array()
	for mob: Mob in _mobs.values():
		ids.append(mob.mob_id)
		kinds.append(String(mob.data.id))
		positions.append(mob.position)
		healths.append(mob.health)
	var peer_ids := PackedInt32Array()
	var player_healths := PackedInt32Array()
	for player in players:
		peer_ids.append(player.peer_id)
		player_healths.append(player.health)
	_sync.rpc_id(multiplayer.get_remote_sender_id(), ids, kinds, positions, healths, peer_ids, player_healths)


@rpc("authority", "reliable")
func _sync(ids: PackedInt32Array, kinds: PackedStringArray, positions: PackedVector2Array, healths: PackedInt32Array, peer_ids: PackedInt32Array, player_healths: PackedInt32Array) -> void:
	for i in ids.size():
		if not _mobs.has(ids[i]):
			_create_mob(ids[i], StringName(kinds[i]), positions[i], healths[i])
	for i in peer_ids.size():
		var player := _player_by_peer(peer_ids[i])
		if player != null:
			player.set_health(player_healths[i])


## Cuenta para las métricas si un mob aparece a la vista de algún jugador.
func _note_spawn(spot: Vector2) -> void:
	stat_spawned += 1
	for player in players:
		if ViewRange.contains(player.position, spot):
			stat_spawned_in_view += 1
			return


func _create_mob(id: int, kind: StringName, spot: Vector2, health: int) -> void:
	if _mobs.has(id):
		return
	var mob := Mob.new()
	mob.position = spot
	var data := GameData.mob(kind)
	mob.setup(id, data, not multiplayer.is_server())
	mob.kind = _renderer.kind_of(data)
	if health >= 0:
		mob.health = health
	_mobs[id] = mob
	_alive_by_kind[kind] = _alive_by_kind.get(kind, 0) + 1
	if multiplayer.is_server():
		mob.leap_landed.connect(_on_leap_landed)
