param()

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitRoot) {
        return $gitRoot.Trim()
    }

    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Assert-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Falta el directorio requerido: $Path"
    }
}

function Assert-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Falta el archivo requerido: $Path"
    }
}

$repoRoot = Resolve-RepoRoot

$requiredDirectories = @(
    'BACKEND',
    'BACKEND/src/controllers',
    'BACKEND/src/services',
    'BACKEND/src/repositories',
    'BACKEND/src/models',
    'BACKEND/src/config',
    'docs-local',
    'juego',
    'scripts/ci'
)

$requiredFiles = @(
    'BACKEND/docker-compose.yml',
    'BACKEND/.env.example',
    'BACKEND/README.md',
    'BACKEND/src/controllers/.gitkeep',
    'BACKEND/src/services/.gitkeep',
    'BACKEND/src/repositories/.gitkeep',
    'BACKEND/src/models/.gitkeep',
    'BACKEND/src/config/.gitkeep',
    'docs-local/.gitkeep',
    'juego/project.godot',
    'README.md'
)

foreach ($directory in $requiredDirectories) {
    Assert-Directory -Path (Join-Path $repoRoot $directory)
}

foreach ($file in $requiredFiles) {
    Assert-File -Path (Join-Path $repoRoot $file)
}

$trackedEnv = git -C $repoRoot ls-files 'BACKEND/.env'
if ($trackedEnv) {
    throw 'BACKEND/.env no debe quedar trackeado por git.'
}

Write-Host 'Monorepo infrastructure guardrails passed.'
