class_name GameData
extends RefCounted
## Acceso a las definiciones de data/ por su id.

static var _mobs: Dictionary = {}


static func mob(id: StringName) -> MobData:
	if not _mobs.has(id):
		_mobs[id] = load("res://data/mobs/%s.tres" % id) as MobData
	return _mobs[id]
