// Empties the Recycle Bin in its own process, with Windows' confirmation and progress dialogs.
// Compiled to EmptyBin.exe by install.ps1. RecycleManager's own "EmptyBin" runs on Rainmeter's
// main thread, so deleting a large bin froze (and eventually killed) the whole desktop.
using System;
using System.Runtime.InteropServices;

public static class EmptyBin
{
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern int SHEmptyRecycleBin(IntPtr hwnd, string rootPath, uint flags);

    [STAThread]
    public static int Main()
    {
        // flags 0: ask for confirmation, show progress, play the sound
        return SHEmptyRecycleBin(IntPtr.Zero, null, 0);
    }
}
