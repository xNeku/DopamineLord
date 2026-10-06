class_name ProjectileManager
extends Node2D
## Proyectiles de los jugadores (flechas, bolas de magia...). Pensado para cientos a la vez:
##
## - Un solo nodo los dibuja todos (no hay un nodo por proyectil).
## - El host los simula en bloque, con la rejilla de mobs, y manda los eventos agrupados: un
##   mensaje por tipo y frame, nunca uno por proyectil o por golpe.
## - Por red solo viajan eventos (nace, crece, explota, termina). Entre eventos todas las
##   máquinas hacen volar el proyectil en línea recta con la misma velocidad.
## - Topes por jugador y global para que ningún efecto desboque el juego.

## Posición del proyectil sobre el suelo, para que no parezca que va por el suelo.
const FLIGHT_HEIGHT := 12.0
const EXPLOSION_TIME := 0.3
## Topes de proyectiles vivos, por jugador y en total.
@export var max_per_player: int = 150
@export var max_total: int = 600

class Proj:
	var id: int = 0
	var data: ProjectileData
	var owner_peer: int = 1
	## En pantalla.
	var position: Vector2 = Vector2.ZERO
	## En el suelo plano, normalizada.
	var direction: Vector2 = Vector2.RIGHT
	var traveled: float = 0.0
	var age: float = 0.0
	var hits: int = 0
	var radius: float = 5.0
	## Solo en el host.
	var damage: int = 0
	var hit_ids: Dictionary = {}
	var dead: bool = false

## Todos los jugadores y el gestor de mobs. Los rellena el mundo.
var players: Array[Player] = []
var mobs: MobManager

## Host: la simulación. Todos: lo que se dibuja.
var _sim: Dictionary = {}
var _view: Dictionary = {}
var _fx: Array[Dictionary] = []
var _per_owner: Dictionary = {}
var _next_id: int = 1

# Eventos del host pendientes de mandar este frame.
var _spawn_ids := PackedInt32Array()
var _spawn_kinds := PackedStringArray()
var _spawn_peers := PackedInt32Array()
var _spawn_positions := PackedVector2Array()
var _spawn_dirs := PackedVector2Array()
var _grow_ids := PackedInt32Array()
var _grow_hits := PackedInt32Array()
var _boom_positions := PackedVector2Array()
var _boom_radii := PackedFloat32Array()
var _boom_colors := PackedColorArray()
var _end_ids := PackedInt32Array()


func _ready() -> void:
	z_index = 30


func projectile_count() -> int:
	return _view.size()


## Dispara un proyectil (solo el host). `origin` en pantalla, `direction` en el suelo plano.
## Devuelve su id, o 0 si se ha llegado a un tope.
func fire(peer_id: int, projectile_id: StringName, origin: Vector2, direction: Vector2, damage_mult: float = 1.0) -> int:
	if _sim.size() >= max_total or _per_owner.get(peer_id, 0) >= max_per_player:
		return 0
	var data := GameData.projectile(projectile_id)
	var caster := _player_by_peer(peer_id)
	if data == null or caster == null:
		return 0
	var proj := Proj.new()
	proj.id = _next_id
	_next_id += 1
	proj.data = data
	proj.owner_peer = peer_id
	proj.position = origin
	proj.direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	proj.radius = data.radius
	proj.damage = maxi(1, roundi(caster.attack_damage * data.damage_mult * damage_mult))
	_sim[proj.id] = proj
	_per_owner[peer_id] = _per_owner.get(peer_id, 0) + 1
	_spawn_ids.append(proj.id)
	_spawn_kinds.append(String(projectile_id))
	_spawn_peers.append(peer_id)
	_spawn_positions.append(origin)
	_spawn_dirs.append(proj.direction)
	return proj.id


func _physics_process(delta: float) -> void:
	_tick_view(delta)
	if not multiplayer.is_server():
		return
	_tick_sim(delta)
	_flush()


func _process(_delta: float) -> void:
	if not _view.is_empty() or not _fx.is_empty():
		queue_redraw()


