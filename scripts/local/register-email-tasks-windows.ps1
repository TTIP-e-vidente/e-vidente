# Registra tareas programadas en Windows (Task Scheduler) para emails locales.
# Requiere PowerShell como usuario con permiso para crear tareas.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts/local/register-email-tasks-windows.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/local/register-email-tasks-windows.ps1 -Unregister

param(
	[switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$runnerScript = (Resolve-Path (Join-Path $PSScriptRoot 'run-email-job.ps1')).Path
$pwshExecutable = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
if (-not $pwshExecutable) {
	$pwshExecutable = (Get-Command powershell -ErrorAction Stop).Source
}

function Register-EmailTask {
	param(
		[string]$TaskName,
		[string]$Job,
		[string]$DailyAt
	)

	$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runnerScript`" -Job $Job"
	$action = New-ScheduledTaskAction -Execute $pwshExecutable -Argument $arguments
	$trigger = New-ScheduledTaskTrigger -Daily -At $DailyAt
	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

	Register-ScheduledTask `
		-TaskName $TaskName `
		-Action $action `
		-Trigger $trigger `
		-Settings $settings `
		-Description "E-VIDENTE email job local ($Job)" `
		-Force | Out-Null

	Write-Host "Registrada: $TaskName ($DailyAt ART) -> $Job"
}

function Remove-EmailTask {
	param([string]$TaskName)

	$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
	if ($null -eq $existing) {
		Write-Host "No existe: $TaskName"
		return
	}
	Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
	Write-Host "Eliminada: $TaskName"
}

$tasks = @(
	@{ Name = 'E-VIDENTE-Email-Streaks'; Job = 'streaks'; At = '19:00' },
	@{ Name = 'E-VIDENTE-Email-Retry-AM'; Job = 'retry-failed'; At = '08:00' },
	@{ Name = 'E-VIDENTE-Email-Retry-PM'; Job = 'retry-failed'; At = '20:00' }
)

if ($Unregister) {
	foreach ($task in $tasks) {
		Remove-EmailTask -TaskName $task.Name
	}
	exit 0
}

foreach ($task in $tasks) {
	Register-EmailTask -TaskName $task.Name -Job $task.Job -DailyAt $task.At
}

Write-Host ""
Write-Host "Listo. Verificá en Programador de tareas de Windows (taskschd.msc)."
Write-Host "Probar manual: powershell -ExecutionPolicy Bypass -File scripts/local/run-email-job.ps1 -Job streaks"
