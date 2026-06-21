class_name CelebracionSubidaRanking
extends RefCounted

# Compara dos posiciones del ranking y decide si mostrar una celebración.
#
# Importante para entender el ranking:
# - Puesto #1 es el mejor (más arriba en la tabla).
# - Un número de puesto MÁS BAJO significa que mejoraste.
#   Ejemplo: de #8 a #5 → subiste 3 puestos.


const PUESTO_NO_REGISTRADO := 0


static func calcular_desde_partida(
	puesto_antes_de_jugar: int,
	puesto_despues_de_jugar: int,
	etiqueta_categoria_ranking: String = ""
) -> Dictionary:
	var resultado_vacio := _crear_resultado_vacio()

	if puesto_despues_de_jugar <= PUESTO_NO_REGISTRADO:
		return resultado_vacio

	var tenia_puesto_antes := puesto_antes_de_jugar > PUESTO_NO_REGISTRADO
	var sufijo_categoria := _formatear_sufijo_categoria(etiqueta_categoria_ranking)

	if not tenia_puesto_antes:
		return {
			"mostrar_celebracion": true,
			"es_primera_aparicion_en_ranking": true,
			"cantidad_puestos_ganados": 0,
			"mensaje_celebracion": "¡Entraste al ranking en puesto #%d%s!" % [
				puesto_despues_de_jugar,
				sufijo_categoria
			],
		}

	if puesto_despues_de_jugar >= puesto_antes_de_jugar:
		return resultado_vacio

	var puestos_ganados := puesto_antes_de_jugar - puesto_despues_de_jugar
	var mensaje_un_puesto := "¡Subiste 1 puesto en el ranking%s!" % sufijo_categoria
	var mensaje_varios_puestos := "¡Subiste %d puestos en el ranking%s!" % [
		puestos_ganados,
		sufijo_categoria
	]

	return {
		"mostrar_celebracion": true,
		"es_primera_aparicion_en_ranking": false,
		"cantidad_puestos_ganados": puestos_ganados,
		"mensaje_celebracion": mensaje_un_puesto if puestos_ganados == 1 else mensaje_varios_puestos,
	}


static func _crear_resultado_vacio() -> Dictionary:
	return {
		"mostrar_celebracion": false,
		"es_primera_aparicion_en_ranking": false,
		"cantidad_puestos_ganados": 0,
		"mensaje_celebracion": "",
	}


static func _formatear_sufijo_categoria(etiqueta_categoria_ranking: String) -> String:
	var etiqueta_limpia := etiqueta_categoria_ranking.strip_edges()
	if etiqueta_limpia.is_empty():
		return ""
	return " en %s" % etiqueta_limpia
