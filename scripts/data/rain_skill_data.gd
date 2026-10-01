class_name RainSkillData
extends SkillData
## Grito de guerra: caen espadas del cielo en un círculo y los enemigos son arrastrados
## hacia su centro (Guerra).

@export var radius: float = 90.0
@export var duration: float = 2.0
## Velocidad con la que arrastra a los enemigos hacia el centro.
@export var pull_speed: float = 90.0
@export var sword_count: int = 14
@export var sword_damage: int = 12
## Radio de impacto de cada espada.
@export var sword_radius: float = 22.0
## Distancia máxima a la que se puede lanzar el círculo desde el jugador.
@export var max_cast_range: float = 140.0