# --- Simulación del host ---------------------------------------------------------------

func _tick_sim(delta: float) -> void:
	for proj: Proj in _sim.values():
		if proj.dead:
			continue
		var data := proj.data
		var step := data.speed * delta
		var from := proj.position
		var to := from + Iso.to_screen(proj.direction * step)
		var ground_from := Iso.to_ground(from)
		var ground_to := Iso.to_ground(to)
		proj.position = to
		proj.traveled += step
		proj.age += delta

		var reach := proj.radius + step * 0.5
		for mob in mobs.mobs_near_ground((ground_from + ground_to) * 0.5, reach):
			if proj.hit_ids.has(mob.mob_id):
				continue
			var closest := Geometry2D.get_closest_point_to_segment(mob.ground_position, ground_from, ground_to)
			if closest.distance_to(mob.ground_position) > proj.radius + mob.data.radius:
				continue
			_hit(proj, mob)
			if proj.dead:
				break
		if not proj.dead and (proj.traveled >= data.max_range or proj.age >= data.lifetime):
			_end(proj)
	# Los terminados se quitan fuera del bucle de arriba.
	for id in _end_ids:
		_sim.erase(id)


func _hit(proj: Proj, mob: Mob) -> void:
	var data := proj.data
	proj.hit_ids[mob.mob_id] = true
	var damage := roundi(proj.damage * (1.0 + data.grow_damage_per_hit * proj.hits))
	proj.hits += 1
	mobs.hit_mob(mob, damage, proj.owner_peer)
	if data.grow_radius_per_hit > 0.0:
		proj.radius = data.radius_after(proj.hits)
		_grow_ids.append(proj.id)
		_grow_hits.append(proj.hits)
	if data.explode_radius > 0.0 and data.explode_at_hits > 0 and proj.hits == data.explode_at_hits:
		_explode(proj)
		if data.explode_ends_projectile:
			_end(proj)
			return
	if data.pierce >= 0 and proj.hits > data.pierce:
		_end(proj)


func _explode(proj: Proj) -> void:
	var data := proj.data
	var damage := maxi(1, roundi(proj.damage * data.explode_damage_mult))
	for mob in mobs.mobs_in_circle(proj.position, data.explode_radius):
		mobs.hit_mob(mob, damage, proj.owner_peer)
	_boom_positions.append(proj.position)
	_boom_radii.append(data.explode_radius)
	_boom_colors.append(data.color)
	if data.child_id != &"" and data.child_count > 0:
		var offset := randf() * TAU
		for i in data.child_count:
			var angle := offset + TAU * i / data.child_count
			fire(proj.owner_peer, data.child_id, proj.position, Vector2.from_angle(angle))


func _end(proj: Proj) -> void:
	if proj.dead:
		return
	proj.dead = true
	_end_ids.append(proj.id)
	_per_owner[proj.owner_peer] = maxi(0, _per_owner.get(proj.owner_peer, 1) - 1)


## Manda lo ocurrido este frame, en un mensaje por tipo.
func _flush() -> void:
	var online := not multiplayer.get_peers().is_empty()
	if not _spawn_ids.is_empty():
		if online:
			_ev_spawn.rpc(_spawn_ids, _spawn_kinds, _spawn_peers, _spawn_positions, _spawn_dirs)
		_ev_spawn(_spawn_ids, _spawn_kinds, _spawn_peers, _spawn_positions, _spawn_dirs)
	if not _grow_ids.is_empty():
		if online:
			_ev_grow.rpc(_grow_ids, _grow_hits)
		_ev_grow(_grow_ids, _grow_hits)
	if not _boom_positions.is_empty():
		if online:
			_ev_boom.rpc(_boom_positions, _boom_radii, _boom_colors)
		_ev_boom(_boom_positions, _boom_radii, _boom_colors)
	if not _end_ids.is_empty():
		if online:
			_ev_end.rpc(_end_ids)
		_ev_end(_end_ids)
	_spawn_ids = PackedInt32Array()
	_spawn_kinds = PackedStringArray()
	_spawn_peers = PackedInt32Array()
	_spawn_positions = PackedVector2Array()
	_spawn_dirs = PackedVector2Array()
	_grow_ids = PackedInt32Array()
	_grow_hits = PackedInt32Array()
	_boom_positions = PackedVector2Array()
	_boom_radii = PackedFloat32Array()
	_boom_colors = PackedColorArray()
	_end_ids = PackedInt32Array()


