class_name MobData
extends Resource
## Definición de un tipo de mob. Cada uno vive en data/mobs/<id>.tres. Los valores se
## ajustan en el inspector; el código no tiene nada específico de ningún mob.

## Cómo se comporta: cuerpo a cuerpo, a distancia (dispara y se mantiene lejos) o saltador
## (cuerpo a cuerpo que además salta sobre el jugador y lo lanza hacia fuera).
enum Ai { MELEE, RANGED, LEAPER }

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

@export var ai: Ai = Ai.MELEE

## Cuánto resiste los empujones (0 = nada, 1 = inmune).
@export_range(0.0, 1.0) var knockback_resist: float = 0.0

@export_group("Aparición")
## Peso al elegir qué mob hace aparecer el host. Más peso, más frecuente.
@export var spawn_weight: float = 10.0
## Aparecen en grupos de este tamaño.
@export var group_min: int = 1
@export var group_max: int = 1
## Máximo de este mob vivo a la vez (0 = sin límite).
@export var max_alive: int = 0

@export_group("A distancia")
## Distancia a la que le gusta quedarse: si te acercas, retrocede; si te alejas, se acerca.
@export var preferred_distance: float = 130.0
@export var projectile_speed: float = 140.0
@export var projectile_radius: float = 4.0
@export var projectile_lifetime: float = 3.0

@export_group("Salto")
@export var leap_cooldown: float = 6.0
## Solo salta si el jugador está entre estas dos distancias.
@export var leap_min_distance: float = 70.0
@export var leap_max_distance: float = 240.0
## Aviso antes de despegar: se ve una marca donde va a caer.
@export var leap_windup: float = 0.9
@export var leap_duration: float = 0.6
## Radio del área de aterrizaje, en el suelo plano.
@export var leap_radius: float = 50.0
@export var leap_damage: int = 25
## Altura del arco, solo visual.
@export var leap_height: float = 60.0

@export_group("Drops")
## Dinero que suelta al morir, entre el mínimo y el máximo. Con máximo 0 no suelta.
@export var drop_money_min: int = 1
@export var drop_money_max: int = 3
