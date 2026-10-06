class_name SkillManager
extends Node
## Las skills de los jugadores. Manda el host: valida, simula el daño y mueve lo que haga
## falta; todos los jugadores reciben eventos para dibujarlo.
##
## - Buff y giro: el host avisa y cada máquina aplica el efecto a ese jugador. El host hace
##   el daño del giro cada pocos décimos de segundo, alrededor del jugador.
## - Lanzada: el host mueve la espada y manda su posición unas 10 veces por segundo.
## - Guerra: sale de una semilla, así que todos dibujan las mismas espadas; el host aplica
##   daño y arrastre con esas mismas espadas.

const SNAPSHOT_INTERVAL := 0.1
## Margen para que la recarga del cliente (que empieza antes) no choque con la del host.
const COOLDOWN_SLACK := 0.4

## Todos los jugadores de la partida y el gestor de mobs. Los rellena el mundo.
var players: Array[Player] = []
var mobs: MobManager

var _spins: Array[Dictionary] = []
var _boomerangs: Dictionary = {}
var _rains: Array[Dictionary] = []
var _nodes: Dictionary = {}
var _next_id: int = 1
var _snapshot_timer: float = 0.0


## El jugador local quiere usar la skill del hueco `slot`.
func request_skill(slot: int, position: Vector2, direction: Vector2, target: Vector2) -> void:
	if multiplayer.is_server():
		_execute(multiplayer.get_unique_id(), slot, position, direction, target)
	else:
		_skill_request.rpc_id(1, slot, position, direction, target)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_tick_spins(delta)
	_tick_boomerangs(delta)
	_tick_rains(delta)
	_snapshot_timer += delta
	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer = 0.0
		_send_boomerang_snapshot()


# --- Lógica del host -------------------------------------------------------------------

func _execute(peer_id: int, slot: int, position: Vector2, direction: Vector2, target: Vector2) -> void:
	var caster := _player_by_peer(peer_id)
	if caster == null or caster.is_dead or slot < 0 or slot >= caster.skills.size():
		return
	var skill := caster.skills[slot]
	if skill == null:
		return
	if caster.is_remote:
		if caster.skill_cooldown_left[slot] > COOLDOWN_SLACK:
			return
		caster.skill_cooldown_left[slot] = skill.cooldown
	var aim := direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT

	if skill is BuffSkillData:
		_buff_start.rpc(peer_id, skill.id)
	elif skill is SpinSkillData:
		_spin_start.rpc(peer_id, skill.id)
		_spins.append({"peer": peer_id, "data": skill, "left": skill.duration, "tick": 0.0})
	elif skill is BoomerangSkillData:
		var id := _take_id()
		_boomerang_spawn.rpc(id, peer_id, skill.id, position, aim)
		_boomerangs[id] = {
			"peer": peer_id, "data": skill, "position": position, "direction": aim,
			"out": true, "traveled": 0.0, "reach": skill.reach, "hits": {}, "hit_count": 0,
			"radius": skill.radius, "age": 0.0,
		}
	elif skill is RainSkillData:
		var offset := Iso.to_ground(target - position)
		offset = offset.limit_length(skill.max_cast_range)
		var center := position + Iso.to_screen(offset)
		var id := _take_id()
		var seed_value := randi()
		_rain_spawn.rpc(id, skill.id, center, seed_value)
		_rains.append({
			"peer": peer_id, "data": skill, "center": center, "time": 0.0, "fired": 0,
			"swords": SwordRainEffect.generate(skill, seed_value),
		})


func _tick_spins(delta: float) -> void:
	for spin in _spins.duplicate():
		var caster := _player_by_peer(spin["peer"])
		spin["left"] -= delta
		if caster == null or caster.is_dead or spin["left"] <= 0.0:
			_spins.erase(spin)
			continue
		spin["tick"] += delta
		var data: SpinSkillData = spin["data"]
		if spin["tick"] >= data.tick_interval:
			spin["tick"] -= data.tick_interval
			for mob in mobs.mobs_in_circle(caster.position, data.radius):
				mobs.hit_mob(mob, data.damage, spin["peer"])


