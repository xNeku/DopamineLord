class_name ProjectileData
extends Resource
## Un tipo de proyectil de jugador (flecha, bola de magia, mini bola...). Lo simula el host en
## bloque (ProjectileManager) y todos lo dibujan. Las definiciones viven en
## data/projectiles/<id>.tres.

enum Shape { BALL, ARROW, SNOWBALL }

@export var id: StringName
@export var shape: Shape = Shape.BALL
@export var color: Color = Color(1.0, 0.85, 0.2)
## Etiquetas para las sinergias del nivel 75 (elemento, munición, estilo).
@export var tags: Array[StringName] = []

## Si es true, le afectan los modificadores del lanzador: pasivas (Bounce), alcance y, en las
## skills que disparan a ritmo, la velocidad de ataque. Regla del juego: todo proyectil de una
## skill se comporta como lo haría un proyectil normal de esa rama.
@export var affected_by_passives: bool = true

@export_group("Vuelo")
## Píxeles por segundo en el suelo plano.
@export var speed: float = 300.0
@export var radius: float = 5.0
## Distancia máxima que recorre, en el suelo plano.
@export var max_range: float = 300.0
## Tope de segundos de vida, por si acaso.
@export var lifetime: float = 5.0

@export_group("Daño")
## Daño = ataque del lanzador × este valor.
@export var damage_mult: float = 1.0
## A cuántos enemigos atraviesa antes de desaparecer. 0 = se para en el primero, -1 = infinito.
@export var pierce: int = 0
## Cuánto crece el radio con cada enemigo golpeado, hasta `max_radius`.
@export var grow_radius_per_hit: float = 0.0
@export var max_radius: float = 40.0
## Cuánto sube el daño con cada enemigo golpeado (0.2 = +20% por golpe).
@export var grow_damage_per_hit: float = 0.0

@export_group("Empuje")
## Cuánto empuja a cada enemigo que golpea, en la dirección del proyectil (suelo plano).
@export var knockback: float = 0.0
@export var knockback_time: float = 0.25
## Si es > 0: el enemigo empujado que acaba fuera de la vista del lanzador recibe un golpe
## crítico de este múltiplo del daño del proyectil.
@export var crit_mult: float = 0.0
## Si es true, vuela hasta salir de la vista del lanzador (en vez de parar en `max_range`).
@export var until_offscreen: bool = false

@export_group("Explosión")
## 0 = no explota.
@export var explode_radius: float = 0.0
@export var explode_damage_mult: float = 1.0
## Explota al golpear a este número de enemigos (1 = al primero). 0 = nunca.
@export var explode_at_hits: int = 0
## Si es true, el proyectil desaparece al explotar.
@export var explode_ends_projectile: bool = true
## Proyectiles que salen al explotar, repartidos en círculo. No explotan en cadena si su
## propio `explode_at_hits` es 0.
@export var child_id: StringName = &""
@export var child_count: int = 0


## Radio del proyectil tras golpear a `hits` enemigos. Lo usan el host y los clientes.
func radius_after(hits: int) -> float:
	return minf(radius + grow_radius_per_hit * hits, maxf(max_radius, radius))
