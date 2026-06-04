#!/usr/bin/env python3
"""Renombra identificadores de funciones en archivos .gd del proyecto."""
from __future__ import annotations

import sys
from pathlib import Path

# Orden: nombres más largos primero para evitar reemplazos parciales.
REPLACEMENTS: list[tuple[str, str]] = [
    ("get_all_completed_activity_ids", "obtener_todos_ids_actividades_completadas"),
    ("get_all_used_activity_ids", "obtener_todos_ids_actividades_usadas"),
    ("get_completed_activity_ids", "obtener_ids_actividades_completadas"),
    ("get_played_activity_ids", "obtener_ids_actividades_jugadas"),
    ("mark_activity_completed", "marcar_actividad_completada"),
    ("mark_activity_played", "marcar_actividad_jugada"),
    ("reset_completed_activity_pool", "reiniciar_pool_actividades_completadas"),
    ("debug_clear_completed_activity_history", "depurar_limpiar_historial_actividades"),
    ("get_node_best_accuracy", "obtener_mejor_precision_nodo"),
    ("get_node_progress_entry", "obtener_entrada_progreso_nodo"),
    ("get_all_node_progress", "obtener_todo_progreso_nodos"),
    ("save_node_accuracy", "guardar_precision_nodo"),
    ("get_ranking_position", "obtener_posicion_ranking"),
    ("get_total_exp", "obtener_exp_total"),
    ("init_with_save_manager", "inicializar_con_save_manager"),
    ("reset_session_history", "reiniciar_historial_sesion"),
    ("change_normal_scene", "cambiar_escena_normal"),
    ("change_scene", "cambiar_escena"),
    ("transition_to_scene", "transicionar_a_escena"),
    ("go_to_route", "ir_a_ruta"),
    ("go_to_map", "ir_al_mapa"),
    ("go_to_streak", "ir_a_racha"),
    ("go_to_resume", "ir_a_reanudar"),
    ("get_scene_path_for_mode", "obtener_ruta_escena_por_modo"),
    ("read_return_to", "leer_retorno_a"),
    ("read_streak_return_to", "leer_retorno_racha"),
    ("set_streak_return_to", "establecer_retorno_racha"),
    ("consume_streak_return_to", "consumir_retorno_racha"),
    ("build_post_game_flow_state", "construir_estado_flujo_post_juego"),
    ("resolve_post_teaching_flow", "resolver_flujo_post_ensenanza"),
    ("navigate_after_teaching", "navegar_despues_ensenanza"),
    ("navigate_after_streak", "navegar_despues_racha"),
    ("consume_flow_state", "consumir_estado_flujo"),
    ("view_model", "modelo_vista"),
    ("build_feedback", "construir_feedback"),
    ("configure_for_track", "configurar_para_pista"),
    ("refresh_profile_icon", "refrescar_icono_perfil"),
    ("set_completed", "establecer_completado"),
    ("set_progress", "establecer_progreso"),
    ("set_weekly_data", "establecer_datos_semanales"),
    ("set_objective", "establecer_objetivo"),
    ("load_catalog", "cargar_catalogo"),
    ("resolve_item_definition", "resolver_definicion_item"),
    ("create_runtime_game", "crear_juego_runtime"),
    ("sample_drag_pool_ids", "muestrear_ids_pool_arrastre"),
    ("load_from_context", "cargar_desde_contexto"),
    ("load_activity", "cargar_actividad"),
    ("get_activity_candidates", "obtener_candidatos_actividad"),
    ("get_activity", "obtener_actividad"),
    ("filter_uncompleted_content", "filtrar_contenido_incompleto"),
    ("to_legacy_node", "a_nodo_legado"),
    ("load_json", "cargar_json"),
    ("validate_activity_ids", "validar_ids_actividad"),
    ("filter_uncompleted", "filtrar_incompletos"),
    ("get_stats", "obtener_estadisticas"),
    ("get_precision", "obtener_precision"),
    ("get_duration_formatted", "obtener_duracion_formateada"),
    ("calculate_precision", "calcular_precision"),
    ("calculate_final_exp", "calcular_exp_final"),
    ("get_exp_for_difficulty", "obtener_exp_por_dificultad"),
    ("format_duration", "formatear_duracion"),
    ("add_exp", "sumar_exp"),
    ("reset_state", "reiniciar_estado"),
    ("set_selected", "marcar_seleccionado"),
    ("set_correct", "marcar_correcto"),
    ("set_wrong", "marcar_incorrecto"),
    ("dodge_button", "esquivar_boton"),
    ("_get_save_manager", "_obtener_save_manager"),
    ("_get_right_anchor", "_obtener_ancla_derecha"),
    ("_get_left_anchor", "_obtener_ancla_izquierda"),
    ("_get_title", "_obtener_titulo"),
    ("_is_button_disabled", "_boton_esta_deshabilitado"),
    ("_apply_state_color", "_aplicar_color_estado"),
    ("_apply_progress_state", "_aplicar_estado_progreso"),
    ("_apply_legacy_progress_state", "_aplicar_estado_progreso_legado"),
    ("_resolve_visual_state_name", "_resolver_nombre_estado_visual"),
    ("_sanitize_visual_state", "_sanitizar_estado_visual"),
    ("_refresh_badge", "_actualizar_insignia"),
    ("_animate_click", "_animar_click"),
    ("_finish_streak_flow", "_finalizar_flujo_racha"),
    ("_return_from_streak", "_volver_desde_racha"),
    ("_has_post_game_flow_state", "_tiene_estado_flujo_post_juego"),
    ("_take_post_game_flow_state", "_tomar_estado_flujo_post_juego"),
    ("_return_to_map_scene", "_volver_a_escena_mapa"),
    ("_read_playable_json_path", "_leer_ruta_json_jugable"),
    ("_on_button_pressed", "_on_boton_presionado"),
    ("_on_button_mouse_entered", "_on_boton_mouse_entrado"),
    ("_on_button_mouse_exited", "_on_boton_mouse_salido"),
    ("_on_profile_button_pressed", "_on_boton_perfil_presionado"),
    ("_on_back_button_pressed", "_on_boton_atras_presionado"),
    ("_on_overlay_save_pressed", "_on_superposicion_guardar_presionado"),
    ("_on_continuar_pressed", "_on_continuar_presionado"),
    ("_on_atras_pressed", "_on_atras_presionado"),
    ("_on_jugar_nuevamente_pressed", "_on_jugar_nuevamente_presionado"),
    ("_on_button_submit_pressed", "_on_boton_enviar_presionado"),
    ("_on_password_submitted", "_on_clave_enviada"),
    ("_on_session_restored", "_on_sesion_restaurada"),
    ("_on_session_restore_failed", "_on_fallo_restauracion_sesion"),
    ("_on_button_switch_mode_pressed", "_on_boton_cambiar_modo_presionado"),
    ("_on_button_play_offline_pressed", "_on_boton_jugar_offline_presionado"),
    ("_on_login_completed", "_on_login_completado"),
    ("_on_play_offline_requested", "_on_jugar_offline_solicitado"),
    ("_on_jugar_pressed", "_on_jugar_presionado"),
    ("_mostrar_profile", "_mostrar_perfil"),
    ("_on_login_succeeded", "_on_login_exitoso"),
    ("_on_login_failed", "_on_login_fallido"),
    ("_on_sync_succeeded", "_on_sync_exitosa"),
    ("_on_sync_failed", "_on_sync_fallida"),
    ("_on_session_expired", "_on_sesion_expirada"),
    ("_on_logout_completed", "_on_cierre_sesion_completado"),
    ("_on_return_button_pressed", "_on_boton_volver_presionado"),
    ("record", "registrar"),
    ("_initialize", "_inicializar"),
    ("_wait_for", "_esperar_a"),
    ("_go_to", "_ir_a"),
    ("_check", "_verificar"),
    ("finalizar_ok", "finalizar_correctamente"),
    ("test_fixture_json_se_puede_abrir", "probar_fixture_json_se_puede_abrir"),
    ("test_carga_retorna_ok", "probar_carga_retorna_ok"),
    ("is_v1_content", "es_contenido_v1"),
    ("is_supported_map_mode", "es_modo_mapa_soportado"),
]

