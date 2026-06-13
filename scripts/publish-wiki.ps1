param(
    [string]$Owner = "TTIP-e-vidente",
    [string]$Repo = "e-vidente",
    [string]$Message = "Initialize wiki starter",
    [string]$Username = "agusdiisanto"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$wikiSource = Join-Path $root "wiki"

if (-not (Test-Path $wikiSource)) {
    throw "No se encontro la carpeta wiki en $wikiSource"
}

$wikiUrl = "https://$Username@github.com/$Owner/$Repo.wiki.git"
$tmpPath = Join-Path $env:TEMP ("wiki-init-" + [guid]::NewGuid().ToString())

Write-Host "Clonando wiki en: $tmpPath"

git clone $wikiUrl $tmpPath | Out-Host
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmpPath)) {
    throw "No se pudo clonar la wiki. Verifica que este habilitada en GitHub Settings > Features > Wikis. URL: $wikiUrl"
}

# Borrar todo excepto .git para hacer un mirror limpio
Get-ChildItem -Path $tmpPath -Exclude ".git" | Remove-Item -Recurse -Force

# Copiar el contenido local completo
Copy-Item -Path (Join-Path $wikiSource "*") -Destination $tmpPath -Recurse -Force

Push-Location $tmpPath
try {
    git add -A
    $status = git status --porcelain

    if (-not $status) {
        Write-Host "No hay cambios para publicar en la wiki."
        exit 0
    }

    git commit -m $Message | Out-Host
    git push origin HEAD | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Error al hacer push a la wiki ($LASTEXITCODE). Verificá permisos en $wikiUrl"
    }
    Write-Host "Wiki publicada correctamente en $wikiUrl"
    Write-Host ""
    Write-Host "Vistas interactivas (raw.githack, ~1 min de cache):"
    Write-Host "  https://raw.githack.com/$Owner/$Repo/dev/wiki/mer.html?v=4"
    Write-Host "Indice wiki: https://github.com/$Owner/$Repo/wiki/Vistas-Interactivas"
}
finally {
    Pop-Location
    Remove-Item -Path $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
}