#Requires -Version 7
<#
.SYNOPSIS
    Captures a web page or one application window to a PNG file.

.DESCRIPTION
    -Url renders the page in headless Chromium through the Playwright CLI.
    -Window captures a top-level Windows window, matched by process name or by a
    substring of its title. Screen copies the window's on-screen pixels after bringing it
    forward, which works for games; Print asks the window to render itself, which works
    while it is covered but can return black for DirectX or OpenGL surfaces.
#>
[CmdletBinding(DefaultParameterSetName = 'Url')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Url')][string]$Url,
    [Parameter(Mandatory, ParameterSetName = 'Window')][string]$Window,
    [Parameter(Mandatory)][string]$OutFile,
    [Parameter(ParameterSetName = 'Url')][int]$Width = 1280,
    [Parameter(ParameterSetName = 'Url')][int]$Height = 720,
    [Parameter(ParameterSetName = 'Url')][switch]$FullPage,
    [Parameter(ParameterSetName = 'Window')][ValidateSet('Screen', 'Print')][string]$Method = 'Screen'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$OutFile = [IO.Path]::GetFullPath($OutFile)
New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null

function Invoke-PageCapture {
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw 'npx was not found. Install Node.js 18 or later (https://nodejs.org), then rerun.'
    }
    $arguments = @('--yes', 'playwright', 'screenshot', '--browser', 'chromium',
        "--viewport-size=$Width,$Height", '--wait-for-timeout', '1000')
    if ($FullPage) { $arguments += '--full-page' }
    & npx @arguments $Url $OutFile
    if ($LASTEXITCODE -ne 0) {
        throw 'Playwright failed. If the browser is missing, run: npx --yes playwright install chromium'
    }
}

function Invoke-WindowCapture {
    if (-not $IsWindows) {
        $native = $IsMacOS ? 'screencapture -w <file>.png for a click-selected window' :
            'gnome-screenshot -w, or import -window <window-id> <file>.png (ImageMagick)'
        throw "Window capture is implemented for Windows only. Use: $native"
    }

    Add-Type -AssemblyName System.Drawing
    if (-not ('Capture.Native' -as [type])) {
        Add-Type -Namespace Capture -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
[DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out RECT rect, int size);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@
    }
    # Physical pixels: without this, a scaled display reports logical coordinates and the capture is cropped.
    [Capture.Native]::SetProcessDPIAware() | Out-Null

    $windows = @(Get-Process | Where-Object { $_.MainWindowHandle -ne 0 })
    # An exact process name is the more deliberate match, so it wins over title substrings.
    $candidates = @($windows | Where-Object ProcessName -EQ $Window)
    if ($candidates.Count -eq 0) { $candidates = @($windows | Where-Object MainWindowTitle -Like "*$Window*") }
    if ($candidates.Count -eq 0) { throw "No visible window matches '$Window'. Start the application first." }
    if ($candidates.Count -gt 1) {
        $names = ($candidates | ForEach-Object { "$($_.ProcessName): $($_.MainWindowTitle)" }) -join '; '
        throw "Several windows match '$Window': $names. Pass a more specific title."
    }
    $handle = $candidates[0].MainWindowHandle

    if ([Capture.Native]::IsIconic($handle)) {
        [Capture.Native]::ShowWindow($handle, 9) | Out-Null
        Start-Sleep -Milliseconds 300
    }
    # The extended frame bounds exclude the invisible resize border that GetWindowRect includes.
    $rect = New-Object Capture.Native+RECT
    [Capture.Native]::DwmGetWindowAttribute($handle, 9, [ref]$rect, 16) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { throw "Window '$Window' has no visible area." }

    $bitmap = [Drawing.Bitmap]::new($w, $h)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        if ($Method -eq 'Screen') {
            [Capture.Native]::SetForegroundWindow($handle) | Out-Null
            Start-Sleep -Milliseconds 400
            $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        } else {
            $hdc = $graphics.GetHdc()
            # 2 = PW_RENDERFULLCONTENT, needed for windows composed by DirectComposition.
            $ok = [Capture.Native]::PrintWindow($handle, $hdc, 2)
            $graphics.ReleaseHdc($hdc)
            if (-not $ok) { throw 'PrintWindow failed. Retry with -Method Screen.' }
        }
        $bitmap.Save($OutFile, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Url') { Invoke-PageCapture } else { Invoke-WindowCapture }

$size = [math]::Round((Get-Item $OutFile).Length / 1KB)
Write-Output "Saved $OutFile ($size KB)"
