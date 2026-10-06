class_name ClassData
extends Resource
## Una rama jugable (Melee, Rango, Magia): stats base, ataque básico y las 4 skills.
## Las definiciones viven en data/classes/<id>.tres y se ajustan en el inspector (o desde la
## hoja de balance). Los stats de movimiento y salto se comparten entre ramas: aquí solo hay
## multiplicadores.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## Si es false aparece en el selector pero no se puede elegir (todavía no está hecha).
@export var playable: bool = true
## Color de la rama, para el selector y los efectos.
@export var color: Color = Color.WHITE

@export_group("Stats base")
@export var max_health: int = 100
## Multiplica la velocidad de movimiento del jugador (y, con ella, la distancia del salto).
@export var move_speed_mult: float = 1.0
## Fracción del daño que hace que se convierte en vida (0.1 = el 10%). Cuenta el básico y las skills.
@export_range(0.0, 1.0) var life_steal: float = 0.0
## Vida que recupera por segundo.
@export var health_regen: float = 0.0

@export_group("Ataque básico")
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.4
## Alcance en el suelo plano, medido desde el jugador.
@export var attack_range: float = 40.0
@export_range(10.0, 360.0) var attack_arc_degrees: float = 140.0

@export_group("Skills")
## Las skills de los huecos 1 a 4, por su id (data/skills/). Un id vacío es un hueco sin skill.
@export var skill_ids: Array[StringName] = []
