extends Resource
class_name MiPaleta

const PRIMARY = Color("#A3D9A5")
const SECONDARY = Color("#F2C94C")
const HOVER = Color("#6FCF97")
const DISABLED = Color("#D3D3D3")
const FEEDBACK_OK      := Color(0.17, 0.49, 0.28, 1.0)  # verde
const FEEDBACK_ERROR   := Color(0.74, 0.18, 0.16, 1.0)  # rojo
const FEEDBACK_NEUTRAL := Color(0.18, 0.19, 0.21, 1.0)  # gris oscuro

# Colores Principales (Fila Superior)
@export var oro_claro: Color = Color("#dbc151")
@export var naranja_tierra: Color = Color("#db9d4b")
@export var azul_brillante: Color = Color("#4b79db")

# Colores Neutros/Oscuros (Fila Media)
@export var gris_azulado: Color = Color("#4d525c")
@export var verde_oliva_oscuro: Color = Color("#5c594d")
@export var marron_grisaceo: Color = Color("#5c554d")

# Colores de Acento (Fila Inferior)
@export var verde_bosque: Color = Color("#42785e")
@export var marron_rojizo: Color = Color("#704532")
