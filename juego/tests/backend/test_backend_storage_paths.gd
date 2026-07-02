extends GdUnitTestSuite
class_name TestBackendStoragePaths


func test_storage_namespace_no_esta_vacio() -> void:
	BackendConfig.recargar()
	assert_str(BackendConfig.obtener_storage_namespace()).is_not_empty()


func test_user_path_se_aisla_por_namespace() -> void:
	BackendConfig.recargar()
	var espacio_nombres := BackendStoragePaths.obtener_namespace()
	var resolved := BackendStoragePaths.resolver("user://save_data.json")
	assert_str(resolved).starts_with("user://")
	if espacio_nombres != BackendStoragePaths.DEFAULT_NAMESPACE:
		assert_str(resolved).contains("/save_data.json")
		assert_str(resolved).contains(espacio_nombres)
