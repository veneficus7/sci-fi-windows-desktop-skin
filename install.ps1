<#
  Installs or updates the Arrakis desktop: copies the skins into Rainmeter (keeping your
  settings and discoveries), writes the layouts for each theme and loads the current one.

    powershell -ExecutionPolicy Bypass -File install.ps1                    # install / update
    powershell -ExecutionPolicy Bypass -File install.ps1 -City "Tashkent"   # also set up live weather
    powershell -ExecutionPolicy Bypass -File install.ps1 -Autostart         # also start Rainmeter with Windows
    powershell -ExecutionPolicy Bypass -File install.ps1 -Guard             # also restart Rainmeter if it closes or freezes
    powershell -ExecutionPolicy Bypass -File install.ps1 -Reset             # overwrite settings and state
#>
param([switch]$Reset, [switch]$Autostart, [switch]$Guard, [string]$City)
$ErrorActionPreference = 'Stop'
# Keep a record of every run next to this script.
try { Start-Transcript -Path (Join-Path $PSScriptRoot 'install-log.txt') -Force | Out-Null } catch { }
trap { Write-Host "INSTALL FAILED: $_" -ForegroundColor Red; try { Stop-Transcript | Out-Null } catch { }; exit 1 }

$src = Join-Path $PSScriptRoot 'Arrakis'
if (-not (Test-Path (Join-Path $src '@Resources\Images\Wallpapers\arrakis_day.png'))) {
    Write-Host 'The wallpapers have not been generated yet (artwork is not included in the repository).' -ForegroundColor Yellow
    Write-Host 'Run:  python build\make_assets.py path\to\dune.jpg Arrakis\@Resources [path\to\alien.jpg]'
    exit 1
}
$rainmeter = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
if (-not (Test-Path $rainmeter)) {
    Write-Host 'Rainmeter is not installed. Install it first:' -ForegroundColor Yellow
    Write-Host '  winget install -e --id Rainmeter.Rainmeter'
    exit 1
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ArrakisNative {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
}
'@
[void][ArrakisNative]::SetProcessDPIAware()
$w = [ArrakisNative]::GetSystemMetrics(0); $h = [ArrakisNative]::GetSystemMetrics(1)
if ($w -ne 1920 -or $h -ne 1200) {
    Write-Warning "The layout is built for 1920x1200 but the primary screen is ${w}x${h}. Elements will be misplaced."
}

# --- where Rainmeter keeps skins (honours a custom SkinPath) ---
$settings = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
$skinsDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
if (Test-Path $settings) {
    $m = Select-String -Path $settings -Pattern '^\s*SkinPath\s*=\s*(.+?)\s*$' | Select-Object -First 1
    if ($m) { $skinsDir = $m.Matches[0].Groups[1].Value.TrimEnd('\') }
}
$dest = Join-Path $skinsDir 'Arrakis'
$res = Join-Path $dest '@Resources'

# --- keep the user's settings and saved state across updates ---
function Read-Keys([string]$path) {
    $keys = [ordered]@{}
    if (Test-Path $path) {
        foreach ($line in [IO.File]::ReadAllLines($path)) {
            if ($line -match '^\s*([^;\[\s][^=]*?)\s*=(.*)$') { $keys[$Matches[1]] = $Matches[2] }
        }
    }
    return $keys
}
# Takes the new default file and puts the user's values back into it; keys the user added are appended.
function Merge-Keys([string]$path, $old) {
    $lines = [Collections.Generic.List[string]][IO.File]::ReadAllLines($path)
    $seen = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*([^;\[\s][^=]*?)\s*=') {
            $k = $Matches[1]; $seen[$k] = $true
            if ($old.Contains($k)) { $lines[$i] = "$k=$($old[$k])" }
        }
    }
    foreach ($k in $old.Keys) { if (-not $seen.ContainsKey($k)) { $lines.Add("$k=$($old[$k])") } }
    [IO.File]::WriteAllLines($path, $lines)
}
$oldVars = if ($Reset) { [ordered]@{} } else { Read-Keys (Join-Path $res 'Variables.inc') }
$oldState = if ($Reset) { [ordered]@{} } else { Read-Keys (Join-Path $res 'State.inc') }

robocopy $src $dest /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Copying the skin failed (robocopy exit $LASTEXITCODE)." }
# Default paths in Variables.inc are written with a {USERPROFILE} placeholder.
$varsPath = Join-Path $res 'Variables.inc'
[IO.File]::WriteAllText($varsPath, ([IO.File]::ReadAllText($varsPath)).Replace('{USERPROFILE}', $env:USERPROFILE))
Merge-Keys (Join-Path $res 'Variables.inc') $oldVars
Merge-Keys (Join-Path $res 'State.inc') $oldState

# --- optional: live weather from a city name (Open-Meteo geocoding, no account) ---
if ($City) {
    $q = [uri]::EscapeDataString($City)
    $geo = Invoke-RestMethod "https://geocoding-api.open-meteo.com/v1/search?name=$q&count=1&language=en&format=json"
    if (-not $geo.results) { throw "Could not find a place called '$City'." }
    $place = $geo.results[0]
    $inv = [Globalization.CultureInfo]::InvariantCulture
    Merge-Keys (Join-Path $res 'Variables.inc') ([ordered]@{
        WeatherCity = "$($place.name), $($place.country)"
        Latitude    = ([double]$place.latitude).ToString('0.####', $inv)
        Longitude   = ([double]$place.longitude).ToString('0.####', $inv)
    })
    Write-Host "Weather set to $($place.name), $($place.country)"
}

# --- wallpaper helper used by the Sky skin (compiled from the readable source next to it) ---
$csSource = Join-Path $res 'Scripts\SetWallpaper.cs'
Add-Type -TypeDefinition ([IO.File]::ReadAllText($csSource)) -OutputType WindowsApplication `
    -OutputAssembly (Join-Path $res 'Scripts\SetWallpaper.exe')
# Emptying the recycle bin runs in its own process too, so a big bin cannot freeze Rainmeter.
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $res 'Scripts\EmptyBin.cs'))) -OutputType WindowsApplication `
    -OutputAssembly (Join-Path $res 'Scripts\EmptyBin.exe')
# Mentat's input box runs as its own short-lived process, so .NET never loads into Rainmeter.
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $res 'Scripts\Mentat.cs'))) -OutputType WindowsApplication `
    -ReferencedAssemblies System.Windows.Forms, System.Drawing -OutputAssembly (Join-Path $res 'Scripts\Mentat.exe')
# The guard Task Scheduler runs (see -Guard below).
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $res 'Scripts\Guard.cs'))) -OutputType WindowsApplication `
    -OutputAssembly (Join-Path $res 'Scripts\Guard.exe')

