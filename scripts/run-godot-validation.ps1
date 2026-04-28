param(
    [string]$GodotCommand,
    [ValidateSet('ci', 'full', 'smoke', 'codebase', 'guardrails', 'pr-fast', 'technical')]
    [string]$Mode = 'ci',
    [switch]$IncludeExport
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitRoot) {
        return $gitRoot.Trim()
    }

    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Resolve-GodotCommand {
    param([string]$RequestedCommand)

    if ($RequestedCommand) {
        return $RequestedCommand
    }

    $candidates = @(
        'godot4.6',
        'godot',
        'godot4',
        'Godot_v4.6.2-stable_win64.exe',
        'Godot_v4.6-stable_win64.exe'
    )

    foreach ($candidate in $candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            return $command.Source
        }
    }

    throw 'No se encontro Godot CLI. Agrega `godot` o `godot4` al PATH, o pasa -GodotCommand <ruta-al-ejecutable>.'
}

function Invoke-GodotStep {
    param(
        [string]$Executable,
        [string]$Label,
        [string]$Hint,
        [string[]]$Arguments
    )

    Write-Host "`n==> $Label"
    Write-Host "Ayuda: $Hint"
    Write-Host "$Executable $($Arguments -join ' ')"
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo la validacion: $Label. $Hint"
    }
}

$repoRoot = Resolve-RepoRoot
$godotExecutable = Resolve-GodotCommand -RequestedCommand $GodotCommand

function Get-ValidationSteps {
    param([string]$ValidationMode)

    $importStep = @{ Label = 'Import headless'; Hint = 'Revisar parseo, autoloads y rutas res:// del proyecto.'; Arguments = @('--headless', '--path', 'project', '--editor', '--quit') }
    $questionJsonStep = @{ Label = 'Question JSON contract test'; Hint = 'Revisar el contrato canonical de json_nodos para preguntas y sus errores controlados.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/question_json_loader_test.gd') }
    $smokeStep = @{ Label = 'Gameplay smoke test'; Hint = 'Revisar el flujo minimo Splash -> Intro -> Selector -> Mapa -> Gameplay.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/vertical_slice_smoke_test.gd') }

    switch ($ValidationMode) {
        'codebase' { return @($importStep) }
        'guardrails' { return @($importStep) }
        'technical' { return @($importStep) }
        'smoke' { return @($importStep, $questionJsonStep, $smokeStep) }
        'ci' { return @($importStep, $questionJsonStep, $smokeStep) }
        'pr-fast' { return @($importStep, $questionJsonStep, $smokeStep) }
        'full' { return @($importStep, $questionJsonStep, $smokeStep) }
        default { throw "Modo de validacion no soportado: $ValidationMode" }
    }
}

$steps = Get-ValidationSteps -ValidationMode $Mode

Push-Location $repoRoot
try {
    foreach ($step in $steps) {
        Invoke-GodotStep -Executable $godotExecutable -Label $step.Label -Hint $step.Hint -Arguments $step.Arguments
    }

    if ($IncludeExport) {
        $buildDir = Join-Path $repoRoot 'build/web'
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        Invoke-GodotStep -Executable $godotExecutable -Label 'Web export' -Hint 'Revisar export_presets.cfg, assets del preset y salida build/web.' -Arguments @('--headless', '--verbose', '--path', 'project', '--export-release', 'index', (Join-Path $buildDir 'index.html'))
    }

    Write-Host "`nValidacion Godot completada correctamente."
}
finally {
    Pop-Location
}
