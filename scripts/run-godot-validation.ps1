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
        'godot',
        'godot4',
        'godot4.2',
        'Godot_v4.2-stable_win64.exe'
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
        [string[]]$Arguments
    )

    Write-Host "`n==> $Label"
    Write-Host "$Executable $($Arguments -join ' ')"
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo la validacion: $Label"
    }
}

$repoRoot = Resolve-RepoRoot
$godotExecutable = Resolve-GodotCommand -RequestedCommand $GodotCommand

$steps = @(
    @{ Label = 'Import headless'; Arguments = @('--headless', '--path', 'project', '--editor', '--quit') },
    @{ Label = 'Save manager smoke test'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_smoke_test.gd') },
    @{ Label = 'Save manager validation test'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_validation_test.gd') },
    @{ Label = 'Save manager signal contract test'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_signal_contract_test.gd') },
    @{ Label = 'Save manager legacy migration test'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/save_manager_legacy_migration_test.gd') },
    @{ Label = 'Archivero overlay test'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/archivero_overlay_test.gd') },
    @{ Label = 'Intro menu profile test'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/intro_menu_profile_test.gd') },
    @{ Label = 'Level quick save test'; Arguments = @('--headless', '--path', 'project', '-s', 'res://tests/level_quick_save_test.gd') }
)

Push-Location $repoRoot
try {
    foreach ($step in $steps) {
        Invoke-GodotStep -Executable $godotExecutable -Label $step.Label -Arguments $step.Arguments
    }

    if ($IncludeExport) {
        $buildDir = Join-Path $repoRoot 'build/web'
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        Invoke-GodotStep -Executable $godotExecutable -Label 'Web export' -Arguments @('--headless', '--verbose', '--path', 'project', '--export-release', 'index', (Join-Path $buildDir 'index.html'))
    }

    Write-Host "`nValidacion Godot completada correctamente."
}
finally {
    Pop-Location
}