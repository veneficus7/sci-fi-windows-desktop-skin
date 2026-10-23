// Sets the desktop wallpaper (Fill). Compiled to SetWallpaper.exe by install.ps1 and run by
// the Sky skin; Rainmeter's own !SetWallpaper does not reach Explorer on this system.
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32;

public static class SetWallpaper
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool SystemParametersInfo(int action, int param, string value, int flags);

    public static int Main(string[] args)
    {
        if (args.Length < 1 || !File.Exists(args[0])) return 1;
        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop", true))
        {
            key.SetValue("WallpaperStyle", "10");
            key.SetValue("TileWallpaper", "0");
        }
        // SPI_SETDESKWALLPAPER, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
        return SystemParametersInfo(0x14, 0, args[0], 3) ? 0 : 2;
    }
}
