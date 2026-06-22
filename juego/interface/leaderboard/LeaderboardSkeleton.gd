extends VBoxContainer

# Skeleton animado para la lista del Leaderboard.
# Colores y layout definidos en LeaderboardSkeletonRow.tscn.


@export var speed: float = 2.2
@export var desfase_fila: float = 0.45

var _time: float = 0.0
var _filas: Array[Control] = []


func _ready() -> void:
	for hijo in get_children():
		if hijo is Control:
			_filas.append(hijo as Control)


func _process(delta: float) -> void:
	_time += delta
	for i in _filas.size():
		var fila := _filas[i]
		if not is_instance_valid(fila):
			continue
		var alpha: float = 0.42 + 0.28 * sin(_time * speed + i * desfase_fila)
		fila.modulate.a = alpha
