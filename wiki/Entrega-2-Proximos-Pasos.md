# Próximos Pasos
## Para Entrega 3

Consolidado el polish visual, las modalidades principales y la primera infraestructura de tests, la Entrega 3 se enfoca en **implementar el backend**: registro, login, perfil de usuario, persistencia remota de progreso y tabla de posiciones. La base técnica ya está disponible (PostgreSQL con Docker, conexión validada, modelo inicial de persistencia).

---

## Historias pendientes de la Entrega 2

Estas historias quedaron abiertas al cierre de la entrega y serán arrastradas a Entrega 3:

| ID | Tarea | Estado actual |
|----|-------|--------------|
| UNQ-147 | Animar Escena Mapa | EN PROGRESO |
| UNQ-142 | Implementar Mensaje de Plato con tipo de comida y restricción | EN PROGRESO |
| UNQ-158 | Agregar test de carga de JSON y validación de opciones | EN PROGRESO |
| UNQ-150 | Animar los textos a Typewriter Effect en Arrastre | REVISIÓN |
| UNQ-155 | Animar los textos a Typewriter Effect en Preguntas | REVISIÓN |
| UNQ-152 | Implementar el JSON de la modalidad opciones de palabras | REVISIÓN |
| UNQ-144 | Animar Modalidad Preguntas | REVISIÓN |
| UNQ-145 | Animar Modalidad Arrastre | REVISIÓN |
| UNQ-143 | Animar Modalidad Vinculaciones | REVISIÓN |

---

## Implementar el Backend

Construir la infraestructura de usuarios, autenticación y persistencia remota. Habilita progreso multi-dispositivo y funcionalidades sociales.

> Base ya disponible: UNQ-85 (PostgreSQL con Docker), UNQ-87 (conexión validada), UNQ-86 (modelo inicial de persistencia) ✓

| ID | Tarea |
|----|-------|
| UNQ-90 | Implementar registro de usuario |
| UNQ-91 | Implementar login de usuario |
| UNQ-27 | Implementar escena de perfil de usuario |
| UNQ-69 | Implementar cambio de contraseña del usuario |
| UNQ-96 | Implementar tabla de posiciones global |
| UNQ-64 | Implementar notificaciones por email para racha diaria en riesgo |

---

## Deuda técnica

| Tema | Descripción |
|---|---|
| Persistencia local completa | El guardado de progreso local entre sesiones no está completamente cerrado |
| Ampliar cobertura de tests | GdUnit4 cubre solo el pipeline de preguntas; modalidades Arrastre, Vincular y Completar Palabra no tienen tests |
| Perfil del usuario | La pantalla de perfil aún no está implementada |