# Rainmeter needs UTF-16 LE for the non-ASCII glyphs (the marker, dots and bullets).
Get-ChildItem $dest -Recurse -Include *.ini, *.inc | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName)
    [IO.File]::WriteAllText($_.FullName, $text, [Text.Encoding]::Unicode)
}

# --- layouts: one per theme, positions in physical pixels ---
# name = x, y [, extra settings]
$common = [ordered]@{
    'Intro'    = 0, 0, 'Active=0|AlwaysOnTop=2|FadeDuration=700|LoadOrder=10'
    'Terminal' = 14, 18
    'Controls' = 1769, 9
    'Title'    = 460, 895
    'Stats'    = 360, 1128
    'Sky'      = 0, 0, 'ClickThrough=1|LoadOrder=5'
}
$themes = [ordered]@{
    'Arrakis' = [ordered]@{
        'Record1' = 510, 510
        'Record2' = 1300, 400
        'Record3' = 1105, 102
        'Record4' = 832, 296
        'Record5' = 70, 850
        'Record6' = 770, 640
        'Moon1'   = 953, 124, 'SavePosition=0'
        'Moon2'   = 959, 84, 'SavePosition=0'
        'Focus'   = 635, 28, 'Active=0|ClickThrough=1'
        'Worm'    = 1920, 870, 'Active=0|ClickThrough=1|SavePosition=0|LoadOrder=-1'
    }
    'Nostromo' = [ordered]@{
        'Record1' = 480, 430
        'Record2' = 1250, 510
        'Record3' = 920, 110
        'Record4' = 800, 360
        'Record5' = 940, 535
        'Record6' = 880, 690
    }
}
function Write-Layout([string]$name, $configs) {
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine('[Rainmeter]').AppendLine()
    foreach ($cfg in $configs.Keys) {
        $v = @($configs[$cfg])
        $opts = [ordered]@{ Active = 1; WindowX = $v[0]; WindowY = $v[1]; ClickThrough = 0; Draggable = 0; SnapEdges = 0
                            KeepOnScreen = 0; AlwaysOnTop = -2; SavePosition = 1; FadeDuration = 250; LoadOrder = 0 }
        if ($v.Count -gt 2) { foreach ($kv in $v[2].Split('|')) { $k, $val = $kv.Split('='); $opts[$k] = $val } }
        [void]$sb.AppendLine("[Arrakis\$cfg]")
        foreach ($k in $opts.Keys) { [void]$sb.AppendLine("$k=$($opts[$k])") }
        [void]$sb.AppendLine()
    }
    $dir = Join-Path $env:APPDATA "Rainmeter\Layouts\$name"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'Rainmeter.ini'), $sb.ToString(), [Text.Encoding]::Unicode)
}
foreach ($t in $themes.Keys) {
    if ($t -ne 'Arrakis' -and -not (Test-Path (Join-Path $res "Images\Wallpapers\$($t.ToLower())_day.png"))) { continue }
    $all = [ordered]@{}
    foreach ($k in $common.Keys) { $all[$k] = $common[$k] }
    foreach ($k in $themes[$t].Keys) { $all[$k] = $themes[$t][$k] }
    Write-Layout $t $all
}

