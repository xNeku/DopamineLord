class_name GameData
extends RefCounted
## Acceso a las definiciones de data/ por su id.

static var _mobs: Dictionary = {}
static var _skills: Dictionary = {}


static func mob(id: StringName) -> MobData:
	if not _mobs.has(id):
		_mobs[id] = load("res://data/mobs/%s.tres" % id) as MobData
	return _mobs[id]


static func skill(id: StringName) -> SkillData:
	if not _skills.has(id):
		_skills[id] = load("res://data/skills/%s.tres" % id) as SkillData
	return _skills[id]
