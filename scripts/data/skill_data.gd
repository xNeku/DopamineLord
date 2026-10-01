class_name SkillData
extends Resource
## Base de todas las skills. Cada tipo de skill tiene su propia clase con los valores que le
## importan (BuffSkillData, SpinSkillData...). Las definiciones viven en data/skills/<id>.tres
## y se ajustan en el inspector.

@export var id: StringName
@export var display_name: String = ""
## Segundos de espera hasta poder volver a usarla.
@export var cooldown: float = 10.0
