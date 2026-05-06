extends Node2D

@onready var label_pregunta: Label = $Control/LabelPregunta
@onready var titulo_nivel: Label = $TituloNivel/Label

@onready var concept_item_izq: ConceptoItem = $Control/VBoxIzquierda/ConceptItemIzq
@onready var concept_item_izq_2: ConceptoItem = $Control/VBoxIzquierda/ConceptItemIzq2
@onready var concept_item_izq_3: ConceptoItem = $Control/VBoxIzquierda/ConceptItemIzq3
@onready var concept_item_der: ConceptoItem = $Control/VBoxDerecha/ConceptItemDer
@onready var concept_item_der_2: ConceptoItem = $Control/VBoxDerecha/ConceptItemDer2
@onready var concept_item_der_3: ConceptoItem = $Control/VBoxDerecha/ConceptItemDer3

var seleccion_izquierda : ConceptoItem = null
var seleccion_derecha : ConceptoItem = null

var pares_completados := 0
var total_pares := 3

func _ready() -> void:
	titulo_nivel.text = "Celiaquía"
	label_pregunta.text = "Relacioná Correctamente!"
	for item in $Control/VBoxIzquierda.get_children():
		item.seleccionado.connect(_on_item_seleccionado)

	for item in $Control/VBoxDerecha.get_children():
		item.seleccionado.connect(_on_item_seleccionado)
		
func _on_item_seleccionado(item):
	if item.lado == "izquierda":
		seleccion_izquierda = item
		resaltar(item)

	elif item.lado == "derecha":
		seleccion_derecha = item
		resaltar(item)

	validar_si_corresponde()

func validar_si_corresponde():

	if seleccion_izquierda == null:
		return

	if seleccion_derecha == null:
		return


	if seleccion_izquierda.par_id == seleccion_derecha.par_id:

		conexion_correcta()

	else:

		conexion_incorrecta()
		
func conexion_correcta():

	seleccion_izquierda.disabled = true
	seleccion_derecha.disabled = true

	seleccion_izquierda.bloqueado = true
	seleccion_derecha.bloqueado = true

	seleccion_izquierda.modulate = Color.GREEN
	seleccion_derecha.modulate = Color.GREEN

	pares_completados += 1

	limpiar_seleccion()

	if pares_completados >= total_pares:
		finalizar_modalidad()

func conexion_incorrecta():


	seleccion_izquierda.modulate = Color.RED
	seleccion_derecha.modulate = Color.RED

	await get_tree().create_timer(0.5).timeout

	seleccion_izquierda.modulate = Color.WHITE
	seleccion_derecha.modulate = Color.WHITE

	limpiar_seleccion()

func limpiar_seleccion():

	seleccion_izquierda = null
	seleccion_derecha = null
	
func resaltar(item):

	item.modulate = Color.YELLOW
	
func finalizar_modalidad():

	print("Dar XP")
	print("Guardar progreso")
	print("Ir siguiente nivel")	
