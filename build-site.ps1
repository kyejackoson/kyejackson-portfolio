# Assemble a clean, uploadable copy of the site in _site\.
#
# WHY THIS EXISTS: the working folder is 178MB, but only ~14MB of that is the
# website. The rest is "Kyes folders" — the Procreate exports, SolidWorks PDFs
# and raw renders the site's images were generated from. Dragging the working
# folder straight onto Netlify would upload all of it, publicly.
#
# Run this, then drag _site\ (not the project folder) onto Netlify.

param(
  [string]$Root = $PSScriptRoot,
  [string]$Out  = (Join-Path $PSScriptRoot "_site")
)

$ErrorActionPreference = "Stop"

# Everything the live site needs, and nothing else.
$files = @("index.html", "about.html", "portfolio.html", "contact.html",
           "404.html", "robots.txt", "sitemap.xml", "netlify.toml")
$dirs  = @("css", "js", "images", "assets", "projects")

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Out | Out-Null

foreach ($f in $files) {
  $src = Join-Path $Root $f
  if (Test-Path $src -PathType Leaf) {
    Copy-Item $src -Destination $Out
  } else {
    Write-Warning "missing: $f"
  }
}

foreach ($d in $dirs) {
  $src = Join-Path $Root $d
  if (Test-Path $src -PathType Container) {
    Copy-Item $src -Destination $Out -Recurse
  } else {
    Write-Warning "missing directory: $d"
  }
}

$size  = (Get-ChildItem $Out -Recurse -File | Measure-Object -Property Length -Sum).Sum
$count = (Get-ChildItem $Out -Recurse -File | Measure-Object).Count

Write-Host ""
Write-Host "Built $Out"
Write-Host "  $count files, $([Math]::Round($size / 1MB, 1)) MB"
Write-Host ""
Write-Host "Sanity check - these must NOT appear below:" -ForegroundColor Yellow
$leaked = Get-ChildItem $Out -Recurse -File |
  Where-Object { $_.FullName -match "Kyes folders" -or $_.Extension -eq ".ps1" }
if ($leaked) {
  $leaked | ForEach-Object { Write-Host "  LEAKED: $($_.FullName)" -ForegroundColor Red }
} else {
  Write-Host "  clean - no source material or scripts in the build." -ForegroundColor Green
}
