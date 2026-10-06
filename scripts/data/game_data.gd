class_name GameData
extends RefCounted
## Acceso a las definiciones de data/ por su id.

static var _mobs: Dictionary = {}
static var _skills: Dictionary = {}
static var _classes: Dictionary = {}
static var _projectiles: Dictionary = {}
## Ramas disponibles, en el orden en que se enseñan en el selector.
const CLASS_IDS: Array[StringName] = [&"melee", &"rango", &"mago"]


static func mob(id: StringName) -> MobData:
	if not _mobs.has(id):
		_mobs[id] = load("res://data/mobs/%s.tres" % id) as MobData
	return _mobs[id]


static func skill(id: StringName) -> SkillData:
	if not _skills.has(id):
		_skills[id] = load("res://data/skills/%s.tres" % id) as SkillData
	return _skills[id]


static func char_class(id: StringName) -> ClassData:
	if not _classes.has(id):
		_classes[id] = load("res://data/classes/%s.tres" % id) as ClassData
	return _classes[id]


static func projectile(id: StringName) -> ProjectileData:
	if not _projectiles.has(id):
		_projectiles[id] = load("res://data/projectiles/%s.tres" % id) as ProjectileData
	return _projectiles[id]
