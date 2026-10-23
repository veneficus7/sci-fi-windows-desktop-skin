// Mentat command line: a borderless one-line input shown over the Arrakis terminal.
// Compiled to Mentat.exe by install.ps1. It runs as its own short-lived process, so the .NET
// runtime never loads into Rainmeter (the InputText plugin kept ~8 MB there permanently).
//
// Args: rainmeterExe outFile x y width height textRGB backRGB fontFace fontPx
// Enter writes the text to outFile and calls MentatFile() in the terminal skin;
// Esc or clicking elsewhere calls CloseMentat().
using System;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

public class Mentat : Form
{
    [DllImport("user32.dll")]
    static extern bool SetProcessDPIAware();

    readonly TextBox box = new TextBox();
    readonly string rainmeter, outFile;
    bool done;

    static Color Rgb(string s)
    {
        string[] p = s.Split(',');
        return Color.FromArgb(int.Parse(p[0]), int.Parse(p[1]), int.Parse(p[2]));
    }

    Mentat(string[] a)
    {
        rainmeter = a[0];
        outFile = a[1];
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        Bounds = new Rectangle(int.Parse(a[2]), int.Parse(a[3]), int.Parse(a[4]), int.Parse(a[5]));
        BackColor = Rgb(a[7]);

        box.BorderStyle = BorderStyle.None;
        box.BackColor = BackColor;
        box.ForeColor = Rgb(a[6]);
        box.Font = new Font(a[8], float.Parse(a[9], CultureInfo.InvariantCulture), GraphicsUnit.Pixel);
        box.SetBounds(6, (Height - box.PreferredHeight) / 2, Width - 12, box.PreferredHeight);
        box.KeyDown += OnKey;
        Controls.Add(box);

        Deactivate += (s, e) => Finish(null);
        Shown += (s, e) => { Activate(); box.Focus(); };
    }

    void OnKey(object sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; Finish(box.Text); }
        else if (e.KeyCode == Keys.Escape) { e.SuppressKeyPress = true; Finish(null); }
    }

    void Finish(string text)
    {
        if (done) return;
        done = true;
        string bang;
        if (text != null && text.Trim().Length > 0)
        {
            File.WriteAllText(outFile, text, new UTF8Encoding(false));
            bang = "[!CommandMeasure mScript \"MentatFile()\" \"Arrakis\\Terminal\"]";
        }
        else
        {
            bang = "[!CommandMeasure mScript \"CloseMentat()\" \"Arrakis\\Terminal\"]";
        }
        try { Process.Start(new ProcessStartInfo(rainmeter, bang) { UseShellExecute = false }); }
        catch (Exception) { }
        Close();
    }

    [STAThread]
    public static void Main(string[] a)
    {
        if (a.Length < 10) return;
        SetProcessDPIAware();
        Application.EnableVisualStyles();
        Application.Run(new Mentat(a));
    }
}