func _tick_boomerangs(delta: float) -> void:
	for id in _boomerangs.keys():
		var state: Dictionary = _boomerangs[id]
		var data: BoomerangSkillData = state["data"]
		var caster := _player_by_peer(state["peer"])
		state["age"] += delta
		var step := data.speed * delta
		var finished: bool = state["age"] > 8.0 or caster == null
		if state["out"]:
			state["position"] += Iso.to_screen(state["direction"] * step)
			state["traveled"] += step
			if state["traveled"] >= state["reach"]:
				state["out"] = false
				state["hits"].clear()
		elif caster != null:
			var to_caster := Iso.to_ground(caster.position - state["position"])
			if to_caster.length() <= step + 8.0:
				finished = true
			else:
				state["position"] += Iso.to_screen(to_caster.normalized() * step)

		if finished:
			_boomerang_end.rpc(id)
			_boomerangs.erase(id)
			continue
		for mob in mobs.mobs_in_circle(state["position"], state["radius"]):
			if state["hits"].has(mob.mob_id):
				continue
			state["hits"][mob.mob_id] = true
			state["hit_count"] += 1
			if state["out"]:
				state["reach"] = minf(data.reach + data.reach_per_hit * state["hit_count"], data.max_reach)
			state["radius"] = minf(data.radius + data.radius_per_hit * state["hit_count"], data.max_radius)
			mobs.hit_mob(mob, data.damage, state["peer"])
		var node: BoomerangProjectile = _nodes.get(id)
		if node != null:
			node.set_state(state["position"], state["radius"], false)


func _tick_rains(delta: float) -> void:
	var pulls: Dictionary = {}
	for rain in _rains.duplicate():
		var data: RainSkillData = rain["data"]
		rain["time"] += delta
		var swords: Array = rain["swords"]
		while rain["fired"] < swords.size() and swords[rain["fired"]]["land"] <= rain["time"]:
			var spot: Vector2 = rain["center"] + Iso.to_screen(swords[rain["fired"]]["offset"])
			for mob in mobs.mobs_in_circle(spot, data.sword_radius):
				mobs.hit_mob(mob, data.sword_damage, rain["peer"])
			rain["fired"] += 1
		if rain["time"] >= data.duration:
			_rains.erase(rain)
			continue
		for mob in mobs.mobs_in_circle(rain["center"], data.radius):
			var to_center := Iso.to_ground(rain["center"] - mob.position)
			if to_center.length() > 5.0:
				pulls[mob] = Iso.to_screen(to_center.normalized() * data.pull_speed)
	for mob in mobs.all_mobs():
		mob.pull_velocity = pulls.get(mob, Vector2.ZERO)


func _send_boomerang_snapshot() -> void:
	if _boomerangs.is_empty() or multiplayer.get_peers().is_empty():
		return
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var radii := PackedFloat32Array()
	for id in _boomerangs:
		ids.append(id)
		positions.append(_boomerangs[id]["position"])
		radii.append(_boomerangs[id]["radius"])
	_boomerang_snapshot.rpc(ids, positions, radii)


func _take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func _player_by_peer(peer_id: int) -> Player:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null


# --- Mensajes: del host a todos --------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _buff_start(peer_id: int, skill_id: StringName) -> void:
	var player := _player_by_peer(peer_id)
	if player != null:
		player.apply_buff(GameData.skill(skill_id) as BuffSkillData)


@rpc("authority", "call_local", "reliable")
func _spin_start(peer_id: int, skill_id: StringName) -> void:
	var player := _player_by_peer(peer_id)
	if player != null:
		player.start_spin(GameData.skill(skill_id) as SpinSkillData)


@rpc("authority", "call_local", "reliable")
func _boomerang_spawn(id: int, _peer_id: int, skill_id: StringName, spot: Vector2, _direction: Vector2) -> void:
	var data := GameData.skill(skill_id) as BoomerangSkillData
	var node := BoomerangProjectile.new()
	node.z_index = 50
	add_child(node)
	node.set_state(spot, data.radius, false)
	_nodes[id] = node


@rpc("authority", "unreliable_ordered")
func _boomerang_snapshot(ids: PackedInt32Array, positions: PackedVector2Array, radii: PackedFloat32Array) -> void:
	for i in ids.size():
		var node: BoomerangProjectile = _nodes.get(ids[i])
		if node != null:
			node.set_state(positions[i], radii[i], true)


@rpc("authority", "call_local", "reliable")
func _boomerang_end(id: int) -> void:
	var node: BoomerangProjectile = _nodes.get(id)
	if node != null:
		_nodes.erase(id)
		node.queue_free()


@rpc("authority", "call_local", "reliable")
func _rain_spawn(_id: int, skill_id: StringName, center: Vector2, seed_value: int) -> void:
	var effect := SwordRainEffect.new()
	effect.position = center
	effect.setup(GameData.skill(skill_id) as RainSkillData, seed_value)
	add_child(effect)


# --- Mensajes: de un cliente al host ---------------------------------------------------

@rpc("any_peer", "reliable")
func _skill_request(slot: int, position: Vector2, direction: Vector2, target: Vector2) -> void:
	if multiplayer.is_server():
		_execute(multiplayer.get_remote_sender_id(), slot, position, direction, target)
