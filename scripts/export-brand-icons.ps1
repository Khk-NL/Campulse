$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$brandRoot = Split-Path $PSScriptRoot -Parent
$brandSource = [System.Drawing.Image]::FromFile((Join-Path $brandRoot 'CampusLogo.png'))
try {
  $brandTargets = @{
    'apps/mobile/assets/brand/campulse-logo.png' = 512
    'deploy/pocketbase/pb_public/assets/campulse-logo.png' = 512
    'deploy/pocketbase/pb_public/assets/favicon.png' = 28
    'apps/mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png' = 48
    'apps/mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png' = 72
    'apps/mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png' = 96
    'apps/mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png' = 144
    'apps/mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png' = 192
    'apps/mobile/android/app/src/main/res/drawable/campulse_logo.png' = 192
  }
  foreach ($brandPath in $brandTargets.Keys) {
    $brandSize = $brandTargets[$brandPath]
    $brandOutput = Join-Path $brandRoot $brandPath
    New-Item -ItemType Directory -Force -Path (Split-Path $brandOutput -Parent) | Out-Null
    $brandBitmap = [System.Drawing.Bitmap]::new($brandSize,$brandSize,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $brandGraphics = [System.Drawing.Graphics]::FromImage($brandBitmap)
    try {
      $brandGraphics.Clear([System.Drawing.Color]::Transparent)
      $brandGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
      $brandGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $brandGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $brandGraphics.DrawImage($brandSource,[System.Drawing.Rectangle]::new(0,0,$brandSize,$brandSize),0,0,$brandSource.Width,$brandSource.Height,[System.Drawing.GraphicsUnit]::Pixel)
      $brandBitmap.Save($brandOutput,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $brandGraphics.Dispose(); $brandBitmap.Dispose() }
    Write-Output "$brandPath ${brandSize}x${brandSize}"
  }
} finally { $brandSource.Dispose() }
& (Join-Path $PSScriptRoot 'export-windows-icon.ps1')
