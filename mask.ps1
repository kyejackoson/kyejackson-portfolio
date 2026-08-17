# Paint a white rectangle over a region of an image — used to remove the
# SolidWorks "Item is Unsolvable / Item Conflicts" UI legend that was
# accidentally captured in the exported drawing PDFs.
param(
  [Parameter(Mandatory=$true)][string]$In,
  [Parameter(Mandatory=$true)][string]$Out,
  [Parameter(Mandatory=$true)][int]$X,
  [Parameter(Mandatory=$true)][int]$Y,
  [Parameter(Mandatory=$true)][int]$W,
  [Parameter(Mandatory=$true)][int]$H,
  [int]$Quality = 88
)
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile((Resolve-Path $In))
$bmp = New-Object System.Drawing.Bitmap($src.Width, $src.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.DrawImage($src, 0, 0, $src.Width, $src.Height)
$g.FillRectangle([System.Drawing.Brushes]::White, $X, $Y, $W, $H)

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int64]$Quality)
$bmp.Save($Out, $codec, $ep)
Write-Host "masked $([System.IO.Path]::GetFileName($In)) [$X,$Y ${W}x${H}]"
$g.Dispose(); $bmp.Dispose(); $src.Dispose()
