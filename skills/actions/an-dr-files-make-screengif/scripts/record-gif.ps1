#Requires -Version 7
<#
.SYNOPSIS
    Records one window, or converts an existing video, into an optimised GIF.

.DESCRIPTION
    -Window records a Windows window by its exact title with ffmpeg's gdigrab device.
    -Video converts a recording made by any other tool, trimmed by -Start and -Seconds.
    Both encode through a generated palette, because ffmpeg's default 256-colour
    quantisation dithers flat interface colours into noise and inflates the file.
#>
[CmdletBinding(DefaultParameterSetName = 'Window')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Window')][string]$Window,
    [Parameter(Mandatory, ParameterSetName = 'Video')][string]$Video,
    [Parameter(Mandatory)][string]$OutFile,
    [Parameter(ParameterSetName = 'Video')][double]$Start = 0,
    [double]$Seconds = 8,
    [int]$Fps = 12,
    [int]$Width = 800,
    [Parameter(ParameterSetName = 'Window')][int]$Countdown = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw 'ffmpeg was not found. Install it (winget install Gyan.FFmpeg, brew install ffmpeg, or apt install ffmpeg), then rerun.'
}

$OutFile = [IO.Path]::GetFullPath($OutFile)
New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
$raw = $null

try {
    if ($PSCmdlet.ParameterSetName -eq 'Window') {
        if (-not $IsWindows) {
            throw 'Window recording is implemented for Windows only. Record with the system recorder and pass the file through -Video.'
        }
        # Recording losslessly first keeps the palette pass from seeing compression artefacts.
        $raw = Join-Path ([IO.Path]::GetTempPath()) "record-gif-$([guid]::NewGuid()).mkv"
        for ($i = $Countdown; $i -gt 0; $i--) {
            Write-Host "Recording '$Window' in $i..."
            Start-Sleep -Seconds 1
        }
        Write-Host "Recording for $Seconds s."
        & ffmpeg -hide_banner -loglevel error -y -f gdigrab -framerate 30 -draw_mouse 1 -i "title=$Window" `
            -t $Seconds -c:v libx264rgb -crf 0 -preset ultrafast $raw
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg could not record a window titled exactly '$Window'." }
        $source = $raw
        $trim = @()
    } else {
        if (-not (Test-Path $Video)) { throw "Video '$Video' does not exist." }
        $source = $Video
        $trim = @('-ss', $Start, '-t', $Seconds)
    }

    $filter = "fps=$Fps,scale=${Width}:-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
    & ffmpeg -hide_banner -loglevel error -y @trim -i $source -filter_complex $filter -loop 0 $OutFile
    if ($LASTEXITCODE -ne 0) { throw 'ffmpeg failed to encode the GIF.' }
} finally {
    if ($raw -and (Test-Path $raw)) { Remove-Item $raw -Force }
}

$size = [math]::Round((Get-Item $OutFile).Length / 1MB, 2)
Write-Output "Saved $OutFile ($size MB)"
if ($size -gt 5) { Write-Warning 'The GIF exceeds 5 MB. Lower -Fps or -Width, or shorten -Seconds.' }