# --- Eventos: del host a los demás (el host también los aplica en local) ---------------

@rpc("authority", "reliable")
func _ev_spawn(ids: PackedInt32Array, kinds: PackedStringArray, peers: PackedInt32Array, positions: PackedVector2Array, dirs: PackedVector2Array) -> void:
	for i in ids.size():
		var data := GameData.projectile(StringName(kinds[i]))
		if data == null:
			continue
		var proj := Proj.new()
		proj.id = ids[i]
		proj.data = data
		proj.owner_peer = peers[i]
		proj.position = positions[i]
		proj.direction = dirs[i]
		proj.radius = data.radius
		_view[proj.id] = proj


@rpc("authority", "reliable")
func _ev_grow(ids: PackedInt32Array, hits: PackedInt32Array) -> void:
	for i in ids.size():
		var proj: Proj = _view.get(ids[i])
		if proj != null:
			proj.hits = hits[i]
			proj.radius = proj.data.radius_after(hits[i])


@rpc("authority", "reliable")
func _ev_boom(positions: PackedVector2Array, radii: PackedFloat32Array, colors: PackedColorArray) -> void:
	for i in positions.size():
		_fx.append({"position": positions[i], "radius": radii[i], "color": colors[i], "age": 0.0})


@rpc("authority", "reliable")
func _ev_end(ids: PackedInt32Array) -> void:
	for id in ids:
		_view.erase(id)


# --- Vista (todos) ---------------------------------------------------------------------

func _tick_view(delta: float) -> void:
	for proj: Proj in _view.values():
		proj.position += Iso.to_screen(proj.direction * proj.data.speed * delta)
		proj.age += delta
		# Por si se perdiera el aviso de que ha terminado.
		if proj.age > proj.data.lifetime + 1.0:
			_view.erase(proj.id)
	var i := _fx.size() - 1
	while i >= 0:
		_fx[i]["age"] += delta
		if _fx[i]["age"] >= EXPLOSION_TIME:
			_fx.remove_at(i)
		i -= 1


func _draw() -> void:
	# Primero todas las sombras, con una sola transformación; luego los cuerpos.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	for proj: Proj in _view.values():
		draw_circle(Vector2(proj.position.x, proj.position.y / Iso.Y_SCALE), proj.radius * 0.8, Color(0, 0, 0, 0.25))
	for fx in _fx:
		var t: float = fx["age"] / EXPLOSION_TIME
		var ring: float = fx["radius"] * (0.4 + 0.6 * t)
		var color: Color = fx["color"]
		color.a = 0.5 * (1.0 - t)
		var spot: Vector2 = fx["position"]
		draw_circle(Vector2(spot.x, spot.y / Iso.Y_SCALE), ring, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for proj: Proj in _view.values():
		var at := proj.position + Vector2(0, -FLIGHT_HEIGHT)
		var color := proj.data.color
		if proj.data.shape == ProjectileData.Shape.ARROW:
			var along := Iso.to_screen(proj.direction).normalized()
			var length := proj.radius * 3.0
			draw_line(at - along * length, at + along * length * 0.5, color, maxf(2.0, proj.radius * 0.6))
			draw_circle(at + along * length * 0.5, proj.radius * 0.7, color.lightened(0.4))
		else:
			draw_circle(at, proj.radius * 1.4, Color(color.r, color.g, color.b, 0.3))
			draw_circle(at, proj.radius, color)
			draw_circle(at, proj.radius * 0.45, color.lightened(0.6))


func _player_by_peer(peer_id: int) -> Player:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
