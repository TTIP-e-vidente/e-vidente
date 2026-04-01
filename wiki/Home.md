# 🧠 e-vidente Wiki

**Documentacion tecnica y funcional del proyecto Godot e-vidente.**

> Un juego de puzzle educativo sobre alimentacion, restricciones alimentarias y conciencia nutricional.

---

## 🚀 Inicio rapido

| 🎯 Si necesitas | Donde ir | Tiempo |
|---|---|---|
| **Configurar entorno local** | [Getting Started](Getting-Started) | ~10 min |
| **Entender arquitectura** | [Architecture](Architecture) | ~8 min |
| **Entender el pipeline CI** | [CI](CI) | ~5 min |
| **Solucionar un problema** | [Troubleshooting](Troubleshooting) | ~5 min |
| **Ver cambios recientes** | [Bitacora](Bitacora) | ~2 min |

## 🏗️ Estructura del proyecto

```
e-vidente/
├── project/          # Juego Godot 4.2
│  ├── interface/     # Escenas y UI
│  ├── items/         # Recursos de alimentos
│  ├── niveles/       # Datos de escenarios
│  └── resources/     # Configuracion
├── wiki/             # Esta documentacion
├── .github/          # CI/CD (GitHub Actions)
└── README.md         # Overview
```

## 📋 Flujo de trabajo

1. **Branch** → Crear rama de feature/fix
2. **Develop** → Cambios en bloques pequenos
3. **Document** → Actualizar wiki si aplica
4. **Test locally** → Verificar en Godot
5. **PR** → Crear pull request
6. **CI Review** → Esperar validacion de pipeline
7. **Register** → Agregar entrada en Bitacora si es funcional

## ⚙️ Estado del proyecto

✅ **Wiki:** Activa y mantenida  
✅ **CI:** Validaciones de estructura, docs y build web  
✅ **Build:** Web export funcional  
📝 **Foco:** Cambios pequenos, trazables, bien documentados
