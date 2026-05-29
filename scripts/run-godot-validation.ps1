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
$validationSaveDir = Join-Path $repoRoot '.godot-validation-save'
New-Item -ItemType Directory -Path $validationSaveDir -Force | Out-Null
$saveFilesToPreserve = @(
    (Join-Path $env:APPDATA 'Godot\app_userdata\Evidente\save_data.json'),
    (Join-Path $env:APPDATA 'Godot\app_userdata\Evidente\save_data.tmp.json'),
    (Join-Path $env:APPDATA 'Godot\app_userdata\Evidente\save_data.backup.json')
)
$script:saveSnapshots = @{}

function Preserve-LocalSaveFiles {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            $script:saveSnapshots[$path] = @{
                Exists = $true
                Bytes = [System.IO.File]::ReadAllBytes($path)
                LastWriteTimeUtc = (Get-Item -LiteralPath $path).LastWriteTimeUtc
            }
        }
        else {
            $script:saveSnapshots[$path] = @{
                Exists = $false
                Bytes = @()
                LastWriteTimeUtc = $null
            }
        }
    }
}

function Restore-LocalSaveFiles {
    foreach ($path in $script:saveSnapshots.Keys) {
        $snapshot = $script:saveSnapshots[$path]
        if ([bool]$snapshot['Exists']) {
            $directory = Split-Path -Parent $path
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            [System.IO.File]::WriteAllBytes($path, [byte[]]$snapshot['Bytes'])
            if ($null -ne $snapshot['LastWriteTimeUtc']) {
                [System.IO.File]::SetLastWriteTimeUtc($path, $snapshot['LastWriteTimeUtc'])
            }
        }
        elseif (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

function Get-ValidationSteps {
    param(
        [string]$ValidationMode,
        [string]$RepositoryRoot
    )

    $godotBaseArgs = @('--headless', '--path', 'project')
    $importStep = @{ Label = 'Import headless'; Hint = 'Revisar parseo, autoloads y rutas res:// del proyecto.'; Arguments = $godotBaseArgs + @('--editor', '--quit') }
    $nodeJsonStep = @{ Label = 'Playable node JSON contract test'; Hint = 'Revisar el contrato canonical de nodos jugables por JSON y sus errores controlados.'; Arguments = $godotBaseArgs + @('-s', 'res://tests/node_content_loader_test.gd') }
    $planDeCorridaDeNodoStep = @{ Label = 'Plan de corrida de nodo'; Hint = 'Revisar la regla 1,1,2,3,4,5 y la alternancia simple por nodo.'; Arguments = $godotBaseArgs + @('-s', 'res://tests/plan_de_corrida_de_nodo_test.gd') }
    $indicadorProgresoPreguntaStep = @{ Label = 'Indicador de progreso en pregunta'; Hint = 'Revisar que pregunta.tscn muestre Juego 1/1 y el titulo del nodo en partida normal.'; Arguments = $godotBaseArgs + @('-s', 'res://tests/indicador_progreso_pregunta_test.gd') }
    $indicadorProgresoNivelStep = @{ Label = 'Indicador de progreso en nivel'; Hint = 'Revisar que Level.tscn muestre Juego 1/1 y el titulo del nodo en partida normal.'; Arguments = $godotBaseArgs + @('-s', 'res://tests/indicador_progreso_nivel_test.gd') }
    $postGameFlowStep = @{ Label = 'Post-game flow controller test'; Hint = 'Revisar las decisiones de post-partida para racha, mapa y siguiente nodo.'; Arguments = $godotBaseArgs + @('-s', 'res://tests/post_game_flow_controller_test.gd') }
    $mapProgressVisualStep = @{ Label = 'Map progress visual test'; Hint = 'Revisar contrato del mapa de celiaquia, estados visuales y desbloqueo del siguiente nodo.'; Arguments = $godotBaseArgs + @('-s', 'res://tests/map_progress_visual_test.gd') }
    $flujoProgresivoDeNodoStep = @{ Label = 'Flujo progresivo de nodo'; Hint = 'Revisar los casos de nodos 1 a 6 con apertura directa, indicador y vuelta al mapa.'; Arguments = $godotBaseArgs + @('-s', 'res://tests/flujo_progresivo_de_nodo_test.gd') }
    $smokeStep = @{ Label = 'Gameplay smoke test'; Hint = 'Revisar el flujo minimo Splash -> Intro -> Selector -> Mapa -> Gameplay.'; Arguments = $godotBaseArgs + @('--fixed-fps', '60', '-s', 'res://tests/vertical_slice_smoke_test.gd') }

    $hasNodeJsonTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/node_content_loader_test.gd')
    $hasPlanDeCorridaDeNodoTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/plan_de_corrida_de_nodo_test.gd')
    $hasIndicadorProgresoPreguntaTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/indicador_progreso_pregunta_test.gd')
    $hasIndicadorProgresoNivelTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/indicador_progreso_nivel_test.gd')
    $hasPostGameFlowTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/post_game_flow_controller_test.gd')
    $hasMapProgressVisualTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/map_progress_visual_test.gd')
    $hasFlujoProgresivoDeNodoTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/flujo_progresivo_de_nodo_test.gd')
    $hasSmokeTest = Test-Path (Join-Path $RepositoryRoot 'project/tests/vertical_slice_smoke_test.gd')

    $smokeSuite = @($importStep)
    if ($hasNodeJsonTest) {
        $smokeSuite += $nodeJsonStep
    }
    if ($hasPlanDeCorridaDeNodoTest) {
        $smokeSuite += $planDeCorridaDeNodoStep
    }
    if ($hasIndicadorProgresoPreguntaTest) {
        $smokeSuite += $indicadorProgresoPreguntaStep
    }
    if ($hasIndicadorProgresoNivelTest) {
        $smokeSuite += $indicadorProgresoNivelStep
    }
    if ($hasPostGameFlowTest) {
        $smokeSuite += $postGameFlowStep
    }
    if ($hasMapProgressVisualTest) {
        $smokeSuite += $mapProgressVisualStep
    }
    if ($hasFlujoProgresivoDeNodoTest) {
        $smokeSuite += $flujoProgresivoDeNodoStep
    }
    if ($hasSmokeTest) {
        $smokeSuite += $smokeStep
    }

    switch ($ValidationMode) {
        'codebase' { return @($importStep) }
        'guardrails' { return @($importStep) }
        'technical' { return @($importStep) }
        'smoke' { return $smokeSuite }
        'ci' { return $smokeSuite }
        'pr-fast' { return $smokeSuite }
        'full' { return $smokeSuite }
        default { throw "Modo de validacion no soportado: $ValidationMode" }
    }
}

$steps = Get-ValidationSteps -ValidationMode $Mode -RepositoryRoot $repoRoot

Push-Location $repoRoot
try {
    Preserve-LocalSaveFiles -Paths $saveFilesToPreserve
    $previousValidationSaveDir = $env:EVIDENTE_SAVE_DIR
    $env:EVIDENTE_SAVE_DIR = $validationSaveDir
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
    if ($null -ne $previousValidationSaveDir) {
        $env:EVIDENTE_SAVE_DIR = $previousValidationSaveDir
    }
    else {
        Remove-Item Env:EVIDENTE_SAVE_DIR -ErrorAction SilentlyContinue
    }
    Restore-LocalSaveFiles
    Pop-Location
}
