<#
  Turns the Arrakis desktop off and restores the previous wallpaper.

    powershell -ExecutionPolicy Bypass -File uninstall.ps1           # unload skins, restore wallpaper
    powershell -ExecutionPolicy Bypass -File uninstall.ps1 -Remove   # also delete the skin and layout files
#>
param([switch]$Remove)
$ErrorActionPreference = 'Stop'

$rainmeter = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'

# Remove the guard first so it does not restart anything while we unload.
Unregister-ScheduledTask -TaskName 'Arrakis Guard' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $env:APPDATA 'Rainmeter\Arrakis-guard-off') -ErrorAction SilentlyContinue

$names ='Intro', 'Terminal', 'Controls', 'Record1', 'Record2', 'Record3', 'Record4', 'Record5', 'Record6',
         'Title', 'Stats', 'Sky', 'Moon1', 'Moon2', 'Focus', 'Worm'
if ((Test-Path $rainmeter) -and (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
    # Only configs that are loaded; deactivating an inactive one just logs an error.
    $ini = [IO.File]::ReadAllText((Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'))
    $active = $names | Where-Object { $ini -match "(?m)^\[Arrakis\\$_\]\r?\nActive=[1-9]" }
    $bangs = ($active | ForEach-Object { "[!DeactivateConfig `"Arrakis\$_`"]" }) -join ''
    if ($bangs) { Start-Process -FilePath $rainmeter -ArgumentList $bangs -Wait }
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ArrakisNative {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
}
'@
$backup = Join-Path $env:APPDATA 'Rainmeter\Arrakis-previous-wallpaper.json'
if (Test-Path $backup) {
    $prev = Get-Content $backup -Raw | ConvertFrom-Json
    $desktop = 'HKCU:\Control Panel\Desktop'
    if ($null -ne $prev.WallpaperStyle) { Set-ItemProperty $desktop -Name WallpaperStyle -Value $prev.WallpaperStyle }
    if ($null -ne $prev.TileWallpaper) { Set-ItemProperty $desktop -Name TileWallpaper -Value $prev.TileWallpaper }
    [void][ArrakisNative]::SystemParametersInfo(0x14, 0, [string]$prev.WallPaper, 0x3)
    Remove-Item $backup
    Write-Host "Wallpaper restored to $($prev.WallPaper)"
}

if ($Remove) {
    # Undo the per-app DPI override install.ps1 set for Rainmeter.
    $layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    Remove-ItemProperty -Path $layers -Name $rainmeter -ErrorAction SilentlyContinue
    # And the startup shortcut from install.ps1 -Autostart.
    Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Startup')) 'Rainmeter.lnk') -ErrorAction SilentlyContinue

    $skinsDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
    $settings = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
    if (Test-Path $settings) {
        $m = Select-String -Path $settings -Pattern '^\s*SkinPath\s*=\s*(.+?)\s*$' | Select-Object -First 1
        if ($m) { $skinsDir = $m.Matches[0].Groups[1].Value.TrimEnd('\') }
    }
    Remove-Item -Recurse -Force (Join-Path $skinsDir 'Arrakis') -ErrorAction SilentlyContinue
    foreach ($l in 'Arrakis', 'Nostromo') {
        Remove-Item -Recurse -Force (Join-Path $env:APPDATA "Rainmeter\Layouts\$l") -ErrorAction SilentlyContinue
    }
    Write-Host 'Arrakis files removed.'
}
