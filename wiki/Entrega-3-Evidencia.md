# Evidencia — Entrega 3

## Evidencia por user story

| US | Descripción | Tickets | Estado |
|---|---|---|---|
| US-01 | Infra PostgreSQL | UNQ-85, 87, 162, 161 | Listo |
| US-02 | Registro y login | UNQ-65, 171, 90, 91 | Listo |
| US-03 | Sync de progreso | UNQ-160, 163 | Listo |
| US-04 | Perfil dedicado | UNQ-107, 27 | Listo |
| US-05 | Nodo único de partida | UNQ-170 | Listo |
| US-06 | Enseñanzas JSON | UNQ-167, 168 | Listo |
| US-07 | Test UX Preguntas | UNQ-172 | Listo|
| US-08 | Borde comidas | UNQ-166 | Listo |

## Tickets Jira

| Clave | Resumen | US | Estado Jira |
|---|---|---|---|
| [UNQ-85](https://tip-unq.atlassian.net/browse/UNQ-85) | Configurar PostgreSQL local con Docker | US-01 | Terminado |
| [UNQ-87](https://tip-unq.atlassian.net/browse/UNQ-87) | Validar conexión inicial con PostgreSQL | US-01 | Terminado |
| [UNQ-162](https://tip-unq.atlassian.net/browse/UNQ-162) | Modelar entidades principales del jugador | US-01 | Terminado |
| [UNQ-161](https://tip-unq.atlassian.net/browse/UNQ-161) | Identificar datos locales críticos a migrar | US-01 | Terminado |
| [UNQ-65](https://tip-unq.atlassian.net/browse/UNQ-65) | Diseñar registro de usuario | US-02 | Terminado |
| [UNQ-171](https://tip-unq.atlassian.net/browse/UNQ-171) | Diseñar pantalla de login | US-02 | Terminado |
| [UNQ-90](https://tip-unq.atlassian.net/browse/UNQ-90) | Implementar registro de usuario | US-02 | Terminado |
| [UNQ-91](https://tip-unq.atlassian.net/browse/UNQ-91) | Implementar login de usuario | US-02 | Terminado |
| [UNQ-160](https://tip-unq.atlassian.net/browse/UNQ-160) | Migrar y sincronizar progreso local | US-03 | Terminado |
| [UNQ-163](https://tip-unq.atlassian.net/browse/UNQ-163) | Guardar resumen de partida | US-03 | Terminado |
| [UNQ-107](https://tip-unq.atlassian.net/browse/UNQ-107) | Diseñar pantalla de perfil | US-04 | Terminado |
| [UNQ-27](https://tip-unq.atlassian.net/browse/UNQ-27) | Implementar escena de perfil | US-04 | Terminado |
| [UNQ-170](https://tip-unq.atlassian.net/browse/UNQ-170) | Nodo único multi-modalidad | US-05 | Terminado |
| [UNQ-167](https://tip-unq.atlassian.net/browse/UNQ-167) | Diseñar feedback enseñanzas | US-06 | Terminado |
| [UNQ-168](https://tip-unq.atlassian.net/browse/UNQ-168) | Feedback enseñanzas JSON | US-06 | Terminado |
| [UNQ-172](https://tip-unq.atlassian.net/browse/UNQ-172) | Test UX/UI Preguntas | US-07 | Terminado |
| [UNQ-166](https://tip-unq.atlassian.net/browse/UNQ-166) | Borde blanco en comidas | US-08 | Terminado |

## Evidencia técnica en código

| Bloque | Archivos o módulos | Cómo probar |
|---|---|---|
| Docker / migraciones | `BACKEND/docker-compose.yml`, `BACKEND/migrations/` | `docker compose up -d` en `BACKEND/` |
| Auth backend | `BACKEND/src/modules/auth/` | POST register/login (curl o Postman) |
| Auth Godot | `juego/API/AuthApi.gd`, `juego/interface/auth.gd` | Intro → Registro / Login |
| Offline | flujo Intro sin backend | “Jugar sin iniciar sesión” → selector |
| Sync | `ProgressSyncService.gd`, `SyncApi.gd`, `ImportadorProgresoOnline.gd` | Jugar offline → login → verificar merge |
| Cola offline | `SaveManager.gd` | Apagar backend, terminar partida, volver a encender |
| Perfil / avatar | `BACKEND/src/modules/profile/`, overlay en mapa | Editar perfil y subir imagen con sesión |
| Nodo único | `MapBoard.gd`, JSON del mapa | Partida con ≥2 modalidades en celiaquía |
| Enseñanzas | scripts modalidad + JSON | Agregar entrada sin tocar GDScript |
| Tests Preguntas | `juego/tests/preguntas/test_modalidad_preguntas_ux_ui.gd` | GdUnit4 |
| Smoke CI | `juego/tests/vertical_slice_smoke_test.gd` | Workflow Gameplay Smoke en PR |

## Evidencia

<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/aeab8fd0-c487-41b8-8bb5-7b3a5bcb7c9b" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/b4fb34cb-135b-4f6b-a502-2ac2acfbff1a" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/d00a88c7-4167-43df-901e-21034d6689a4" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/db479355-1a62-4589-add1-3bc6f9dc5ec9" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/1491ff9e-6b3b-47cc-86c8-feb414875da3" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/cf3eff8a-2ba8-4fa1-81ae-27722dc266bc" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/b9976d3f-66fd-4c8d-be35-2522f840ac9a" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/faa91b8a-e9e6-4f11-aedb-e701efa7b0b3" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/d74345bd-f287-4480-ba69-5503d10392fc" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/f65c184f-1139-446c-8629-3c24c5b453cb" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/9b2f97f2-5e78-4393-a91e-cf4343ddad51" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/9a216368-b234-4e3e-ac62-cc049f68636e" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/b1737c62-5bdb-4528-bbaa-371984b3ef91" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/ea0d9aa4-fcb7-42b4-aa98-e2bfd3a92129" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/131d2f41-710d-41f7-b3af-1b64c5a0a2ae" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/82a6c0e1-ee56-4815-8eef-a896793360a9" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/607630a9-8bf6-4e19-94e7-943d0065e552" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/ce9307aa-134a-4e87-9f66-67fd38a7f10b" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/05145933-8e69-46d4-b20a-91201c4d316d" />
<img width="460" height="318" alt="image" src="https://github.com/user-attachments/assets/fa0c63ff-d7e3-4f1d-a9a8-9ff0b4466110" />