TSCN_REPLACEMENTS: list[tuple[str, str]] = [
    ('method="_on_button_pressed"', 'method="_on_boton_presionado"'),
    ('method="_on_button_mouse_entered"', 'method="_on_boton_mouse_entrado"'),
    ('method="_on_button_mouse_exited"', 'method="_on_boton_mouse_salido"'),
    ('method="_on_profile_button_pressed"', 'method="_on_boton_perfil_presionado"'),
    ('method="_on_back_button_pressed"', 'method="_on_boton_atras_presionado"'),
    ('method="_on_overlay_save_pressed"', 'method="_on_superposicion_guardar_presionado"'),
    ('method="_on_continuar_pressed"', 'method="_on_continuar_presionado"'),
    ('method="_on_atras_pressed"', 'method="_on_atras_presionado"'),
    ('method="_on_jugar_nuevamente_pressed"', 'method="_on_jugar_nuevamente_presionado"'),
    ('method="_on_jugar_pressed"', 'method="_on_jugar_presionado"'),
    ('method="_on_return_button_pressed"', 'method="_on_boton_volver_presionado"'),
]


SKIP_PARTS = {"addons", "tools"}


def should_skip(path: Path) -> bool:
    return any(part in SKIP_PARTS for part in path.parts)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    changed_files: list[Path] = []
    for path in root.rglob("*.gd"):
        if should_skip(path):
            continue
        if path.name == Path(__file__).name:
            continue
        text = path.read_text(encoding="utf-8")
        original = text
        for old, new in REPLACEMENTS:
            text = text.replace(old, new)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed_files.append(path)
    for path in root.rglob("*.tscn"):
        if should_skip(path):
            continue
        text = path.read_text(encoding="utf-8")
        original = text
        for old, new in TSCN_REPLACEMENTS:
            text = text.replace(old, new)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed_files.append(path)
    print(f"Actualizados {len(changed_files)} archivos .gd")
    return 0


if __name__ == "__main__":
    sys.exit(main())