# --- back up the current wallpaper once (the Sky skin sets ours) ---
$backup = Join-Path $env:APPDATA 'Rainmeter\Arrakis-previous-wallpaper.json'
if (-not (Test-Path $backup)) {
    $cur = Get-ItemProperty 'HKCU:\Control Panel\Desktop'
    $known = Join-Path $PSScriptRoot 'original-wallpaper.json'
    if (($cur.WallPaper -match '\\Skins\\Arrakis\\|\\Rainmeter\\Wallpaper\.bmp$') -and (Test-Path $known)) {
        # The desktop already shows one of ours; keep the wallpaper you had before Arrakis.
        Copy-Item $known $backup
    } else {
        @{ WallPaper = $cur.WallPaper; WallpaperStyle = $cur.WallpaperStyle; TileWallpaper = $cur.TileWallpaper } |
            ConvertTo-Json | Set-Content -Path $backup -Encoding UTF8
    }
}

# --- render at physical pixels: without this, Windows bitmap-scales Rainmeter at 125% and
#     every skin ends up 25% too big, blurry and offset from the wallpaper ---
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
# Never use New-Item -Force here: on an existing registry key it recreates the key and drops
# the other apps' compatibility entries.
if (-not (Test-Path $layers)) { New-Item -Path $layers | Out-Null }
$current = (Get-ItemProperty $layers -ErrorAction SilentlyContinue).$rainmeter
if ($current -ne '~ HIGHDPIAWARE') {
    New-ItemProperty -Path $layers -Name $rainmeter -Value '~ HIGHDPIAWARE' -PropertyType String -Force | Out-Null
    Get-Process Rainmeter -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# --- optional: start with Windows (same shortcut Rainmeter's own installer offers) ---
if ($Autostart) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Rainmeter.lnk'
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $shortcut.TargetPath = $rainmeter
    $shortcut.WorkingDirectory = Split-Path $rainmeter
    $shortcut.Save()
    Write-Host "Rainmeter will start with Windows ($lnk)"
}

# --- optional: guard task. Runs Guard.exe at sign-in and every 5 minutes; it starts Rainmeter
#     if it is not running and restarts it if it has been frozen for 30+ seconds. ---
if ($Guard) {
    $me = "$env:USERDOMAIN\$env:USERNAME"
    $action = New-ScheduledTaskAction -Execute (Join-Path $res 'Scripts\Guard.exe') -Argument "`"$rainmeter`""
    $every5 = (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)).Repetition
    $atLogon = New-ScheduledTaskTrigger -AtLogOn -User $me
    $atLogon.Delay = 'PT1M'            # the startup shortcut starts Rainmeter; this is the backstop
    $atLogon.Repetition = $every5
    $now = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName 'Arrakis Guard' -Action $action -Trigger $atLogon, $now -Settings $settings `
        -Principal $principal -Description 'Keeps the Arrakis Rainmeter desktop running. Pause with Mentat: guard off.' -Force | Out-Null
    Write-Host 'Guard installed: Rainmeter is restarted if it closes or freezes (Mentat: guard off to pause).'
}

# --- load the layout of the current theme ---
$theme = (Read-Keys (Join-Path $res 'State.inc'))['Theme']
if (-not $theme -or -not (Test-Path (Join-Path $env:APPDATA "Rainmeter\Layouts\$theme"))) { $theme = 'Arrakis' }
# Always start a fresh Rainmeter so it reads the settings written above.
Get-Process Rainmeter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
Start-Process -FilePath $rainmeter -ArgumentList "!LoadLayout $theme"
Write-Host "Arrakis installed to $dest (theme: $theme)" -ForegroundColor Green
try { Stop-Transcript | Out-Null } catch { }
