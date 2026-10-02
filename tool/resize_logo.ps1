Add-Type -AssemblyName System.Drawing
$srcPath = Join-Path $PSScriptRoot "..\assets\logo.png"
$dstPath = Join-Path $PSScriptRoot "..\web\hissab_logo_120.png"

$src = [System.Drawing.Image]::FromFile($srcPath)
$bmp = New-Object System.Drawing.Bitmap 120, 120
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.DrawImage($src, 0, 0, 120, 120)
$bmp.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bmp.Dispose()
$src.Dispose()

Write-Host "Created 120x120 logo successfully at $dstPath"
