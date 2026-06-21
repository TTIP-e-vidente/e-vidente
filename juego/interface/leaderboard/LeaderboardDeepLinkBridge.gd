extends Node

# Autoload: captura deep links al iniciar y abre el ranking en escenas jugables.


func _ready() -> void:
	LeaderboardDeepLinkHelper.registrar_solicitud_desde_arranque_del_sistema()


func procesar_en_escena_actual(nodo_escena: Node) -> void:
	LeaderboardDeepLinkHelper.abrir_leaderboard_si_hay_solicitud_pendiente(nodo_escena)
