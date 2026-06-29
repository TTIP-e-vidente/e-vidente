extends GdUnitTestSuite
class_name TestCelebracionSubidaRanking

const CelebracionScript := preload("res://interface/leaderboard/CelebracionSubidaRanking.gd")


func test_sin_puesto_despues_no_celebra() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(10, 0)
	assert_bool(bool(resultado.get("mostrar_celebracion", true))).is_false()


func test_primera_aparicion_en_ranking() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(0, 49)
	assert_bool(bool(resultado.get("mostrar_celebracion", false))).is_true()
	assert_bool(bool(resultado.get("es_primera_aparicion_en_ranking", false))).is_true()
	assert_str(str(resultado.get("mensaje_celebracion", ""))).contains("#49")


func test_entrada_al_top_50_desde_fuera() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(0, 50)
	assert_bool(bool(resultado.get("mostrar_celebracion", false))).is_true()
	assert_bool(bool(resultado.get("es_primera_aparicion_en_ranking", false))).is_true()
	assert_str(str(resultado.get("mensaje_celebracion", ""))).contains("#50")


func test_cruce_limite_top_50_mejora() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(51, 49)
	assert_bool(bool(resultado.get("mostrar_celebracion", false))).is_true()
	assert_bool(bool(resultado.get("es_primera_aparicion_en_ranking", true))).is_false()
	assert_int(int(resultado.get("cantidad_puestos_ganados", 0))).is_equal(2)
	assert_str(str(resultado.get("mensaje_celebracion", ""))).contains("2 puestos")


func test_subida_un_puesto_en_top_50() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(49, 48)
	assert_bool(bool(resultado.get("mostrar_celebracion", false))).is_true()
	assert_int(int(resultado.get("cantidad_puestos_ganados", 0))).is_equal(1)
	assert_str(str(resultado.get("mensaje_celebracion", ""))).contains("1 puesto")


func test_mismo_puesto_no_celebra() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(48, 48)
	assert_bool(bool(resultado.get("mostrar_celebracion", true))).is_false()


func test_baja_de_puesto_no_celebra() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(40, 42)
	assert_bool(bool(resultado.get("mostrar_celebracion", true))).is_false()


func test_subida_con_etiqueta_categoria() -> void:
	var resultado: Dictionary = CelebracionScript.calcular_desde_partida(
		12,
		9,
		"XP Global"
	)
	assert_str(str(resultado.get("mensaje_celebracion", ""))).contains("en XP Global")
