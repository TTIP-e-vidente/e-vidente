# Ejecuta jobs de email contra Postgres local + Brevo (.env en BACKEND/).
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts/local/run-email-job.ps1 -Job streaks
#   pwsh scripts/local/run-email-job.ps1 -Job retry-failed   (si tenés PowerShell 7+)

param(
	[Parameter(Mandatory = $true)]
	[ValidateSet('streaks', 'retry-failed')]
	[string]$Job
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
	$gitRoot = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
	if ($LASTEXITCODE -eq 0 -and $gitRoot) {
		return $gitRoot.Trim()
	}
	return (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
}

$repoRoot = Resolve-RepoRoot
$backendDir = Join-Path $repoRoot 'BACKEND'

if (-not (Test-Path (Join-Path $backendDir 'package.json'))) {
	throw "No se encontro BACKEND/ en $repoRoot"
}

if (-not (Test-Path (Join-Path $backendDir '.env'))) {
	throw "Falta BACKEND/.env. Copiá .env.example y completá BREVO_API_KEY."
}

$npmScript = switch ($Job) {
	'streaks' { 'email:streaks' }
	'retry-failed' { 'email:retry-failed' }
}

Push-Location $backendDir
try {
	Write-Host "[email-local] Levantando Postgres si hace falta..."
	docker compose up -d postgres | Out-Host
	if ($LASTEXITCODE -ne 0) {
		throw "docker compose up -d postgres fallo con exit code $LASTEXITCODE"
	}

	Write-Host "[email-local] Ejecutando npm run $npmScript ..."
	npm run $npmScript
	if ($LASTEXITCODE -ne 0) {
		throw "npm run $npmScript fallo con exit code $LASTEXITCODE"
	}
}
finally {
	Pop-Location
}

Write-Host "[email-local] OK ($Job)"
