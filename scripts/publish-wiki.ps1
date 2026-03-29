param(
    [string]$Owner = "TTIP-e-vidente",
    [string]$Repo = "e-vidente",
    [string]$Message = "Initialize wiki starter"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$wikiSource = Join-Path $root "wiki"

if (-not (Test-Path $wikiSource)) {
    throw "No se encontro la carpeta wiki en $wikiSource"
}

$wikiUrl = "https://github.com/$Owner/$Repo.wiki.git"
$tmpPath = Join-Path $env:TEMP ("wiki-init-" + [guid]::NewGuid().ToString())

Write-Host "Clonando wiki en: $tmpPath"

git clone $wikiUrl $tmpPath | Out-Host
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmpPath)) {
    throw "No se pudo clonar la wiki. Verifica que este habilitada en GitHub Settings > Features > Wikis. URL: $wikiUrl"
}

Copy-Item -Path (Join-Path $wikiSource "*") -Destination $tmpPath -Recurse -Force

Push-Location $tmpPath
try {
    git add .
    $status = git status --porcelain

    if (-not $status) {
        Write-Host "No hay cambios para publicar en la wiki."
        exit 0
    }

    git commit -m $Message | Out-Host
    git push origin HEAD | Out-Host
    Write-Host "Wiki publicada correctamente en $wikiUrl"
}
finally {
    Pop-Location
    Remove-Item -Path $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
}