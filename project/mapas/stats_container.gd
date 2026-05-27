# Componente visual: muestra un stat (imagen + número). No calcula nada.
extends Control
@onready var panel: Panel = $Panel
@onready var numero: Label = $Imagen/Numero
@onready var imagen: TextureRect = $Imagen
@onready var icono: Sprite2D = $icono

func _ready():
	pass
	

func _setear_icono(texture : Texture2D) -> void:
	icono.texture = texture
