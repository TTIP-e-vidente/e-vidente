param(
    [string]$GodotCommand,
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

$steps = @(
    @{ Label = 'Import headless'; Hint = 'Revisar errores de parseo, rutas res:// o autoloads.'; Arguments = @('--headless', '--path', 'project', '--editor', '--quit') },
    @{ Label = 'Content catalog validation test'; Hint = 'Revisar integridad del catalogo de tracks, capitulos, corridas y recursos referenciados.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/content_catalog_validation_test.gd') },
    @{ Label = 'Save manager smoke test'; Hint = 'Revisar persistencia minima y carga inicial de SaveManager.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_smoke_test.gd') },
    @{ Label = 'Save manager validation test'; Hint = 'Revisar perfil local, validacion de datos y escritura/lectura de SaveManager.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_validation_test.gd') },
    @{ Label = 'Save manager signal contract test'; Hint = 'Revisar nombres de señales, payloads y puntos de emision.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_signal_contract_test.gd') },
    @{ Label = 'Save manager legacy migration test'; Hint = 'Revisar migracion de saves legacy, session activa y resume_state.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_legacy_migration_test.gd') },
    @{ Label = 'Archivero overlay test'; Hint = 'Revisar nodos, visibilidad y callbacks del overlay de perfil.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/archivero_overlay_test.gd') },
    @{ Label = 'Intro menu profile test'; Hint = 'Revisar flujo de Intro para perfil, continuar y navegacion.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/intro_menu_profile_test.gd') },
    @{ Label = 'Level quick save test'; Hint = 'Revisar quick save, restauracion parcial y UI de guardado en nivel.'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/level_quick_save_test.gd') }
)

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