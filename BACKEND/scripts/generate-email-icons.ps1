# Exporta iconos de racha desde assets del juego (misma identidad visual que el HUD).
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$gameRacha = Join-Path (Split-Path $root -Parent) 'juego\assets-sistema\racha-diaria'
$iconsDir = Join-Path $root 'src\modules\email\assets\icons'
New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null
Add-Type -AssemblyName System.Drawing

function Export-RachaIcon {
  param(
    [string]$SourceFile,
    [string]$DestFile,
    [int]$Size = 128
  )

  $srcPath = Join-Path $gameRacha $SourceFile
  if (-not (Test-Path $srcPath)) {
    throw "No se encontró el asset del juego: $srcPath"
  }

  $img = [System.Drawing.Image]::FromFile($srcPath)
  $bmp = New-Object System.Drawing.Bitmap $Size, $Size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($img, 0, 0, $Size, $Size)

  # Quitar fondo negro del asset para que se vea bien en mails claros.
  for ($x = 0; $x -lt $Size; $x++) {
    for ($y = 0; $y -lt $Size; $y++) {
      $pixel = $bmp.GetPixel($x, $y)
      if ($pixel.A -gt 0 -and $pixel.R -le 28 -and $pixel.G -le 28 -and $pixel.B -le 28) {
        $bmp.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
      }
    }
  }

  $bmp.Save($DestFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
  $img.Dispose()
}

Export-RachaIcon -SourceFile 'racha-activa-1.png' -DestFile (Join-Path $iconsDir 'streak.png')
Export-RachaIcon -SourceFile 'racha-warning-1.png' -DestFile (Join-Path $iconsDir 'streak-header.png')

Write-Host "Iconos de racha exportados desde el juego:"
Get-ChildItem (Join-Path $iconsDir 'streak*.png') | Format-Table Name, Length
