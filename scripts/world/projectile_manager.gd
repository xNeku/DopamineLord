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
const FALL_TIME := 0.3
const FALL_HEIGHT := 160.0
const SHADER := preload("res://scripts/world/projectile_renderer.gdshader")
const MAX_KINDS := 32
const FLOATS_PER_INSTANCE := 12  # transform 2D (8) + datos propios (4)
const BALL_SEGMENTS := 16
## Se dibujan los proyectiles hasta este margen más allá de la pantalla.
const CULL_MARGIN := 48.0
const PUFF_MAX := 64
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
	var max_range: float = 0.0
	var age: float = 0.0
	var hits: int = 0
	var radius: float = 5.0
	## Solo en el host.
	var damage: int = 0
	var base_damage: int = 0
	var hit_ids: Dictionary = {}
	## Rebote del ataque básico (pasiva Bounce): rebotes que le quedan, alcance y ganancia.
	var bounces_left: int = 0
	var bounces_done: int = 0
	var bounce_range: float = 0.0
	var bounce_gain: float = 0.0
	var dead: bool = false
	## Tipo en el dibujo en bloque.
	var kind: int = 0
	## Solo en el host: todavía no se ha mandado el evento de que ha nacido.
	var fresh: bool = true
	## Solo en el dibujo: ya se ha escrito en la MultiMesh al menos una vez, y ya ha terminado
	## (se quita después de dibujarlo, para que nunca desaparezca sin haberse visto).
	var drawn: bool = false
	var ending: bool = false

## Para las métricas: proyectiles que nacen y terminan en el mismo tick (nunca llegan a dibujarse),
## y cuántos se han dibujado en el último frame.
var stat_instant: int = 0
var stat_fired: int = 0
var stat_drawn: int = 0
## Cuántos proyectiles habrían desaparecido sin llegar a dibujarse ni un frame (se alarga su vida).
var stat_unseen: int = 0

## Todos los jugadores y el gestor de mobs. Los rellena el mundo.
var players: Array[Player] = []
var mobs: MobManager

## Host: la simulación. Todos: lo que se dibuja.
var _sim: Dictionary = {}
var _view: Dictionary = {}
var _fx: Array[Dictionary] = []
## Manchas en el suelo (rastros) y bolas que caen del cielo (Lluvia): solo se dibujan.
var _patches: Array[Dictionary] = []
var _falls: Array[Dictionary] = []
var _per_owner: Dictionary = {}
var _next_id: int = 1
var _was_active: bool = false
## Dibujo en bloque: una MultiMesh compartida por dos nodos (sombras debajo, cuerpos encima).
var _multimesh: MultiMesh
var _buffer := PackedFloat32Array()
var _materials: Array[ShaderMaterial] = []
var _kind_index: Dictionary = {}
var _kind_colors := PackedVector4Array()
var _kind_shapes := PackedFloat32Array()

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
var _redirect_ids := PackedInt32Array()
var _redirect_positions := PackedVector2Array()
var _redirect_dirs := PackedVector2Array()


func _ready() -> void:
	z_index = 30
	_kind_colors.resize(MAX_KINDS)
	_kind_shapes.resize(MAX_KINDS)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = false
	_multimesh.use_custom_data = true
	_multimesh.mesh = _build_mesh()
	for layer in 2:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("layer", layer)
		_materials.append(material)
		var node := MultiMeshInstance2D.new()
		node.multimesh = _multimesh
		node.material = material
		node.z_index = -1 if layer == 0 else 0
		add_child(node)


func projectile_count() -> int:
	return _view.size()


