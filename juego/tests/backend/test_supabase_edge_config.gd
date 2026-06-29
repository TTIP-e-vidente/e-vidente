extends GdUnitTestSuite
class_name TestSupabaseEdgeConfig


func test_supabase_edge_client_arma_url_auth_login() -> void:
	BackendConfig.recargar()
	var functions_url := BackendConfig.obtener_supabase_functions_url()
	if functions_url.is_empty():
		assert_bool(false).override_failure_message(
			"Falta supabase_functions_url en backend.local.json. Corré: npm run sync:godot-config:staging"
		).is_true()
		return

	var client := SupabaseEdgeClient.new()
	assert_str(client.armar_url("auth-login")).is_equal(functions_url + "/auth-login")
	client.free()


func test_backend_config_modo_edge() -> void:
	BackendConfig.recargar()
	if not BackendConfig.es_modo_supabase_edge():
		assert_bool(false).override_failure_message(
			"api_mode no es supabase_edge en backend.local.json. Corré: npm run sync:godot-config:staging"
		).is_true()
		return

	var api_base := BackendConfig.obtener_api_base_url()
	assert_bool(api_base.is_empty()).is_false()
	assert_bool(api_base.ends_with("/functions/v1")).is_true()
	assert_bool(BackendConfig.edge_listo_para_usar()).is_true()
