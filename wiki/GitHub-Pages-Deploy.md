# 📡 GitHub Pages Deployment

Documentacion sobre configuracion y troubleshooting del deploy automatico a GitHub Pages.

---

## 🔍 Estado Actual

**Ultimo deployment:** Failed  
**Razon:** Condicion no cumplida: `vars.ENABLE_PAGES_DEPLOY != 'true'`

---

## 📋 Opciones

### Opcion 1: Desactivar Pages Deploy (Recomendado por ahora)

Si **no necesitas** GitHub Pages (la wiki local en `/wiki/` es suficiente):

```bash
# Editar .github/workflows/ci.yml
# Eliminar el job completo deploy-pages (lineas ~384-400)
```

**Beneficios:**
- Pipeline mas simple
- Menos dependencias
- Wiki local en GitHub es suficiente

**Acciones:**
1. Editar `.github/workflows/ci.yml`
2. Borrar job `deploy-pages` completo
3. Commit + push

---

### Opcion 2: Habilitar Pages Deploy (Avanzado)

Si **querés** que GitHub auto-publique web build en `https://TTIP-e-vidente.github.io/e-vidente/`:

**Paso 1:** Crear variable de repositorio
1. GitHub → [tu repo] → Settings → Secrets and variables → **Variables**
2. New repository variable
3. Name: `ENABLE_PAGES_DEPLOY`
4. Value: `true`

**Paso 2:** Configurar GitHub Pages
1. GitHub → [tu repo] → Settings → Pages
2. Source: Deploy from a branch
3. Branch: `gh-pages`
4. Folder: `/ (root)`

**Paso 3:** Verificar workflow

El workflow ya tiene:
```yaml
if: github.ref == 'refs/heads/main' && 
    needs.build-web.result == 'success' && 
    vars.ENABLE_PAGES_DEPLOY == 'true'
```

Con esos 3 requisitos cumplidos, el deploy ocurre automaticamente.

**Beneficios:**
- Web build accessible publicamente
- Auto-update en cada push a main
- URL limpia

---

## ⚡ Recomendacion Inmediata

**Simplificar:**
- Remover el job `deploy-pages` del workflow
- Mantener la wiki en GitHub como documentacion principal
- Si en el futuro necesitas web publico, agregar Pages entonces

Esto resuelve los 2 failed deployments que ves.

---

## 🔧 Cambios necesarios

**File:** `.github/workflows/ci.yml`

**Eliminar:**
```yaml
  deploy-pages:
    name: Deploy to GitHub Pages
    runs-on: ubuntu-latest
    needs: build-web
    if: github.ref == 'refs/heads/main' && needs.build-web.result == 'success' && vars.ENABLE_PAGES_DEPLOY == 'true'
    timeout-minutes: 10
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    steps:
      - name: Deploy
        id: deployment
        uses: actions/deploy-pages@v4
```

Luego el job `build-web` tampoco necesita el paso `Prepare GitHub Pages artifact`:

```yaml
# REMOVER:
      - name: Prepare GitHub Pages artifact
        if: github.ref == 'refs/heads/main'
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web
```

**Result:** Workflow mas limpio, sin failed deployments.

---

## 📞 Siguiente paso

**Querés que lo haga?** Puedo editar el workflow para remover el Pages deploy y limpiar la configuracion.
