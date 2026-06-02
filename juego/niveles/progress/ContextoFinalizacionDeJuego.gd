extends RefCounted

# ContextoFinalizacionDeJuego.gd
# Arma el resumen de una partida terminada para que PostGameFlowController
# decida si sigue juego, racha, mapa o libro.

static func construir(
	fuente: String,
	clave_pista: String,
	numero_nivel: int,
	total_niveles_de_pista: int,
	es_pista_predeterminada: bool,
	viene_desde_mapa: bool,
	clave_nodo: String,
	escena_retorno: String,
	creado_por: String
) -> Dictionary:
	var valor_clave_nodo: Variant = null
	var clave_nodo_limpia: String = clave_nodo.strip_edges()
	if viene_desde_mapa and not clave_nodo_limpia.is_empty():
		valor_clave_nodo = clave_nodo_limpia

	return {
		"source": fuente,
		"level": {
			"track_key": clave_pista,
			"number": numero_nivel,
			"track_level_count": total_niveles_de_pista,
			"is_default_track": es_pista_predeterminada,
		},
		"map": {
			"came_from_map": viene_desde_mapa,
			"node_key": valor_clave_nodo,
		},
		"navigation": {
			"return_to": escena_retorno,
		},
		"debug": {
			"created_by": creado_por,
		},
	}
