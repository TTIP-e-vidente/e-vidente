extends Node

var niveles_desbloqueados := {
	1: true,
	2: false,
	3: false
}

func desbloquear(nivel_id):
	niveles_desbloqueados[nivel_id] = true

func esta_desbloqueado(nivel_id):
	return niveles_desbloqueados.get(nivel_id, false)