## Dispara un proyectil (solo el host). `origin` en pantalla, `direction` en el suelo plano.
## Al proyectil le afectan los modificadores del lanzador (ver `affected_by_passives`). Devuelve
## su id, o 0 si se ha llegado a un tope.
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
	proj.base_damage = proj.damage
	proj.max_range = data.max_range
	if data.affected_by_passives:
		proj.max_range *= caster.attack_range_mult
		for skill in caster.skills:
			if skill is BounceSkillData:
				proj.bounces_left = skill.max_bounces
				proj.bounce_range = skill.bounce_range
				proj.bounce_gain = skill.damage_gain
	_sim[proj.id] = proj
	stat_fired += 1
	_per_owner[peer_id] = _per_owner.get(peer_id, 0) + 1
	_spawn_ids.append(proj.id)
	_spawn_kinds.append(String(projectile_id))
	_spawn_peers.append(peer_id)
	_spawn_positions.append(origin)
	_spawn_dirs.append(proj.direction)
	return proj.id


func _physics_process(delta: float) -> void:
	PerfProbe.begin(&"proj_view")
	_tick_view(delta)
	PerfProbe.end(&"proj_view")
	if not multiplayer.is_server():
		return
	PerfProbe.begin(&"proj_sim")
	_tick_sim(delta)
	PerfProbe.end(&"proj_sim")
	PerfProbe.begin(&"proj_net")
	_flush()
	PerfProbe.end(&"proj_net")


var _simple: Array[Vector3] = []


func _process(_delta: float) -> void:
	_simple.clear()
	var active := not _view.is_empty() or not _fx.is_empty() or not _patches.is_empty() or not _falls.is_empty()
	# Un redibujado más al quedarse vacío, para que el último fotograma no se quede en pantalla.
	if active or _was_active or ViewInfo.simple_draw:
		queue_redraw()
	_was_active = active
	PerfProbe.begin(&"proj_draw")
	_fill_instances()
	PerfProbe.end(&"proj_draw")


## Manchas en el suelo que duran `life` segundos (solo visual; el daño lo lleva quien las
## pide). Solo el host. Mejor llamarlo con varias posiciones a la vez.
func add_patches(positions: PackedVector2Array, radius: float, color: Color, life: float) -> void:
	if positions.is_empty():
		return
	if not multiplayer.get_peers().is_empty():
		_ev_patch.rpc(positions, radius, color, life)
	_ev_patch(positions, radius, color, life)


## Bolas que caen del cielo hasta `positions` (solo visual). Solo el host.
func add_falls(positions: PackedVector2Array, color: Color) -> void:
	if positions.is_empty():
		return
	if not multiplayer.get_peers().is_empty():
		_ev_fall.rpc(positions, color)
	_ev_fall(positions, color)


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
		if not proj.dead and (proj.traveled >= proj.max_range or proj.age >= data.lifetime):
			_end(proj)
		elif not proj.dead and data.until_offscreen:
			var caster := _player_by_peer(proj.owner_peer)
			if caster == null or not ViewRange.contains(caster.position, proj.position):
				_end(proj)
	# Los terminados se quitan fuera del bucle de arriba.
	for id in _end_ids:
		_sim.erase(id)


func _hit(proj: Proj, mob: Mob) -> void:
	var data := proj.data
	proj.hit_ids[mob.mob_id] = true
	var damage := roundi(proj.damage * (1.0 + data.grow_damage_per_hit * proj.hits))
	proj.hits += 1
	if data.knockback > 0.0:
		var crit := roundi(damage * data.crit_mult) if data.crit_mult > 0.0 else 0
		mobs.knock_mob(mob, proj.direction * data.knockback, data.knockback_time, crit, proj.owner_peer)
	var killed := mobs.hit_mob(mob, damage, proj.owner_peer)
	if killed and proj.bounces_left > 0 and _try_bounce(proj):
		return
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


