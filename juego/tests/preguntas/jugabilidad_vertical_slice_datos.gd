extends RefCounted
class_name EscenasVerticalSlice

const SPLASH := {
	"id": "splash",
	"ruta": "res://interface/evidente.tscn",
	"nodos": ["FondoFicha2"],
	"botones": ["go"],
}

const INTRO := {
	"id": "intro",
	"ruta": "res://niveles/intro.tscn",
	"nodos": ["FondoFicha", "MenuBar"],
	"botones": ["MenuBar/Jugar", "MenuBar/Salir"],
}

const SELECTOR := {
	"id": "selector",
	"ruta": "res://niveles/selector.tscn",
	"nodos": ["FondoFicha", "MenuBar"],
	"botones": ["MenuBar/VBoxContainer/HBoxContainer/Celiaquia", "Atrás"],
}

const MAPA := {
	"id": "mapa",
	"ruta": "res://mapas/MapScene.tscn",
	"nodos": ["MapBoard", "MapHud"],
	"botones": ["MapHud/HudRoot/BackAnchor/BackButton"],
}

const FINALIZACION := {
	"id": "finalizacion",
	"ruta": "res://mapas/finalizacion_partida.tscn",
	"nodos": ["CenterContainer/VBoxContainer/StatsContainer", "Mensaje"],
	"botones": ["Continuar"],
}

const DRAG := {
	"id": "drag",
	"ruta": "res://niveles/nivel_1/Level.tscn",
	"nodos": ["IndicadorProgresoDeJuego", "DragObjectiveText"],
	"botones": ["Atrás"],
}

const QUIZ := {
	"id": "quiz",
	"ruta": "res://preguntas/pregunta.tscn",
	"nodos": ["IndicadorProgresoDeJuego", "Contenido"],
	"botones": ["Contenido/Atrás"],
}

const MATCH := {
	"id": "match",
	"ruta": "res://vincular/VincularConceptos.tscn",
	"nodos": ["IndicadorProgresoDeJuego", "Control"],
	"botones": ["Atrás"],
}

const COMPLETAR := {
	"id": "completar",
	"ruta": "res://completar/completar_palabra.tscn",
	"nodos": ["Control/TituloNivel", "Control"],
	"botones": ["Control/ProgressBar/Atrás"],
}

const TODAS := [SPLASH, INTRO, SELECTOR, MAPA, FINALIZACION, DRAG, QUIZ, MATCH, COMPLETAR]
