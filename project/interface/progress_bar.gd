extends Control


@onready var barra: ProgressBar = $"Progress-game"

var total_objetivos 
var completados 
var tween = create_tween()

func _ready() -> void:
	pass

func configurar(total: int, hechos: int):

	total_objetivos = total
	completados = hechos

	actualizar_barra()

func actualizar_barra():

	var progreso = float(completados) / float(total_objetivos)

	barra.value = progreso * 100
	tween.tween_property(
	barra,
	"value",
	progreso * 100,
	0.5
)
