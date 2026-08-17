param(
  [string]$Dir = (Join-Path $PSScriptRoot "images\as1100"),
  [int]$MaxSize = 1400,
  [int]$Quality = 82
)

Add-Type -AssemblyName System.Drawing

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq "image/jpeg" }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [int64]$Quality)

Get-ChildItem -Path $Dir -Filter *.png | ForEach-Object {
  $src = [System.Drawing.Image]::FromFile($_.FullName)

  $scale = [Math]::Min($MaxSize / $src.Width, $MaxSize / $src.Height)
  if ($scale -gt 1) { $scale = 1 }
  $w = [int]($src.Width * $scale)
  $h = [int]($src.Height * $scale)

  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  # JPEG has no alpha: flatten transparency onto white first, otherwise
  # transparent pixels land on black and soft shadows turn to grey noise.
  $g.Clear([System.Drawing.Color]::White)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($src, 0, 0, $w, $h)

  $out = [System.IO.Path]::ChangeExtension($_.FullName, ".jpg")
  $bmp.Save($out, $codec, $encParams)

  $g.Dispose(); $bmp.Dispose(); $src.Dispose()

  $oldKb = [Math]::Round($_.Length / 1KB)
  $newKb = [Math]::Round((Get-Item $out).Length / 1KB)
  Write-Host "$($_.Name): ${oldKb}KB -> $([System.IO.Path]::GetFileName($out)) ${newKb}KB (${w}x${h})"
}
