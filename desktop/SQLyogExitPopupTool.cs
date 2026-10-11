using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using Microsoft.Win32;

namespace SQLyogExitPopupTool
{
    public enum FileState { Original, Patched, Unsupported }

    // All patching and validation live in the standalone PowerShell script.
    public static class PatchService
    {
        private static string Run(string action, string path)
        {
            string script = Path.Combine(Path.GetDirectoryName(typeof(PatchService).Assembly.Location), "sqlyog-no-popup.ps1");
            if (!File.Exists(script)) throw new IOException("请将桌面程序与 sqlyog-no-popup.ps1 放在同一目录。");
            ProcessStartInfo start = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + script + "\" " + action + " -Path \"" + Path.GetFullPath(path) + "\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using (Process process = Process.Start(start))
            {
                var output = process.StandardOutput.ReadToEndAsync();
                var error = process.StandardError.ReadToEndAsync();
                process.WaitForExit();
                string errorText = error.Result.Trim();
                if (process.ExitCode != 0) throw new IOException(errorText);
                return output.Result;
            }
        }

        public static FileState Inspect(string path)
        {
            string output = Run("status", path);
            if (output.Contains("Status: original")) return FileState.Original;
            if (output.Contains("Status: patched")) return FileState.Patched;
            return FileState.Unsupported;
        }

        public static string ChangeFile(string path, bool restore)
        {
            Run(restore ? "restore" : "apply", path);
            return restore ? "已恢复原样。" : "已去掉退出推广弹窗，并保留原版备份。";
        }
    }

    internal sealed class MainWindow : Form
    {
        private readonly TextBox filePath = new TextBox();
        private readonly Label status = new Label();
        private readonly Button apply = new Button();
        private readonly Button restore = new Button();

        public MainWindow()
        {
            Text = "SQLyog 退出弹窗工具";
            Font = new Font("Microsoft YaHei UI", 10F);
            AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(660, 290);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.White;

            Label title = new Label { Text = "去掉 SQLyog 退出推广弹窗", Location = new Point(24, 22), AutoSize = true, Font = new Font(Font.FontFamily, 15F, FontStyle.Bold) };
            Label hint = new Label { Text = "支持已验证的社区版 13.1.6–13.3.1（64 位）。请先关闭 SQLyog。", Location = new Point(24, 62), AutoSize = true };
            filePath.SetBounds(24, 101, 502, 30);
            filePath.ReadOnly = true;
            Button browse = new Button { Text = "选择程序", Location = new Point(536, 98), Size = new Size(100, 34) };
            browse.Click += delegate
            {
                using (OpenFileDialog picker = new OpenFileDialog())
                {
                    picker.Title = "选择 SQLyogCommunity.exe";
                    picker.Filter = "SQLyog 程序 (SQLyogCommunity.exe)|SQLyogCommunity.exe|程序文件 (*.exe)|*.exe";
                    if (File.Exists(filePath.Text)) picker.InitialDirectory = Path.GetDirectoryName(filePath.Text);
                    if (picker.ShowDialog(this) == DialogResult.OK) { filePath.Text = picker.FileName; RefreshStatus(); }
                }
            };
            status.SetBounds(24, 148, 612, 40);
            apply.Text = "去掉弹窗";
            apply.SetBounds(24, 210, 160, 42);
            restore.Text = "恢复原样";
            restore.SetBounds(196, 210, 160, 42);
            apply.Click += delegate { Change(false); };
            restore.Click += delegate { Change(true); };
            Label footer = new Label { Text = "自动备份 · 文件不匹配时不会修改", Location = new Point(374, 222), AutoSize = true, ForeColor = Color.DimGray };
            Controls.AddRange(new Control[] { title, hint, filePath, browse, status, apply, restore, footer });
            filePath.Text = FindInstalledProgram();
            RefreshStatus();
        }

        private static string FindInstalledProgram()
        {
            RegistryHive[] hives = { RegistryHive.CurrentUser, RegistryHive.LocalMachine };
            RegistryView[] views = { RegistryView.Registry64, RegistryView.Registry32 };
            foreach (RegistryHive hive in hives)
                foreach (RegistryView view in views)
                    try
                    {
                        using (RegistryKey root = RegistryKey.OpenBaseKey(hive, view))
                        using (RegistryKey uninstall = root.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"))
                        {
                            if (uninstall == null) continue;
                            foreach (string name in uninstall.GetSubKeyNames())
                                using (RegistryKey entry = uninstall.OpenSubKey(name))
                                {
                                    if (entry == null) continue;
                                    string display = Convert.ToString(entry.GetValue("DisplayName"));
                                    if (display.IndexOf("SQLyog Community", StringComparison.OrdinalIgnoreCase) < 0) continue;
                                    string folder = Convert.ToString(entry.GetValue("InstallLocation"));
                                    if (String.IsNullOrWhiteSpace(folder)) continue;
                                    string exe = Path.Combine(folder, "SQLyogCommunity.exe");
                                    if (File.Exists(exe)) return exe;
                                }
                        }
                    }
                    catch { /* A manual file picker remains available. */ }
            return "";
        }

        private void RefreshStatus()
        {
            apply.Enabled = restore.Enabled = false;
            status.ForeColor = Color.DimGray;
            if (!File.Exists(filePath.Text)) { status.Text = "请选择 SQLyogCommunity.exe。"; return; }
            try
            {
                FileState state = PatchService.Inspect(filePath.Text);
                if (state == FileState.Original)
                {
                    status.Text = "已识别：支持的原版。可以去掉退出弹窗。";
                    status.ForeColor = Color.FromArgb(30, 110, 60);
                    apply.Enabled = true;
                }
                else if (state == FileState.Patched)
                {
                    status.Text = "已识别：退出弹窗已经去掉。可以恢复原样。";
                    status.ForeColor = Color.FromArgb(30, 110, 60);
                    restore.Enabled = true;
                }
                else { status.Text = "这个程序文件暂不支持，不会修改。"; status.ForeColor = Color.FromArgb(160, 80, 20); }
            }
            catch (Exception exception) { status.Text = "无法检查文件：" + exception.Message; }
        }

        private void Change(bool restoring)
        {
            apply.Enabled = restore.Enabled = false;
            UseWaitCursor = true;
            try { MessageBox.Show(this, PatchService.ChangeFile(filePath.Text, restoring), "操作完成", MessageBoxButtons.OK, MessageBoxIcon.Information); }
            catch (Exception exception) { MessageBox.Show(this, exception.Message, "未完成", MessageBoxButtons.OK, MessageBoxIcon.Information); }
            finally { UseWaitCursor = false; RefreshStatus(); }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainWindow());
        }
    }
}
