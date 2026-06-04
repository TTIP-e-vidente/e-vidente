class_name ContenedorEstadisticas
extends Container

@onready var panel: Panel = $Panel
@onready var numero: Label = $Imagen/Numero
@onready var imagen: TextureRect = $Imagen
@onready var icono: Sprite2D = $icono


func setear_icono(texture: Texture2D) -> void:
	if icono != null:
		icono.texture = texture