## Pasiva Bounce: tras matar, la flecha sigue hacia el enemigo más cercano con más daño.
func _try_bounce(proj: Proj) -> bool:
	var ground := Iso.to_ground(proj.position)
	var best: Mob = null
	var best_distance := INF
	for mob in mobs.mobs_near_ground(ground, proj.bounce_range):
		if proj.hit_ids.has(mob.mob_id):
			continue
		var distance := mob.ground_position.distance_to(ground)
		if distance <= proj.bounce_range + mob.data.radius and distance < best_distance:
			best = mob
			best_distance = distance
	if best == null:
		return false
	proj.bounces_left -= 1
	proj.bounces_done += 1
	proj.damage = roundi(proj.base_damage * (1.0 + proj.bounce_gain * proj.bounces_done))
	proj.direction = (best.ground_position - ground).normalized()
	proj.traveled = 0.0
	_redirect_ids.append(proj.id)
	_redirect_positions.append(proj.position)
	_redirect_dirs.append(proj.direction)
	return true


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
	if proj.fresh:
		stat_instant += 1
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
	if not _redirect_ids.is_empty():
		if online:
			_ev_redirect.rpc(_redirect_ids, _redirect_positions, _redirect_dirs)
		_ev_redirect(_redirect_ids, _redirect_positions, _redirect_dirs)
	if not _end_ids.is_empty():
		if online:
			_ev_end.rpc(_end_ids)
		_ev_end(_end_ids)
	for id in _spawn_ids:
		var fresh: Proj = _sim.get(id)
		if fresh != null:
			fresh.fresh = false
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
	_redirect_ids = PackedInt32Array()
	_redirect_positions = PackedVector2Array()
	_redirect_dirs = PackedVector2Array()


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
		proj.kind = _kind_of(data)
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
func _ev_patch(positions: PackedVector2Array, radius: float, color: Color, life: float) -> void:
	for spot in positions:
		_patches.append({"position": spot, "radius": radius, "color": color, "age": 0.0, "life": life})


@rpc("authority", "reliable")
func _ev_fall(positions: PackedVector2Array, color: Color) -> void:
	for spot in positions:
		_falls.append({"position": spot, "color": color, "age": 0.0})


@rpc("authority", "reliable")
func _ev_redirect(ids: PackedInt32Array, positions: PackedVector2Array, dirs: PackedVector2Array) -> void:
	for i in ids.size():
		var proj: Proj = _view.get(ids[i])
		if proj != null:
			proj.position = positions[i]
			proj.direction = dirs[i]


@rpc("authority", "reliable")
func _ev_end(ids: PackedInt32Array) -> void:
	for id in ids:
		var proj: Proj = _view.get(id)
		if proj == null:
			continue
		_puff(proj)
		if proj.drawn:
			_view.erase(id)
		else:
			# Nació y terminó antes de que se dibujara ni un frame (un golpe a bocajarro, o
			# varios ticks de física seguidos): se deja un frame más para que se vea.
			proj.ending = true
			stat_unseen += 1


## Un aro pequeño donde acaba un proyectil, para que no se esfume de golpe.
func _puff(proj: Proj) -> void:
	if _fx.size() >= PUFF_MAX * 4 or not proj.drawn:
		return
	_fx.append({"position": proj.position, "radius": proj.radius * 2.2, "color": proj.data.color, "age": 0.0})


# --- Vista (todos) ---------------------------------------------------------------------

func _tick_view(delta: float) -> void:
	for proj: Proj in _view.values():
		proj.position += Iso.to_screen(proj.direction * proj.data.speed * delta)
		proj.age += delta
		# Por si se perdiera el aviso de que ha terminado.
		if proj.age > proj.data.lifetime + 1.0:
			_view.erase(proj.id)
	_age_list(_fx, delta, EXPLOSION_TIME)
	_age_list(_falls, delta, FALL_TIME)
	_age_list(_patches, delta, -1.0)


