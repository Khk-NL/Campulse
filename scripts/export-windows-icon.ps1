$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$iconRoot = Split-Path $PSScriptRoot -Parent
$iconSource = [System.Drawing.Image]::FromFile((Join-Path $iconRoot 'CampusLogo.png'))
$iconFrames = [System.Collections.Generic.List[byte[]]]::new()
$iconSizes = @(16, 32, 48, 256)
try {
  foreach ($iconSize in $iconSizes) {
    $iconBitmap = [System.Drawing.Bitmap]::new($iconSize, $iconSize)
    $iconGraphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
    $iconStream = [System.IO.MemoryStream]::new()
    try {
      $iconGraphics.Clear([System.Drawing.Color]::Transparent)
      $iconGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $iconGraphics.DrawImage($iconSource, 0, 0, $iconSize, $iconSize)
      $iconBitmap.Save($iconStream, [System.Drawing.Imaging.ImageFormat]::Png)
      $iconFrames.Add($iconStream.ToArray())
    } finally { $iconStream.Dispose(); $iconGraphics.Dispose(); $iconBitmap.Dispose() }
  }
  $iconPath = Join-Path $iconRoot 'apps/mobile/windows/runner/resources/app_icon.ico'
  $iconOutput = [System.IO.BinaryWriter]::new([System.IO.File]::Create($iconPath))
  try {
    $iconOutput.Write([uint16]0); $iconOutput.Write([uint16]1); $iconOutput.Write([uint16]$iconSizes.Count)
    $iconOffset = 6 + 16 * $iconSizes.Count
    for ($iconIndex = 0; $iconIndex -lt $iconSizes.Count; $iconIndex++) {
      $iconDimension = if ($iconSizes[$iconIndex] -eq 256) { 0 } else { $iconSizes[$iconIndex] }
      $iconOutput.Write([byte]$iconDimension); $iconOutput.Write([byte]$iconDimension)
      $iconOutput.Write([byte]0); $iconOutput.Write([byte]0)
      $iconOutput.Write([uint16]1); $iconOutput.Write([uint16]32)
      $iconOutput.Write([uint32]$iconFrames[$iconIndex].Length); $iconOutput.Write([uint32]$iconOffset)
      $iconOffset += $iconFrames[$iconIndex].Length
    }
    foreach ($iconFrame in $iconFrames) { $iconOutput.Write([byte[]]$iconFrame) }
  } finally { $iconOutput.Dispose() }
  Write-Output 'Windows icon exported from CampusLogo.png (16 / 32 / 48 / 256).'
} finally { $iconSource.Dispose() }
