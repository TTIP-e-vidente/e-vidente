$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'No se encontro un repositorio Git activo.'
}

Push-Location $repoRoot
try {
    git config core.hooksPath .githooks
    $configuredPath = git config --get core.hooksPath

    if ($configuredPath -ne '.githooks') {
        throw 'No se pudo configurar core.hooksPath en .githooks.'
    }

    Write-Host 'Hooks de Git activados desde .githooks/'
    Write-Host 'Bypass global: $env:SKIP_EVIDENTE_HOOKS=1'
    Write-Host 'Bypass puntual de engine: $env:ALLOW_GODOT_ENGINE_CHANGE=1'
} finally {
    Pop-Location
}