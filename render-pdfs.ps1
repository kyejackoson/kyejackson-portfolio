# Rasterise the first page of each drawing PDF to a JPEG using the built-in
# Windows.Data.Pdf WinRT API, so drawings display as reliable images instead
# of inline <embed> PDF viewers (which mobile browsers refuse to render).

param(
  [string]$SrcDir = (Join-Path $PSScriptRoot "assets\as1100"),
  [string]$OutDir = (Join-Path $PSScriptRoot "images\as1100"),
  [int]$Width = 1600,
  [int]$MaxPages = 2,
  [string]$Filter = "*.pdf"
)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing

# Helper to synchronously await WinRT IAsyncOperation from PowerShell
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
  Where-Object {
    $_.Name -eq 'AsTask' -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  })[0]

function Await($op, $resultType) {
  $task = $asTaskGeneric.MakeGenericMethod($resultType).Invoke($null, @($op))
  $task.Wait()
  $task.Result
}

[Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]   | Out-Null
[Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime] | Out-Null

Get-ChildItem -Path $SrcDir -Filter $Filter | ForEach-Object {
  $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)

  $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($_.FullName)) ([Windows.Storage.StorageFile])
  $doc  = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])

  $pageCount = [Math]::Min($doc.PageCount, $MaxPages)
  for ($i = 0; $i -lt $pageCount; $i++) {
    $page = $doc.GetPage($i)

    $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
    $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
    $opts.DestinationWidth = [uint32]$Width

    $render = $page.RenderToStreamAsync($stream, $opts)
    ([System.WindowsRuntimeSystemExtensions].GetMethods() |
      Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
                     $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0].Invoke($null, @($render)).Wait()

    # WinRT stream -> byte[] -> System.Drawing -> JPEG
    $size = [int]$stream.Size
    $reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
    ([System.WindowsRuntimeSystemExtensions].GetMethods() |
      Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
                     $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0].
      MakeGenericMethod([uint32]).Invoke($null, @($reader.LoadAsync($size))).Wait()

    $bytes = New-Object byte[] $size
    $reader.ReadBytes($bytes)
    $reader.Dispose()

    $suffix = if ($doc.PageCount -gt 1) { "-p$($i+1)" } else { "" }
    $out = Join-Path $OutDir "$name-drawing$suffix.jpg"

    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $bmp = [System.Drawing.Image]::FromStream($ms)

    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
      Where-Object { $_.MimeType -eq "image/jpeg" }
    $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
      [System.Drawing.Imaging.Encoder]::Quality, [int64]85)

    # flatten onto white; PDF renders with transparency
    $flat = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height)
    $g = [System.Drawing.Graphics]::FromImage($flat)
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawImage($bmp, 0, 0, $bmp.Width, $bmp.Height)

    $flat.Save($out, $codec, $encParams)
    Write-Host "$($_.Name) p$($i+1) -> $([System.IO.Path]::GetFileName($out)) ($($bmp.Width)x$($bmp.Height), $([Math]::Round((Get-Item $out).Length/1KB))KB)"

    $g.Dispose(); $flat.Dispose(); $bmp.Dispose(); $ms.Dispose(); $stream.Dispose()
  }
}
