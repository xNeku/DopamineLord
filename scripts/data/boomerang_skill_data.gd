class_name BoomerangSkillData
extends SkillData
## Lanza la espada, que va, vuelve y crece con cada enemigo que golpea (Lanzada).

## Distancia que recorre antes de dar la vuelta, en el suelo plano.
@export var reach: float = 170.0
@export var speed: float = 300.0
@export var damage: int = 14
## Radio de golpeo al lanzarla.
@export var radius: float = 14.0
## Cuánto crece el radio con cada enemigo golpeado.
@export var radius_per_hit: float = 5.0
@export var max_radius: float = 60.0
