class_name MobData
extends Resource
## Definición de un tipo de mob. Cada uno vive en data/mobs/<id>.tres. Los valores se
## ajustan en el inspector; el código no tiene nada específico de ningún mob.

@export var id: StringName
@export var display_name: String = ""
@export var max_health: int = 30
## Píxeles por segundo en el suelo plano.
@export var move_speed: float = 55.0
@export var damage: int = 5
## Distancia a la que empieza a atacar (en el suelo plano).
@export var attack_range: float = 22.0
## Tiempo entre que avisa del golpe y lo da. Es la ventana para esquivar o saltar.
@export var attack_windup: float = 0.45
@export var attack_cooldown: float = 1.2
@export var radius: float = 7.0
## Color del programmer art. Cuando haya sprite, se añade aquí su ruta.
@export var color: Color = Color(0.75, 0.25, 0.25)

@export_group("Drops")
## Dinero que suelta al morir, entre el mínimo y el máximo. Con máximo 0 no suelta.
@export var drop_money_min: int = 1
@export var drop_money_max: int = 3
