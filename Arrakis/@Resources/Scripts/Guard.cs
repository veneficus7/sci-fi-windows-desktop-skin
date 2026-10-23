// Arrakis guard. Task Scheduler runs it at sign-in and every 5 minutes (install.ps1 -Guard).
//  - Rainmeter not running      -> start it
//  - Rainmeter not responding   -> wait 30 s; if still frozen, close it and start it again
// Does nothing while %APPDATA%\Rainmeter\Arrakis-guard-off exists (Mentat: "guard off").
// Restarts are logged to %APPDATA%\Rainmeter\Arrakis-guard.log.
//
// Args: [exePath]   (defaults to Rainmeter; the process name is taken from the file name)
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

public static class Guard
{
    delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern bool EnumWindows(EnumProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);

    [DllImport("user32.dll")]
    static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam,
        uint flags, uint timeoutMs, out IntPtr result);

    const uint WM_NULL = 0, SMTO_ABORTIFHUNG = 0x2;

    static readonly string SettingsDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Rainmeter");

    // True when any window of the process answers within 5 s (or it has no windows yet).
    static bool Responds(Process p)
    {
        bool anyWindow = false, answered = false;
        EnumWindows((hwnd, l) =>
        {
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            if (pid != p.Id) return true;
            anyWindow = true;
            IntPtr result;
            if (SendMessageTimeout(hwnd, WM_NULL, IntPtr.Zero, IntPtr.Zero, SMTO_ABORTIFHUNG, 5000, out result) != IntPtr.Zero)
            {
                answered = true;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return answered || !anyWindow;
    }

    // Plain CreateProcess launch at normal priority. Launched through the shell (Explorer or
    // ShellExecute), this Rainmeter starts but never loads its skins on this PC.
    static void Launch(string exe)
    {
        Process p = Process.Start(new ProcessStartInfo(exe)
        {
            UseShellExecute = false,
            WorkingDirectory = Path.GetDirectoryName(exe),
        });
        try { p.PriorityClass = ProcessPriorityClass.Normal; } catch (Exception) { }
    }

    static void Log(string message)
    {
        try
        {
            File.AppendAllText(Path.Combine(SettingsDir, "Arrakis-guard.log"),
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + message + Environment.NewLine);
        }
        catch (Exception) { }
    }

    public static int Main(string[] args)
    {
        string exe = args.Length > 0 ? args[0] : @"C:\Program Files\Rainmeter\Rainmeter.exe";
        if (File.Exists(Path.Combine(SettingsDir, "Arrakis-guard-off")) || !File.Exists(exe)) return 0;
        string name = Path.GetFileNameWithoutExtension(exe);

        Process[] running = Process.GetProcessesByName(name);
        if (running.Length == 0)
        {
            Launch(exe);
            Log(name + " was not running: started");
            return 1;
        }

        foreach (Process p in running)
        {
            if (Responds(p)) continue;
            Thread.Sleep(30000);                       // give a busy app time to recover
            p.Refresh();
            if (p.HasExited || Responds(p)) continue;
            try { p.Kill(); p.WaitForExit(5000); } catch (Exception) { }
            Launch(exe);
            Log(name + " was frozen for 30+ s: restarted");
            return 2;
        }
        return 0;
    }
}