## Envejece una lista de efectos y quita los que han terminado (`life` < 0: cada uno trae el suyo).
func _age_list(list: Array[Dictionary], delta: float, life: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		list[i]["age"] += delta
		var limit: float = life if life > 0.0 else list[i]["life"]
		if list[i]["age"] >= limit:
			list.remove_at(i)
		i -= 1


## Escribe en la MultiMesh los proyectiles que están a la vista. Cuesta lo mismo (casi) con 50
## que con 500 y se dibuja en dos llamadas.
func _fill_instances() -> void:
	var count := 0
	if not players.is_empty() and not _view.is_empty():
		var view := ViewInfo.world_rect(get_viewport(), CULL_MARGIN)
		var low := view.position
		var high := view.end
		var needed := _view.size() * FLOATS_PER_INSTANCE
		if needed > _buffer.size():
			_buffer.resize(maxi(needed, maxi(_buffer.size() * 2, 128 * FLOATS_PER_INSTANCE)))
		var buffer := _buffer
		# El dibujo va a más fotogramas que la física: cada proyectil se adelanta lo que le toca
		# entre dos ticks, para que se mueva suave a cualquier frecuencia de pantalla.
		var ahead := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
		var finished: Array[int] = []
		for proj: Proj in _view.values():
			var position := proj.position + Iso.to_screen(proj.direction * proj.data.speed * ahead)
			if position.x < low.x or position.x > high.x or position.y < low.y or position.y > high.y:
				if proj.ending:
					finished.append(proj.id)
				continue
			if ViewInfo.simple_draw:
				_simple.append(Vector3(position.x, position.y, float(proj.kind)))
				proj.drawn = true
				if proj.ending:
					finished.append(proj.id)
				continue
			var offset := count * FLOATS_PER_INSTANCE
			buffer[offset] = 1.0
			buffer[offset + 1] = 0.0
			buffer[offset + 2] = 0.0
			buffer[offset + 3] = position.x
			buffer[offset + 4] = 0.0
			buffer[offset + 5] = 1.0
			buffer[offset + 6] = 0.0
			buffer[offset + 7] = position.y
			buffer[offset + 8] = float(proj.kind)
			buffer[offset + 9] = proj.radius
			if proj.data.shape == ProjectileData.Shape.ARROW:
				var along := Iso.to_screen(proj.direction).normalized()
				buffer[offset + 10] = along.x
				buffer[offset + 11] = along.y
			else:
				buffer[offset + 10] = proj.age * 6.0
				buffer[offset + 11] = 0.0
			count += 1
			proj.drawn = true
			if proj.ending:
				finished.append(proj.id)
		for id in finished:
			_view.erase(id)
		if count > 0:
			var capacity := buffer.size() / FLOATS_PER_INSTANCE
			if _multimesh.instance_count != capacity:
				_multimesh.instance_count = capacity
			_multimesh.buffer = buffer
	_multimesh.visible_instance_count = count
	stat_drawn = count


## Número de tipo para un proyectil (color y forma viajan en uniformes del shader).
func _kind_of(data: ProjectileData) -> int:
	if _kind_index.has(data.id):
		return _kind_index[data.id]
	var index: int = _kind_index.size()
	if index >= MAX_KINDS:
		push_warning("ProjectileManager: más de %d tipos de proyectil, se reutiliza el último" % MAX_KINDS)
		return MAX_KINDS - 1
	_kind_index[data.id] = index
	_kind_colors[index] = Vector4(data.color.r, data.color.g, data.color.b, 1.0)
	_kind_shapes[index] = float(data.shape)
	for material in _materials:
		material.set_shader_parameter("kind_color", _kind_colors)
		material.set_shader_parameter("kind_shape", _kind_shapes)
	return index


## Una malla con todas las formas posibles; el shader enseña solo las que tocan según la forma
## del proyectil. UV.x lleva el número de la parte (0 sombra, 1 halo, 2 cuerpo, 3 núcleo,
## 4 cuerpo de flecha, 5 punta de flecha, 6 mancha de nieve, 7 aro de nieve); UV.y, qué mancha.
func _build_mesh() -> ArrayMesh:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	_add_disc(vertices, uvs, indices, 0, 0.0, Vector2.ZERO, 1.0, Vector2(1.0, Iso.Y_SCALE))
	_add_disc(vertices, uvs, indices, 1, 0.0, Vector2.ZERO, 1.4, Vector2.ONE)
	_add_disc(vertices, uvs, indices, 2, 0.0, Vector2.ZERO, 1.0, Vector2.ONE)
	_add_disc(vertices, uvs, indices, 3, 0.0, Vector2.ZERO, 0.45, Vector2.ONE)
	# Cuerpo de flecha: de -3 a +1,5 radios de largo; la anchura la pone el shader (en píxeles).
	var first := vertices.size()
	for corner in [Vector2(-3.0, -1.0), Vector2(1.5, -1.0), Vector2(1.5, 1.0), Vector2(-3.0, 1.0)]:
		vertices.append(corner)
		uvs.append(Vector2(4.0, 0.0))
	indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	_add_disc(vertices, uvs, indices, 5, 0.0, Vector2.ZERO, 0.7, Vector2.ONE)
	for k in 3:
		_add_disc(vertices, uvs, indices, 6, float(k), Vector2.ZERO, 0.28, Vector2.ONE)
	# Aro de la bola de nieve.
	first = vertices.size()
	for i in BALL_SEGMENTS:
		var direction := Vector2.from_angle(TAU * i / BALL_SEGMENTS)
		vertices.append(direction * 0.9)
		vertices.append(direction)
		uvs.append(Vector2(7.0, 0.0))
		uvs.append(Vector2(7.0, 0.0))
	for i in BALL_SEGMENTS:
		var a := first + i * 2
		var b := first + ((i + 1) % BALL_SEGMENTS) * 2
		indices.append_array([a, a + 1, b, b, a + 1, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_disc(vertices: PackedVector2Array, uvs: PackedVector2Array, indices: PackedInt32Array, part: int, extra: float, center: Vector2, disc_radius: float, squash: Vector2) -> void:
	var first := vertices.size()
	vertices.append(center)
	uvs.append(Vector2(part, extra))
	for i in BALL_SEGMENTS:
		var angle := TAU * i / BALL_SEGMENTS
		vertices.append(center + Vector2(cos(angle) * disc_radius * squash.x, sin(angle) * disc_radius * squash.y))
		uvs.append(Vector2(part, extra))
	for i in BALL_SEGMENTS:
		indices.append_array([first, first + 1 + i, first + 1 + (i + 1) % BALL_SEGMENTS])


## Solo lo que sigue siendo poco numeroso y no merece MultiMesh: manchas del suelo, explosiones
## y bolas que caen (Lluvia).
func _draw() -> void:
	PerfProbe.begin(&"fx_draw")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	for patch in _patches:
		var left: float = 1.0 - patch["age"] / patch["life"]
		var tone: Color = patch["color"]
		tone.a = 0.35 * minf(1.0, left * 2.0)
		var at: Vector2 = patch["position"]
		draw_circle(Vector2(at.x, at.y / Iso.Y_SCALE), patch["radius"], tone)
	for fx in _fx:
		var t: float = fx["age"] / EXPLOSION_TIME
		var ring: float = fx["radius"] * (0.4 + 0.6 * t)
		var color: Color = fx["color"]
		color.a = 0.5 * (1.0 - t)
		var spot: Vector2 = fx["position"]
		draw_circle(Vector2(spot.x, spot.y / Iso.Y_SCALE), ring, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for spot in _simple:
		var tone := Color(_kind_colors[int(spot.z)].x, _kind_colors[int(spot.z)].y, _kind_colors[int(spot.z)].z)
		draw_circle(Vector2(spot.x, spot.y), 5.0, tone)
	for fall in _falls:
		var t: float = fall["age"] / FALL_TIME
		var tone: Color = fall["color"]
		var spot: Vector2 = fall["position"]
		draw_circle(spot + Vector2(0, -FALL_HEIGHT * (1.0 - t)), 4.0, tone.lightened(0.3))
	PerfProbe.end(&"fx_draw")


func _player_by_peer(peer_id: int) -> Player:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
