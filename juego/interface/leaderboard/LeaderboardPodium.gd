class_name LeaderboardPodium
extends Control

# Podio visual con los tres primeros puestos (#2 | #1 | #3).


@onready var _slot_segundo: LeaderboardPodiumSlot = %SlotSegundo
@onready var _slot_primero: LeaderboardPodiumSlot = %SlotPrimero
@onready var _slot_tercero: LeaderboardPodiumSlot = %SlotTercero


func _ready() -> void:
	if not LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.connect(_al_avatar_cargado)


func _exit_tree() -> void:
	if LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.disconnect(_al_avatar_cargado)


func limpiar() -> void:
	if is_instance_valid(_slot_segundo):
		_slot_segundo.limpiar()
	if is_instance_valid(_slot_primero):
		_slot_primero.limpiar()
	if is_instance_valid(_slot_tercero):
		_slot_tercero.limpiar()
	visible = false


func poblar(entradas: Array, scope: String, id_propio: String) -> void:
	var por_rank: Dictionary = {}
	for entrada in entradas:
		if entrada is Dictionary:
			var rank := int((entrada as Dictionary).get("rank", 0))
			if rank >= 1 and rank <= 3:
				por_rank[rank] = entrada

	visible = not por_rank.is_empty()
	if not visible:
		limpiar()
		return

	if is_instance_valid(_slot_segundo):
		if por_rank.has(2):
			_slot_segundo.poblar(por_rank[2], _es_propio(por_rank[2], id_propio), scope)
		else:
			_slot_segundo.limpiar()
	if is_instance_valid(_slot_primero):
		if por_rank.has(1):
			_slot_primero.poblar(por_rank[1], _es_propio(por_rank[1], id_propio), scope)
		else:
			_slot_primero.limpiar()
	if is_instance_valid(_slot_tercero):
		if por_rank.has(3):
			_slot_tercero.poblar(por_rank[3], _es_propio(por_rank[3], id_propio), scope)
		else:
			_slot_tercero.limpiar()


func _es_propio(entrada: Dictionary, id_propio: String) -> bool:
	if id_propio.is_empty():
		return false
	return str(entrada.get("user_id", "")) == id_propio


func refrescar_avatar_si_coincide(user_id: String) -> void:
	for slot in [_slot_segundo, _slot_primero, _slot_tercero]:
		if is_instance_valid(slot):
			slot.refrescar_avatar_si_coincide(user_id)


func _al_avatar_cargado(user_id: String, _texture: Texture2D) -> void:
	refrescar_avatar_si_coincide(user_id)
