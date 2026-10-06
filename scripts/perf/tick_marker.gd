extends Node
## Marca el principio o el final del tick de física para PerfOverlay (ver allí).

var callback: Callable


func _physics_process(_delta: float) -> void:
	callback.call()
