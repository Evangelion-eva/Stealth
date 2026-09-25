param(
    [switch]$Console = $false
)

<#
    ==========================================================================
    UNIVERSAL STEALTH OVERLAY & AI COPILOT v2.2 (Precision-Formatted & Hardened)
    - Multi-Window Universal: Works on ANY window / IDE / browser / exam portal
    - Screen-Capture Undetectable: Uses SetWindowDisplayAffinity (0x11)
    - Full Quiz & Coding Optimization: Standard Class Solution Format
    - Windows CRLF Formatting with Clean Layout & Non-Overlapping Title Bar
    - Working [X] Cut/Close Button (WM_NCHITTEST safe) & Esc Dismissal
    - Infinite-Loop-Proof Single-Shot Screenshot Engine (Opacity-based)
    - Direct DOM Extraction from Active Browser Tab (Zero OCR Lag)
    - Dedicated Settings Panel for API Keys, Dot Toggles, and Preferences
    ==========================================================================
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime -EA SilentlyContinue

try { [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException) } catch {}
try { [System.Windows.Forms.Application]::add_ThreadException({ param($s,$e) }) } catch {}

# --- WinRT Native OCR Helper Types ---
try {
    [void][Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
    [void][Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
    [void][Windows.Graphics.Imaging.BitmapDecoder,Windows.Foundation,ContentType=WindowsRuntime]
    $script:asTaskMethod = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 }) |
        Select-Object -First 1
} catch {}

function Wait-WinRtTask($asyncOp, $returnType, $timeoutMs = 5000) {
    if (-not $script:asTaskMethod -or -not $asyncOp) { return $null }
    try {
        $genMethod = $script:asTaskMethod.MakeGenericMethod($returnType)
        $task = $genMethod.Invoke($null, @($asyncOp))
        if (-not $task.Wait($timeoutMs)) {
            Write-Log "ERR" "WinRT async task timed out after $($timeoutMs)ms."
            return $null
        }
        return $task.Result
    } catch {
        Write-Log "ERR" "Wait-WinRtTask error: $($_.Exception.Message)"
        return $null
    }
}

# --- Win32 Native API & Window Styles ---
$winApiCode = @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;

public class StealthAPI {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowDisplayAffinity(IntPtr hWnd, uint dwAffinity);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr h, int n);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr h, int n, int v);

    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr wp, IntPtr lp);

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr h, int id, uint mod, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr h, int id);

    [DllImport("gdi32.dll", EntryPoint = "CreateRoundRectRgn")]
    public static extern IntPtr CreateRoundRectRgn(int nLeft, int nTop, int nRight, int nBottom, int nWidthEllipse, int nHeightEllipse);

    public const int GWL_EXSTYLE        = -20;
    public const int WS_EX_TOOLWINDOW   = 0x00000080;
    public const int WS_EX_APPWINDOW    = 0x00040000;
    public const int WS_EX_NOACTIVATE   = 0x08000000;
    public const uint SWP_NOMOVE        = 0x0002;
    public const uint SWP_NOSIZE        = 0x0001;
    public const uint SWP_FRAMECHANGED  = 0x0020;
    public const int WM_NCLBUTTONDOWN   = 0x00A1;
    public const int HTCAPTION          = 2;
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);

    public const uint WDA_NONE               = 0x00000000;
    public const uint WDA_MONITOR            = 0x00000001;
    public const uint WDA_EXCLUDEFROMCAPTURE = 0x00000011;

    public static bool ApplyStealthAffinity(IntPtr hWnd, bool enable = true) {
        try {
            if (!enable) {
                return SetWindowDisplayAffinity(hWnd, WDA_NONE);
            }
            bool res = SetWindowDisplayAffinity(hWnd, WDA_EXCLUDEFROMCAPTURE);
            if (!res) {
                res = SetWindowDisplayAffinity(hWnd, WDA_MONITOR);
            }
            return res;
        } catch {
            return false;
        }
    }
}

public class StealthHotkeyNW : NativeWindow {
    const int WM_HOTKEY = 0x0312;
    public static int LastKey = 0;
    public const uint MOD_ALT = 1, MOD_CTRL = 2, MOD_SHIFT = 4, MOD_WIN = 8;
    public StealthHotkeyNW(IntPtr h) { AssignHandle(h); }
    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY) {
            LastKey = m.WParam.ToInt32();
        }
        base.WndProc(ref m);
    }
}

public class ResizableBorderNW : NativeWindow {
    const int WM_NCHITTEST=0x84, HTLEFT=10, HTRIGHT=11, HTTOP=12, HTTOPLEFT=13, HTTOPRIGHT=14, HTBOTTOM=15, HTBOTTOMLEFT=16, HTBOTTOMRIGHT=17, HTCLIENT=1;
    Form _f; int _g;
    public ResizableBorderNW(Form f, int grip=6) { _f = f; _g = grip; AssignHandle(f.Handle); }
    protected override void WndProc(ref Message m) {
        base.WndProc(ref m);
        if (m.Msg == WM_NCHITTEST && (int)m.Result == HTCLIENT) {
            int lp = m.LParam.ToInt32();
            var p = _f.PointToClient(new Point(lp & 0xFFFF, lp >> 16));
            int x = p.X, y = p.Y, w = _f.Width, h = _f.Height, g = _g;
            // CRITICAL: Do NOT intercept top-right button zone (Close, Copy, Lang buttons) as resize grip!
            if (y < 42 && x > w - 280) {
                return;
            }
            if (x < g && y < g) m.Result = (IntPtr)HTTOPLEFT;
            else if (x > w - g && y < g) m.Result = (IntPtr)HTTOPRIGHT;
            else if (x < g && y > h - g) m.Result = (IntPtr)HTBOTTOMLEFT;
            else if (x > w - g && y > h - g) m.Result = (IntPtr)HTBOTTOMRIGHT;
            else if (x < g) m.Result = (IntPtr)HTLEFT;
            else if (x > w - g) m.Result = (IntPtr)HTRIGHT;
            else if (y < g) m.Result = (IntPtr)HTTOP;
            else if (y > h - g) m.Result = (IntPtr)HTBOTTOM;
        }
    }
}
"@

Add-Type -TypeDefinition $winApiCode -ReferencedAssemblies "System.Windows.Forms", "System.Drawing" -ErrorAction Stop

# --- Configuration & State ---
$configFile = Join-Path $PSScriptRoot 'config.json'
$script:winX = -1
$script:winY = -1
$script:winW = 480
$script:winH = 280

$script:config = [PSCustomObject]@{
    ShowConsole      = $Console.IsPresent
    StealthAffinity  = $true
    DefaultMode      = "auto"
    AnswerTimeoutSec = 40
    CamouflageMode   = "dark"
    WindowPos        = [PSCustomObject]@{
        X = -1
        Y = -1
        W = 480
        H = 280
    }
    Hotkeys          = [PSCustomObject]@{
        AutoSolve  = "Ctrl+Shift+T"
        TabSolve   = "Ctrl+Shift+S"
        Java       = "Ctrl+Shift+J"
        Cpp        = "Ctrl+Shift+C"
        Python     = "Ctrl+Shift+Y"
        Browser    = "Ctrl+Shift+B"
        Screenshot = "Ctrl+Shift+P"
        Panic      = "Ctrl+Shift+Q"
    }
    Buttons          = [PSCustomObject]@{
        Screenshot = $true
        Browser    = $true
        AutoSolve  = $true
        TabSolve   = $true
        Java       = $true
        Cpp        = $true
        Python     = $true
        Settings   = $true
    }
    Keys             = @()
}

function Load-Config {
    if (Test-Path $configFile) {
        try {
            $json = Get-Content $configFile -Raw | ConvertFrom-Json
            if ($json.PSObject.Properties['ShowConsole'])      { $script:config.ShowConsole      = [bool]$json.ShowConsole }
            if ($json.PSObject.Properties['StealthAffinity'])  { $script:config.StealthAffinity  = [bool]$json.StealthAffinity }
            if ($json.PSObject.Properties['DefaultMode'])      { $script:config.DefaultMode      = [string]$json.DefaultMode }
            if ($json.PSObject.Properties['AnswerTimeoutSec']) { $script:config.AnswerTimeoutSec = [int]$json.AnswerTimeoutSec }
            if ($json.PSObject.Properties['CamouflageMode'])   { $script:config.CamouflageMode   = [string]$json.CamouflageMode }
            if ($json.PSObject.Properties['WindowPos'] -and $json.WindowPos) {
                if ($json.WindowPos.PSObject.Properties['X']) { $script:config.WindowPos.X = [int]$json.WindowPos.X; $script:winX = [int]$json.WindowPos.X }
                if ($json.WindowPos.PSObject.Properties['Y']) { $script:config.WindowPos.Y = [int]$json.WindowPos.Y; $script:winY = [int]$json.WindowPos.Y }
                if ($json.WindowPos.PSObject.Properties['W']) { $script:config.WindowPos.W = [int]$json.WindowPos.W; $script:winW = [int]$json.WindowPos.W }
                if ($json.WindowPos.PSObject.Properties['H']) { $script:config.WindowPos.H = [int]$json.WindowPos.H; $script:winH = [int]$json.WindowPos.H }
            }
            if ($json.PSObject.Properties['Hotkeys'] -and $json.Hotkeys) {
                foreach ($prop in $json.Hotkeys.PSObject.Properties) {
                    $script:config.Hotkeys.$($prop.Name) = [string]$prop.Value
                }
            }
            if ($json.PSObject.Properties['Buttons']) {
                foreach ($prop in $json.Buttons.PSObject.Properties) {
                    $script:config.Buttons.$($prop.Name) = [bool]$prop.Value
                }
            }
            if ($json.PSObject.Properties['Keys']) {
                $script:config.Keys = @($json.Keys)
            }
        } catch {
            Write-Log "ERR" "Failed to parse config.json: $($_.Exception.Message)"
        }
    }

    if ($script:config.Keys.Count -eq 0) {
        $keysTxt = Join-Path $PSScriptRoot 'keys.txt'
        if (Test-Path $keysTxt) {
            Get-Content $keysTxt | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } | ForEach-Object {
                $parts = $_.Trim() -split ':', 2
                if ($parts.Count -eq 2) {
                    $script:config.Keys += [PSCustomObject]@{ Provider = $parts[0].Trim().ToLower(); Key = $parts[1].Trim() }
                }
            }
        }
    }
    if ($Console.IsPresent) { $script:config.ShowConsole = $true }
}

function Save-Config {
    try {
        $script:config | ConvertTo-Json -Depth 5 | Out-File $configFile -Encoding UTF8 -Force
        $keysTxt = Join-Path $PSScriptRoot 'keys.txt'
        $lines = @("# Universal Stealth Assistant Keys")
        foreach ($k in $script:config.Keys) {
            $lines += "$($k.Provider):$($k.Key)"
        }
        $lines | Out-File $keysTxt -Encoding UTF8 -Force
        Write-Log "INFO" "Configuration saved successfully."
    } catch {
        Write-Log "ERR" "Error saving config: $($_.Exception.Message)"
    }
}

# --- Logging System ---
$script:guiLogForm = $null
$script:guiLogBox  = $null

function Write-Log {
    param(
        [string]$Tag = "INFO",
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    $ts = (Get-Date).ToString("HH:mm:ss.fff")
    $logLine = "[$ts] [$Tag] $Message"

    $c = switch ($Tag) {
        "OCR"   { [ConsoleColor]::Yellow }
        "AI"    { [ConsoleColor]::Cyan }
        "TAB"   { [ConsoleColor]::Magenta }
        "KEY"   { [ConsoleColor]::Green }
        "ERR"   { [ConsoleColor]::Red }
        "WARN"  { [ConsoleColor]::DarkYellow }
        default { [ConsoleColor]::White }
    }

    if ($script:config.ShowConsole) {
        Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
        Write-Host "[$Tag] " -NoNewline -ForegroundColor $c
        Write-Host "$Message" -ForegroundColor $Color
    }

    if ($script:guiLogBox -and -not $script:guiLogBox.IsDisposed) {
        try {
            $script:guiLogBox.AppendText("$logLine`r`n")
            $script:guiLogBox.SelectionStart = $script:guiLogBox.TextLength
            $script:guiLogBox.ScrollToCaret()
        } catch {}
    }
}

function Show-LogWindow {
    if ($script:guiLogForm -and -not $script:guiLogForm.IsDisposed) {
        $script:guiLogForm.BringToFront()
        return
    }

    $lf = New-Object System.Windows.Forms.Form
    $lf.Text            = "Stealth Assistant - Live Console & Logs"
    $lf.Size            = New-Object System.Drawing.Size(720, 450)
    $lf.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $lf.BackColor       = [System.Drawing.Color]::FromArgb(18, 20, 26)
    $lf.TopMost         = $true

    $tb = New-Object System.Windows.Forms.Panel
    $tb.Dock = [System.Windows.Forms.DockStyle]::Top; $tb.Height = 32
    $tb.BackColor = [System.Drawing.Color]::FromArgb(26, 28, 36)

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Clear Logs"; $btnClear.Dock = [System.Windows.Forms.DockStyle]::Right; $btnClear.Width = 90
    $btnClear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnClear.BackColor = [System.Drawing.Color]::FromArgb(40,40,55); $btnClear.ForeColor = [System.Drawing.Color]::White

    $tb.Controls.Add($btnClear)

    $rtb = New-Object System.Windows.Forms.TextBox
    $rtb.Multiline  = $true
    $rtb.ReadOnly   = $true
    $rtb.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $rtb.Dock       = [System.Windows.Forms.DockStyle]::Fill
    $rtb.BackColor  = [System.Drawing.Color]::FromArgb(12, 14, 18)
    $rtb.ForeColor  = [System.Drawing.Color]::FromArgb(210, 225, 240)
    $rtb.Font       = New-Object System.Drawing.Font("Consolas", 9.5)
    $rtb.BorderStyle = [System.Windows.Forms.BorderStyle]::None

    $btnClear.Add_Click({ $rtb.Clear() })

    $lf.Controls.Add($rtb)
    $lf.Controls.Add($tb)

    [StealthAPI]::ApplyStealthAffinity($lf.Handle, $script:config.StealthAffinity) | Out-Null
    $script:guiLogForm = $lf
    $script:guiLogBox  = $rtb
    $lf.Show()
    Write-Log "INFO" "Live log console opened."
}

# --- Initialize WebView2 SDK ---
$sdk  = "$PSScriptRoot\wv2sdk"
$core = "$sdk\Microsoft.Web.WebView2.Core.dll"
$wf   = "$sdk\Microsoft.Web.WebView2.WinForms.dll"
$ldr  = "$sdk\WebView2Loader.dll"

if (!(Test-Path $core) -or !(Test-Path $wf) -or !(Test-Path $ldr)) {
    New-Item -ItemType Directory -Force $sdk | Out-Null
    Write-Log "INFO" "Downloading WebView2 SDK (~500KB)..."
    $zip = "$sdk\wv2.zip"
    Invoke-WebRequest "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.2792.45" -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath "$sdk\pkg" -Force
    Copy-Item "$sdk\pkg\lib\net462\Microsoft.Web.WebView2.Core.dll"     $sdk -Force
    Copy-Item "$sdk\pkg\lib\net462\Microsoft.Web.WebView2.WinForms.dll" $sdk -Force
    $arch = if ([IntPtr]::Size -eq 8) { "x64" } else { "x86" }
    Copy-Item "$sdk\pkg\build\native\$arch\WebView2Loader.dll"          $sdk -Force
    Remove-Item "$sdk\pkg" -Recurse -Force
    Remove-Item $zip -Force
}

try { Add-Type -Path $core -ErrorAction Stop } catch {}
try { Add-Type -Path $wf   -ErrorAction Stop } catch {}

Load-Config
Write-Log "INFO" "Configuration loaded. Found $($script:config.Keys.Count) API keys."

$script:aiKeyIndex    = 0
$script:currentMode   = $script:config.DefaultMode
$script:latestOCRText = ""
$script:latestCode    = ""
$script:latestAns     = ""
$script:aiLabel       = $null
$script:aiTimer       = $null
$script:codeForm      = $null

# Persistent async references
$script:aiRs          = $null
$script:aiPs          = $null
$script:aiHandle      = $null
$script:aiPollTimer   = $null

# Native OCR Temporary Paths
$script:ocrImgTmp = "$env:TEMP\stealth_ocr_in.png"
$script:ocrWrkTmp = "$env:TEMP\stealth_ocr_wrk.ps1"
$script:ocrResTmp = "$env:TEMP\stealth_ocr_res.txt"
$script:ocrBusy   = $false

# --- 100% Transparent Floating Display Windows with Adaptive Camouflage & Memory ---
$script:keyColor = [System.Drawing.Color]::FromArgb(1, 1, 1)

function Show-CodeSolution {
    param(
        [string]$CodeText,
        [string]$Lang = "Java"
    )
    if (-not $CodeText) { return }

    if ($script:codeForm -and -not $script:codeForm.IsDisposed) {
        try { $script:codeForm.Close(); $script:codeForm.Dispose() } catch {}
        $script:codeForm = $null
    }
    if ($script:aiLabel -and -not $script:aiLabel.IsDisposed) {
        try { $script:aiLabel.Close(); $script:aiLabel.Dispose() } catch {}
        $script:aiLabel = $null
    }

    $cleanCode = $CodeText.Trim()
    if ($cleanCode -match '(?s)```(?:[a-zA-Z0-9_#\+\-]+)?\s*[\r\n]+(.*?)\s*```') {
        $cleanCode = $matches[1].Trim()
    }
    if ($cleanCode -notmatch "`n" -and $cleanCode -match '\\n') {
        $cleanCode = $cleanCode.Replace('\r\n', "`r`n").Replace('\n', "`r`n").Replace('\t', "    ")
    }

    $cleanLines = @()
    $maxLineLen = 25
    foreach ($line in ($cleanCode -split "\r?\n")) {
        $cleanLines += $line
        if ($line.Length -gt $maxLineLen) { $maxLineLen = $line.Length }
    }
    $cleanCode = $cleanLines -join "`r`n"
    $script:latestCodeToCopy = $cleanCode

    $displayLang = if ($Lang -and $Lang.Trim() -ne "" -and $Lang -ne "auto") { $Lang.ToUpper() } else { "CODE" }
    $scr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

    # Remembered Size & Position Logic
    $hasSavedPos = ($script:winX -gt 0 -and $script:winY -gt 0)
    $posX = if ($hasSavedPos) { $script:winX } else { [Math]::Max(20, [int]($scr.Width - 520)) }
    $posY = if ($hasSavedPos) { $script:winY } else { 32 }
    
    $calcW = if ($script:winW -gt 200) {
        $script:winW
    } else {
        [Math]::Max(380, [Math]::Min(680, [int]($maxLineLen * 8.2 + 36)))
    }
    $calcH = if ($script:winH -gt 100) {
        $script:winH
    } else {
        [Math]::Max(140, [Math]::Min(480, [int]($cleanLines.Count * 17.5 + 38)))
    }

    $cf = New-Object System.Windows.Forms.Form
    $cf.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $cf.Size            = New-Object System.Drawing.Size($calcW, $calcH)
    $cf.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
    $cf.Location        = New-Object System.Drawing.Point($posX, $posY)
    $cf.BackColor       = $script:keyColor
    $cf.TransparencyKey = $script:keyColor
    $cf.TopMost         = $true
    $cf.ShowInTaskbar   = $false
    $cf.KeyPreview      = $true

    [void]$cf.Handle
    [StealthAPI]::ApplyStealthAffinity($cf.Handle, $script:config.StealthAffinity) | Out-Null
    $ex = [StealthAPI]::GetWindowLong($cf.Handle, [StealthAPI]::GWL_EXSTYLE)
    [StealthAPI]::SetWindowLong($cf.Handle, [StealthAPI]::GWL_EXSTYLE, $ex -bor [StealthAPI]::WS_EX_TOOLWINDOW) | Out-Null
    [StealthAPI]::SetWindowPos($cf.Handle, [StealthAPI]::HWND_TOPMOST, $posX, $posY, $calcW, $calcH, ([StealthAPI]::SWP_SHOWWINDOW -bor [StealthAPI]::SWP_NOACTIVATE)) | Out-Null

    # Header Bar: 100% Transparent
    $tb = New-Object System.Windows.Forms.Panel
    $tb.Dock      = [System.Windows.Forms.DockStyle]::Top
    $tb.Height    = 22
    $tb.BackColor = $script:keyColor
    $tb.Padding   = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)

    $langBadge = New-Object System.Windows.Forms.Label
    $langBadge.Text      = "[$displayLang]"
    $langBadge.Dock      = [System.Windows.Forms.DockStyle]::Left
    $langBadge.AutoSize  = $true
    $langBadge.BackColor = $script:keyColor
    $langBadge.ForeColor = [System.Drawing.Color]::FromArgb(56, 189, 248)
    $langBadge.Font      = New-Object System.Drawing.Font("Segoe UI", 8.0, [System.Drawing.FontStyle]::Bold)
    $langBadge.Cursor    = [System.Windows.Forms.Cursors]::SizeAll

    # Contrast Invert Button (Camouflage for White vs Dark backgrounds)
    $btnInv = New-Object System.Windows.Forms.Button
    $btnInv.Text = if ($script:config.CamouflageMode -eq "light") { "Lit" } else { "Inv" }
    $btnInv.Size = New-Object System.Drawing.Size(32, 18)
    $btnInv.Dock = [System.Windows.Forms.DockStyle]::Left
    $btnInv.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnInv.FlatAppearance.BorderSize = 0
    $btnInv.BackColor = if ($script:config.CamouflageMode -eq "light") { [System.Drawing.Color]::FromArgb(200, 210, 225) } else { [System.Drawing.Color]::FromArgb(40, 45, 60) }
    $btnInv.ForeColor = if ($script:config.CamouflageMode -eq "light") { [System.Drawing.Color]::Black } else { [System.Drawing.Color]::White }
    $btnInv.Font = New-Object System.Drawing.Font("Segoe UI", 7.0, [System.Drawing.FontStyle]::Bold)
    $btnInv.Cursor = [System.Windows.Forms.Cursors]::Hand

    $closeAction = {
        if ($script:codeForm -and -not $script:codeForm.IsDisposed) {
            try { $script:codeForm.Close(); $script:codeForm.Dispose() } catch {}
            $script:codeForm = $null
        }
    }

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "X"
    $btnClose.Size = New-Object System.Drawing.Size(20, 18)
    $btnClose.Dock = [System.Windows.Forms.DockStyle]::Right
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
    $btnClose.ForeColor = [System.Drawing.Color]::White
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.TabStop = $false
    $btnClose.Add_Click($closeAction)
    $btnClose.Add_MouseDown({ param($s,$e) & $closeAction })

    # Guaranteed Working Copy Button (Using Tag + Retry Loop)
    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy"
    $btnCopy.Tag  = $cleanCode
    $btnCopy.Size = New-Object System.Drawing.Size(42, 18)
    $btnCopy.Dock = [System.Windows.Forms.DockStyle]::Right
    $btnCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopy.FlatAppearance.BorderSize = 0
    $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $btnCopy.ForeColor = [System.Drawing.Color]::White
    $btnCopy.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    $btnCopy.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnCopy.TabStop = $false
    $btnCopy.Add_Click({
        param($s,$e)
        $txtToCopy = [string]$s.Tag
        if (-not $txtToCopy) { $txtToCopy = $script:latestCodeToCopy }
        if ($txtToCopy) {
            for ($attempt = 0; $attempt -lt 5; $attempt++) {
                try {
                    [System.Windows.Forms.Clipboard]::SetText($txtToCopy)
                    break
                } catch {
                    Start-Sleep -Milliseconds 40
                }
            }
            $s.Text = "OK"
            $s.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
            $rt = New-Object System.Windows.Forms.Timer; $rt.Interval = 900
            $rt.Add_Tick({ param($snd,$ev) $s.Text = "Copy"; $s.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $snd.Stop(); $snd.Dispose() })
            $rt.Start()
        }
    })

    $tb.Controls.Add($langBadge)
    $tb.Controls.Add($btnInv)
    $tb.Controls.Add($btnCopy)
    $tb.Controls.Add($btnClose)

    # Safe Drag Support
    foreach ($ctl in @($tb, $langBadge)) {
        $ctl.Add_MouseDown({
            param($s,$e)
            if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
                [StealthAPI]::ReleaseCapture() | Out-Null
                $targetH = if ($s -is [System.Windows.Forms.Form]) { $s.Handle } else { $s.FindForm().Handle }
                if ($targetH) {
                    [StealthAPI]::SendMessage($targetH, [StealthAPI]::WM_NCLBUTTONDOWN, ([IntPtr]([StealthAPI]::HTCAPTION)), [IntPtr]::Zero) | Out-Null
                }
            }
        })
    }

    # Code Display Box (100% Transparent Background, Adaptive High-Contrast Font)
    $txtCode = New-Object System.Windows.Forms.TextBox
    $txtCode.Multiline   = $true
    $txtCode.ReadOnly    = $false
    $txtCode.ScrollBars  = if ($cleanLines.Count -gt 22) { [System.Windows.Forms.ScrollBars]::Vertical } else { [System.Windows.Forms.ScrollBars]::None }
    $txtCode.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $txtCode.BackColor   = $script:keyColor
    $txtCode.Font        = New-Object System.Drawing.Font("Consolas", 10.0, [System.Drawing.FontStyle]::Bold)
    $txtCode.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtCode.WordWrap    = $false
    $txtCode.AcceptsTab  = $true
    $txtCode.Text        = $cleanCode

    # Apply Camouflage Colors
    if ($script:config.CamouflageMode -eq "light") {
        $txtCode.ForeColor   = [System.Drawing.Color]::FromArgb(15, 23, 42) # Jet dark for white background
        $langBadge.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    } else {
        $txtCode.ForeColor   = [System.Drawing.Color]::FromArgb(248, 250, 252) # Pure white for dark background
        $langBadge.ForeColor = [System.Drawing.Color]::FromArgb(56, 189, 248)
    }

    # Invert Contrast Toggle on Inv click
    $btnInv.Add_Click({
        if ($script:config.CamouflageMode -eq "light") {
            $script:config.CamouflageMode = "dark"
            $txtCode.ForeColor   = [System.Drawing.Color]::FromArgb(248, 250, 252)
            $langBadge.ForeColor = [System.Drawing.Color]::FromArgb(56, 189, 248)
            $btnInv.Text = "Inv"
            $btnInv.BackColor = [System.Drawing.Color]::FromArgb(40, 45, 60)
            $btnInv.ForeColor = [System.Drawing.Color]::White
        } else {
            $script:config.CamouflageMode = "light"
            $txtCode.ForeColor   = [System.Drawing.Color]::FromArgb(15, 23, 42)
            $langBadge.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
            $btnInv.Text = "Lit"
            $btnInv.BackColor = [System.Drawing.Color]::FromArgb(200, 210, 225)
            $btnInv.ForeColor = [System.Drawing.Color]::Black
        }
        Save-Config
    })

    $pnlBody = New-Object System.Windows.Forms.Panel
    $pnlBody.Dock    = [System.Windows.Forms.DockStyle]::Fill
    $pnlBody.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 6)
    $pnlBody.BackColor = $script:keyColor
    $pnlBody.Controls.Add($txtCode)

    $escAction = {
        param($s, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            & $closeAction
        }
    }
    $cf.Add_KeyDown($escAction)
    $txtCode.Add_KeyDown($escAction)

    # Track and Remember Position & Size
    $cf.Add_LocationChanged({
        param($s,$e)
        if ($s.Location.X -gt 0 -and $s.Location.Y -gt 0) {
            $script:winX = $s.Location.X
            $script:winY = $s.Location.Y
            $script:config.WindowPos.X = $s.Location.X
            $script:config.WindowPos.Y = $s.Location.Y
        }
    })
    $cf.Add_SizeChanged({
        param($s,$e)
        if ($s.Width -gt 200 -and $s.Height -gt 100) {
            $script:winW = $s.Width
            $script:winH = $s.Height
            $script:config.WindowPos.W = $s.Width
            $script:config.WindowPos.H = $s.Height
        }
    })

    # Border resize support
    $resNW = New-Object ResizableBorderNW($cf, 6)

    $cf.Controls.Add($pnlBody)
    $cf.Controls.Add($tb)
    $tb.SendToBack()

    $cf.Show()
    $cf.BringToFront()
    $script:codeForm = $cf
    Write-Log "INFO" "Rendered clean Code window: [$displayLang]."
}

function Show-QuizAnswer {
    param([string]$Answer)
    if (-not $Answer) { return }

    if ($script:aiTimer) { try { $script:aiTimer.Stop(); $script:aiTimer.Dispose() } catch {}; $script:aiTimer = $null }
    if ($script:aiLabel) { try { $script:aiLabel.Close(); $script:aiLabel.Dispose() } catch {}; $script:aiLabel = $null }
    if ($script:codeForm) { try { $script:codeForm.Close(); $script:codeForm.Dispose() } catch {}; $script:codeForm = $null }

    # Clean lines and count
    $lines = @()
    $maxLineLen = 25
    foreach ($line in ($Answer -split "\r?\n")) {
        $t = $line.Trim()
        if ($t -ne '') {
            $lines += $t
            if ($t.Length -gt $maxLineLen) { $maxLineLen = $t.Length }
        }
    }

    $finalAnswerText = $lines -join "`r`n"
    $script:latestCodeToCopy = $finalAnswerText
    $scr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

    # Remembered Size & Position Logic
    $hasSavedPos = ($script:winX -gt 0 -and $script:winY -gt 0)
    $ansX = if ($hasSavedPos) { $script:winX } else { [Math]::Max(20, [int]($scr.Width - 520)) }
    $ansY = if ($hasSavedPos) { $script:winY } else { 32 }
    
    $ansW = if ($script:winW -gt 200) {
        $script:winW
    } else {
        [Math]::Max(360, [Math]::Min(640, [int]($maxLineLen * 8.2 + 36)))
    }
    $ansH = if ($script:winH -gt 100) {
        $script:winH
    } else {
        [Math]::Max(110, [Math]::Min(420, [int]($lines.Count * 21.0 + 38)))
    }

    $af = New-Object System.Windows.Forms.Form
    $af.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $af.Size            = New-Object System.Drawing.Size($ansW, $ansH)
    $af.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
    $af.Location        = New-Object System.Drawing.Point($ansX, $ansY)
    $af.BackColor       = $script:keyColor
    $af.TransparencyKey = $script:keyColor
    $af.TopMost         = $true
    $af.ShowInTaskbar   = $false
    $af.KeyPreview      = $true

    [void]$af.Handle
    [StealthAPI]::ApplyStealthAffinity($af.Handle, $script:config.StealthAffinity) | Out-Null
    $ex = [StealthAPI]::GetWindowLong($af.Handle, [StealthAPI]::GWL_EXSTYLE)
    [StealthAPI]::SetWindowLong($af.Handle, [StealthAPI]::GWL_EXSTYLE, $ex -bor [StealthAPI]::WS_EX_TOOLWINDOW) | Out-Null
    [StealthAPI]::SetWindowPos($af.Handle, [StealthAPI]::HWND_TOPMOST, $ansX, $ansY, $ansW, $ansH, ([StealthAPI]::SWP_SHOWWINDOW -bor [StealthAPI]::SWP_NOACTIVATE)) | Out-Null

    # Header Bar: 100% Transparent
    $tb = New-Object System.Windows.Forms.Panel
    $tb.Dock      = [System.Windows.Forms.DockStyle]::Top
    $tb.Height    = 22
    $tb.BackColor = $script:keyColor
    $tb.Padding   = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)

    $badge = New-Object System.Windows.Forms.Label
    $badge.Text      = "[Ans]"
    $badge.Dock      = [System.Windows.Forms.DockStyle]::Left
    $badge.AutoSize  = $true
    $badge.BackColor = $script:keyColor
    $badge.ForeColor = [System.Drawing.Color]::FromArgb(52, 211, 153)
    $badge.Font      = New-Object System.Drawing.Font("Segoe UI", 8.0, [System.Drawing.FontStyle]::Bold)
    $badge.Cursor    = [System.Windows.Forms.Cursors]::SizeAll

    # Contrast Invert Button (Camouflage for White vs Dark backgrounds)
    $btnInv = New-Object System.Windows.Forms.Button
    $btnInv.Text = if ($script:config.CamouflageMode -eq "light") { "Lit" } else { "Inv" }
    $btnInv.Size = New-Object System.Drawing.Size(32, 18)
    $btnInv.Dock = [System.Windows.Forms.DockStyle]::Left
    $btnInv.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnInv.FlatAppearance.BorderSize = 0
    $btnInv.BackColor = if ($script:config.CamouflageMode -eq "light") { [System.Drawing.Color]::FromArgb(200, 210, 225) } else { [System.Drawing.Color]::FromArgb(40, 45, 60) }
    $btnInv.ForeColor = if ($script:config.CamouflageMode -eq "light") { [System.Drawing.Color]::Black } else { [System.Drawing.Color]::White }
    $btnInv.Font = New-Object System.Drawing.Font("Segoe UI", 7.0, [System.Drawing.FontStyle]::Bold)
    $btnInv.Cursor = [System.Windows.Forms.Cursors]::Hand

    $dismissAction = {
        if ($script:aiTimer) { try { $script:aiTimer.Stop(); $script:aiTimer.Dispose() } catch {}; $script:aiTimer = $null }
        if ($script:aiLabel) { try { $script:aiLabel.Close(); $script:aiLabel.Dispose() } catch {}; $script:aiLabel = $null }
    }

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "X"
    $btnClose.Size = New-Object System.Drawing.Size(20, 18)
    $btnClose.Dock = [System.Windows.Forms.DockStyle]::Right
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
    $btnClose.ForeColor = [System.Drawing.Color]::White
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.TabStop = $false
    $btnClose.Add_Click($dismissAction)
    $btnClose.Add_MouseDown({ param($s,$e) & $dismissAction })

    # Guaranteed Working Copy Button (Using Tag + Retry Loop)
    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy"
    $btnCopy.Tag  = $finalAnswerText
    $btnCopy.Size = New-Object System.Drawing.Size(42, 18)
    $btnCopy.Dock = [System.Windows.Forms.DockStyle]::Right
    $btnCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopy.FlatAppearance.BorderSize = 0
    $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $btnCopy.ForeColor = [System.Drawing.Color]::White
    $btnCopy.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    $btnCopy.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnCopy.TabStop = $false
    $btnCopy.Add_Click({
        param($s,$e)
        $txtToCopy = [string]$s.Tag
        if (-not $txtToCopy) { $txtToCopy = $script:latestCodeToCopy }
        if ($txtToCopy) {
            for ($attempt = 0; $attempt -lt 5; $attempt++) {
                try {
                    [System.Windows.Forms.Clipboard]::SetText($txtToCopy)
                    break
                } catch {
                    Start-Sleep -Milliseconds 40
                }
            }
            $s.Text = "OK"
            $s.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
            $rt = New-Object System.Windows.Forms.Timer; $rt.Interval = 900
            $rt.Add_Tick({ param($snd,$ev) $s.Text = "Copy"; $s.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $snd.Stop(); $snd.Dispose() })
            $rt.Start()
        }
    })

    $tb.Controls.Add($badge)
    $tb.Controls.Add($btnInv)
    $tb.Controls.Add($btnCopy)
    $tb.Controls.Add($btnClose)

    # Safe Drag Support
    foreach ($ctl in @($tb, $badge)) {
        $ctl.Add_MouseDown({
            param($s,$e)
            if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
                [StealthAPI]::ReleaseCapture() | Out-Null
                $targetH = if ($s -is [System.Windows.Forms.Form]) { $s.Handle } else { $s.FindForm().Handle }
                if ($targetH) {
                    [StealthAPI]::SendMessage($targetH, [StealthAPI]::WM_NCLBUTTONDOWN, ([IntPtr]([StealthAPI]::HTCAPTION)), [IntPtr]::Zero) | Out-Null
                }
            }
        })
    }

    # Quiz Answer Box (100% Transparent Background, Adaptive High-Contrast Font)
    $txtAns = New-Object System.Windows.Forms.TextBox
    $txtAns.Multiline   = $true
    $txtAns.ReadOnly    = $true
    $txtAns.ScrollBars  = if ($lines.Count -gt 18) { [System.Windows.Forms.ScrollBars]::Vertical } else { [System.Windows.Forms.ScrollBars]::None }
    $txtAns.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $txtAns.BackColor   = $script:keyColor
    $txtAns.Font        = New-Object System.Drawing.Font("Segoe UI", 10.0, [System.Drawing.FontStyle]::Bold)
    $txtAns.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtAns.WordWrap    = $true
    $txtAns.Text        = $finalAnswerText

    # Apply Camouflage Colors
    if ($script:config.CamouflageMode -eq "light") {
        $txtAns.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42) # Jet dark for white background
        $badge.ForeColor  = [System.Drawing.Color]::FromArgb(15, 23, 42)
    } else {
        $txtAns.ForeColor = [System.Drawing.Color]::FromArgb(248, 250, 252) # Pure white for dark background
        $badge.ForeColor  = [System.Drawing.Color]::FromArgb(52, 211, 153)
    }

    # Invert Contrast Toggle on Inv click
    $btnInv.Add_Click({
        if ($script:config.CamouflageMode -eq "light") {
            $script:config.CamouflageMode = "dark"
            $txtAns.ForeColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
            $badge.ForeColor  = [System.Drawing.Color]::FromArgb(52, 211, 153)
            $btnInv.Text = "Inv"
            $btnInv.BackColor = [System.Drawing.Color]::FromArgb(40, 45, 60)
            $btnInv.ForeColor = [System.Drawing.Color]::White
        } else {
            $script:config.CamouflageMode = "light"
            $txtAns.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
            $badge.ForeColor  = [System.Drawing.Color]::FromArgb(15, 23, 42)
            $btnInv.Text = "Lit"
            $btnInv.BackColor = [System.Drawing.Color]::FromArgb(200, 210, 225)
            $btnInv.ForeColor = [System.Drawing.Color]::Black
        }
        Save-Config
    })

    $pnlBody = New-Object System.Windows.Forms.Panel
    $pnlBody.Dock    = [System.Windows.Forms.DockStyle]::Fill
    $pnlBody.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 6)
    $pnlBody.BackColor = $script:keyColor
    $pnlBody.Controls.Add($txtAns)

    $escAction = {
        param($s, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            & $dismissAction
        }
    }
    $af.Add_KeyDown($escAction)
    $txtAns.Add_KeyDown($escAction)

    # Track and Remember Position & Size
    $af.Add_LocationChanged({
        param($s,$e)
        if ($s.Location.X -gt 0 -and $s.Location.Y -gt 0) {
            $script:winX = $s.Location.X
            $script:winY = $s.Location.Y
            $script:config.WindowPos.X = $s.Location.X
            $script:config.WindowPos.Y = $s.Location.Y
        }
    })
    $af.Add_SizeChanged({
        param($s,$e)
        if ($s.Width -gt 200 -and $s.Height -gt 100) {
            $script:winW = $s.Width
            $script:winH = $s.Height
            $script:config.WindowPos.W = $s.Width
            $script:config.WindowPos.H = $s.Height
        }
    })

    # Border resize support
    $resNW = New-Object ResizableBorderNW($af, 6)

    $af.Controls.Add($pnlBody)
    $af.Controls.Add($tb)
    $tb.SendToBack()

    $af.Show()
    $af.BringToFront()
    $script:aiLabel = $af

    $timeout = [Math]::Max(15, $script:config.AnswerTimeoutSec) * 1000
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = $timeout
    $t.Add_Tick({
        param($s,$e)
        $s.Stop(); $s.Dispose()
        if ($script:aiLabel) { try { $script:aiLabel.Close(); $script:aiLabel.Dispose() } catch {}; $script:aiLabel = $null }
    })
    $t.Start()
    $script:aiTimer = $t
    Write-Log "INFO" "Rendered clean Answer window."
}

# --- Multi-Tab Stealth Browser ---
$BW_W = 500; $BW_H = 520
$bForm = New-Object System.Windows.Forms.Form
$bForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$bForm.Size            = New-Object System.Drawing.Size($BW_W, $BW_H)
$bForm.MinimumSize     = New-Object System.Drawing.Size(280, 220)
$bForm.TopMost         = $true
$bForm.ShowInTaskbar   = $false
$bForm.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
$bForm.BackColor       = [System.Drawing.Color]::FromArgb(24, 24, 34)

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bForm.Location = New-Object System.Drawing.Point(
    [int](($screen.Width - $BW_W) / 2),
    [int]($screen.Height - $BW_H - 80)
)

$script:bVisible = $false
$script:isQuitting = $false
$bForm.Add_FormClosing({
    param($s,$e)
    if ($script:isQuitting) { return }
    $e.Cancel = $true
    $bForm.Hide()
    $script:bVisible = $false
})

function MakeTBtn($txt, $x, $w, $bg) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $txt; $b.Location = New-Object System.Drawing.Point($x, 4)
    $b.Size = New-Object System.Drawing.Size($w, 24); $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0; $b.BackColor = $bg; $b.ForeColor = [System.Drawing.Color]::White
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand; $b.TabStop = $false; return $b
}

$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Dock = [System.Windows.Forms.DockStyle]::Top; $titleBar.Height = 28
$titleBar.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 28)

$dragLbl = New-Object System.Windows.Forms.Label
$dragLbl.Text      = "  Stealth Browser"
$dragLbl.Dock      = [System.Windows.Forms.DockStyle]::Fill
$dragLbl.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 190)
$dragLbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$dragLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$minBtn = MakeTBtn "-" ($BW_W - 54) 26 ([System.Drawing.Color]::FromArgb(50, 50, 70))
$closeBtn = MakeTBtn "X" ($BW_W - 28) 26 ([System.Drawing.Color]::FromArgb(180, 40, 40))
$closeBtn.Add_Click({ $bForm.Hide(); $script:bVisible = $false })
$minBtn.Add_Click({ $bForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized })

$titleBar.Controls.Add($dragLbl); $titleBar.Controls.Add($minBtn); $titleBar.Controls.Add($closeBtn)

foreach ($ctl in @($titleBar, $dragLbl)) {
    $ctl.Add_MouseDown({
        param($s,$e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [StealthAPI]::ReleaseCapture() | Out-Null
            [StealthAPI]::SendMessage($bForm.Handle, [StealthAPI]::WM_NCLBUTTONDOWN, ([IntPtr]([StealthAPI]::HTCAPTION)), [IntPtr]::Zero) | Out-Null
        }
    })
}

$tb = New-Object System.Windows.Forms.Panel
$tb.Dock = [System.Windows.Forms.DockStyle]::Top; $tb.Height = 32
$tb.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 44)

$dk  = [System.Drawing.Color]::FromArgb(48, 48, 66)
$bl  = [System.Drawing.Color]::FromArgb(35, 90, 210)
$grn = [System.Drawing.Color]::FromArgb(24, 128, 56)
$pur = [System.Drawing.Color]::FromArgb(110, 50, 180)
$ylw = [System.Drawing.Color]::FromArgb(210, 140, 20)

$tBack = MakeTBtn "<"    3  22 $dk
$tFwd  = MakeTBtn ">"   27  22 $dk
$tRld  = MakeTBtn "R"   51  22 $dk

$tURL = New-Object System.Windows.Forms.TextBox
$tURL.Location    = New-Object System.Drawing.Point(76, 5)
$tURL.Size        = New-Object System.Drawing.Size(175, 22)
$tURL.BackColor   = [System.Drawing.Color]::FromArgb(44, 44, 60)
$tURL.ForeColor   = [System.Drawing.Color]::White
$tURL.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$tURL.Font        = New-Object System.Drawing.Font("Segoe UI", 8.5)
$tURL.Text        = "https://gemini.google.com"

$tGo      = MakeTBtn "Go"    254 26 $bl
$tSolveTab= MakeTBtn "⚡Tab" 282 46 $ylw
$tAddQ    = MakeTBtn "+Q"    330 28 $grn
$tAddLink = MakeTBtn "+Link" 360 42 $pur
$tZin     = MakeTBtn "+"     404 20 $dk
$zoomLbl  = New-Object System.Windows.Forms.Label
$zoomLbl.Text      = "100%"
$zoomLbl.Location  = New-Object System.Drawing.Point(426, 7)
$zoomLbl.Size      = New-Object System.Drawing.Size(26, 18)
$zoomLbl.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 210)
$zoomLbl.Font      = New-Object System.Drawing.Font("Segoe UI", 6.5, [System.Drawing.FontStyle]::Bold)
$zoomLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$tZout    = MakeTBtn "-"     454 20 $dk

$tbTip = New-Object System.Windows.Forms.ToolTip
$tbTip.SetToolTip($tSolveTab, "Direct Solve content in active tab (Zero OCR lag!)")
$tbTip.SetToolTip($tAddQ, "Paste captured question into Chat")
$tbTip.SetToolTip($tAddLink, "Paste current URL into Chat")

$tb.Controls.AddRange(@($tBack,$tFwd,$tRld,$tURL,$tGo,$tSolveTab,$tAddQ,$tAddLink,$tZin,$zoomLbl,$tZout))

$aiBar = New-Object System.Windows.Forms.Panel
$aiBar.Dock = [System.Windows.Forms.DockStyle]::Top; $aiBar.Height = 28
$aiBar.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 32)
$aiTip = New-Object System.Windows.Forms.ToolTip

$script:aiList = @(
    @{L="Gem";   C=[System.Drawing.Color]::FromArgb(66,103,212);  U="https://gemini.google.com";                                        T="Google Gemini"},
    @{L="Ael";   C=[System.Drawing.Color]::FromArgb(90,40,180);   U="https://aeliusai.com/";                                            T="Aelius AI (Images & PDFs)"},
    @{L="Ima";   C=[System.Drawing.Color]::FromArgb(210,70,50);   U="https://imastudio.com/chat-with-image";                           T="Ima Studio (Chat with Image)"},
    @{L="Pix";   C=[System.Drawing.Color]::FromArgb(40,160,180);  U="https://pixpal.chat/";                                             T="PixPal (Chat & Reasoning)"},
    @{L="Jolly"; C=[System.Drawing.Color]::FromArgb(220,130,20);  U="https://jollyai.online/models/ai-chatbot-unlimited-messages.php"; T="JollyAI (Unlimited Chat)"},
    @{L="Duck";  C=[System.Drawing.Color]::FromArgb(222,88,51);   U="https://duck.ai/";                                                T="Duck.ai"},
    @{L="Phind"; C=[System.Drawing.Color]::FromArgb(50,120,180);  U="https://www.phind.com/";                                          T="Phind Developer AI"}
)

$wvHost = New-Object System.Windows.Forms.Panel
$wvHost.Dock = [System.Windows.Forms.DockStyle]::Fill

$script:tabs = @{}
$script:activeTab = ""
$script:wvEnvProps = New-Object Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties
$script:wvEnvProps.UserDataFolder = "$env:TEMP\Universal_Stealth_WV2"

function Get-ActiveWv {
    if ($script:tabs -and $script:tabs.ContainsKey($script:activeTab)) {
        return $script:tabs[$script:activeTab].Wv
    }
    return $null
}

function Switch-BrowserTab($tabKey, $tabUrl) {
    if (-not $script:tabs.ContainsKey($tabKey)) {
        $newWv = New-Object Microsoft.Web.WebView2.WinForms.WebView2
        $newWv.Dock = [System.Windows.Forms.DockStyle]::Fill
        $newWv.CreationProperties = $script:wvEnvProps
        $newWv.Tag = @{ Key = $tabKey; Url = $tabUrl }
        $newWv.Add_CoreWebView2InitializationCompleted({
            param($s,$e)
            if ($e.IsSuccess) {
                $tag = $s.Tag
                $s.CoreWebView2.Settings.AreDefaultContextMenusEnabled = $true
                $s.CoreWebView2.Settings.IsStatusBarEnabled            = $false
                $s.CoreWebView2.Settings.IsZoomControlEnabled          = $true
                if ($tag -and $tag.Url) { $s.CoreWebView2.Navigate($tag.Url) }
            }
        })
        $newWv.Add_NavigationCompleted({
            param($s,$e)
            if ($s.Tag -and $script:activeTab -eq $s.Tag.Key -and $s.Source) {
                $tURL.Text = $s.Source.AbsoluteUri
            }
        })
        $wvHost.Controls.Add($newWv)
        $newWv.EnsureCoreWebView2Async($null) | Out-Null
        $script:tabs[$tabKey] = @{ Wv = $newWv; Url = $tabUrl; Key = $tabKey }
    }

    $script:activeTab = $tabKey

    foreach ($k in $script:tabs.Keys) {
        $entry = $script:tabs[$k]
        if ($k -eq $tabKey) {
            $entry.Wv.Visible = $true
            $entry.Wv.BringToFront()
            if ($entry.Wv.Source) { $tURL.Text = $entry.Wv.Source.AbsoluteUri }
            elseif ($entry.Url)   { $tURL.Text = $entry.Url }
        } else {
            $entry.Wv.Visible = $false
        }
    }

    foreach ($ctl in $aiBar.Controls) {
        if ($ctl.Tag -and $ctl.Tag.Key -eq $tabKey) {
            $ctl.FlatAppearance.BorderColor = [System.Drawing.Color]::White
            $ctl.FlatAppearance.BorderSize  = 2
        } else {
            $ctl.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(55, 55, 75)
            $ctl.FlatAppearance.BorderSize  = 0
        }
    }
}

$ax = 4
foreach ($ai in $script:aiList) {
    $ab = New-Object System.Windows.Forms.Button
    $ab.Text = $ai.L; $ab.Size = New-Object System.Drawing.Size(46, 22)
    $ab.Location = New-Object System.Drawing.Point($ax, 3)
    $ab.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $ab.FlatAppearance.BorderSize = 0; $ab.BackColor = $ai.C; $ab.ForeColor = [System.Drawing.Color]::White
    $ab.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    $ab.Cursor = [System.Windows.Forms.Cursors]::Hand; $ab.Tag = @{ Key = $ai.L; Url = $ai.U }; $ab.TabStop = $false
    $aiTip.SetToolTip($ab, $ai.T)
    $ab.Add_Click({ param($s,$e); if ($s.Tag) { Switch-BrowserTab $s.Tag.Key $s.Tag.Url } })
    $aiBar.Controls.Add($ab)
    $ax += 48
}

$tBack.Add_Click({ $w = Get-ActiveWv; if ($w -and $w.CoreWebView2) { $w.CoreWebView2.GoBack() } })
$tFwd.Add_Click({  $w = Get-ActiveWv; if ($w -and $w.CoreWebView2) { $w.CoreWebView2.GoForward() } })
$tRld.Add_Click({  $w = Get-ActiveWv; if ($w -and $w.CoreWebView2) { $w.CoreWebView2.Reload() } })
$tGo.Add_Click({
    $w = Get-ActiveWv
    $raw = $tURL.Text.Trim()
    if ($raw -match '^https?://') { $url = $raw }
    elseif ($raw -match '^(localhost|[a-zA-Z0-9][a-zA-Z0-9\-]*(\.[a-zA-Z]{2,})+)(:[0-9]+)?(/.*)?$') { $url = "https://$raw" }
    else { $url = "https://www.google.com/search?q=" + [Uri]::EscapeDataString($raw) }
    if ($w -and $w.CoreWebView2) { $w.CoreWebView2.Navigate($url) }
})

$tURL.Add_KeyDown({
    param($s,$e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::A) {
        $tURL.SelectAll(); $e.Handled = $true; $e.SuppressKeyPress = $true
    } elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Return) {
        $tGo.PerformClick(); $e.Handled = $true; $e.SuppressKeyPress = $true
    }
})

$tZin.Add_Click({  $w = Get-ActiveWv; if ($w -and $w.CoreWebView2) { $w.ZoomFactor = [Math]::Min(3.0, $w.ZoomFactor + 0.25); $zoomLbl.Text = [int]($w.ZoomFactor * 100) + "%" } })
$tZout.Add_Click({ $w = Get-ActiveWv; if ($w -and $w.CoreWebView2) { $w.ZoomFactor = [Math]::Max(0.25, $w.ZoomFactor - 0.25); $zoomLbl.Text = [int]($w.ZoomFactor * 100) + "%" } })

# --- Extract Content from Current Active Browser Tab (Zero OCR Lag with Non-Blocking Pump) ---
function Get-ActiveTabContent {
    $w = Get-ActiveWv
    if (-not $w -or -not $w.CoreWebView2) {
        return $null
    }
    try {
        $js = @"
(function() {
    let sel = window.getSelection().toString().trim();
    if (sel && sel.length > 5) return sel;
    let el = document.querySelector('[data-track-load="description_content"], .problem-statement, .question-view, pre, main, article, #content');
    if (el && el.innerText.trim().length > 10) return el.innerText.trim();
    return document.body.innerText.trim();
})()
"@
        $task = $w.CoreWebView2.ExecuteScriptAsync($js)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $task.IsCompleted -and $sw.ElapsedMilliseconds -lt 1500) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 15
        }
        if ($task.IsCompleted) {
            $json = $task.Result
            if ($json) {
                $extracted = ($json | ConvertFrom-Json)
                if ($extracted -and $extracted.Trim().Length -gt 5) {
                    Write-Log "TAB" "Extracted $($extracted.Length) chars from active tab."
                    return $extracted
                }
            }
        }
    } catch {
        Write-Log "ERR" "Error extracting tab content: $($_.Exception.Message)"
    }
    return $null
}

function Start-CombinedSolveFlow {
    param([string]$SpecificLang = "auto")
    $tabText = Get-ActiveTabContent
    if ($tabText -and $tabText.Trim().Length -gt 10) {
        $script:latestOCRText = $tabText
        try { [System.Windows.Forms.Clipboard]::SetText($tabText) } catch {}
        Write-Log "TAB" "Direct solving extracted browser tab as MCQ..."
        Execute-AIAsyncSolve -TextToSolve $tabText -SpecificLang $SpecificLang
    } else {
        Start-AISolveFlow -SpecificLang $SpecificLang
    }
}

function Start-TabSolveFlow {
    param([string]$SpecificLang = "auto")
    Start-CombinedSolveFlow -SpecificLang $SpecificLang
}

$tSolveTab.Add_Click({ Start-TabSolveFlow -SpecificLang $script:currentMode })

$tAddQ.Add_Click({
    $w = Get-ActiveWv
    if ($w -and $w.CoreWebView2 -and $script:latestOCRText) {
        [System.Windows.Forms.Clipboard]::SetText($script:latestOCRText)
        $qEsc = $script:latestOCRText.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n')
        $js = @"
(function() {
    let t = "$qEsc";
    let el = document.activeElement;
    if (!el || el === document.body || el.tagName === 'IFRAME') {
        el = document.querySelector('textarea, div[contenteditable="true"], input[type="text"], [role="textbox"]');
    }
    if (el) {
        el.focus();
        if (el.isContentEditable) {
            el.innerText = (el.innerText ? el.innerText + ' ' : '') + t;
        } else {
            el.value = (el.value ? el.value + ' ' : '') + t;
        }
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
    }
})();
"@
        $w.CoreWebView2.ExecuteScriptAsync($js) | Out-Null
        (New-Object System.Windows.Forms.ToolTip).Show("Question pasted!", $tAddQ, 0, -26, 1400)
        Write-Log "INFO" "Question injected into chat."
    }
})

$tAddLink.Add_Click({
    $w = Get-ActiveWv
    if ($w -and $w.CoreWebView2) {
        $u = $w.CoreWebView2.Source
        if ($u) {
            [System.Windows.Forms.Clipboard]::SetText($u)
            $uEsc = $u.Replace('\', '\\').Replace('"', '\"')
            $js = @"
(function() {
    let t = "$uEsc";
    let el = document.activeElement;
    if (!el || el === document.body || el.tagName === 'IFRAME') {
        el = document.querySelector('textarea, div[contenteditable="true"], input[type="text"], [role="textbox"]');
    }
    if (el) {
        el.focus();
        if (el.isContentEditable) {
            el.innerText = (el.innerText ? el.innerText + ' ' : '') + t;
        } else {
            el.value = (el.value ? el.value + ' ' : '') + t;
        }
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
    }
})();
"@
            $w.CoreWebView2.ExecuteScriptAsync($js) | Out-Null
            (New-Object System.Windows.Forms.ToolTip).Show("URL pasted!", $tAddLink, 0, -26, 1400)
        }
    }
})

$bResNW = New-Object ResizableBorderNW($bForm, 6)
$bForm.Controls.Add($wvHost)
$bForm.Controls.Add($aiBar)
$bForm.Controls.Add($tb)
$bForm.Controls.Add($titleBar)

$bForm.Add_Shown({
    [StealthAPI]::ApplyStealthAffinity($bForm.Handle, $script:config.StealthAffinity) | Out-Null
    $ex = [StealthAPI]::GetWindowLong($bForm.Handle, [StealthAPI]::GWL_EXSTYLE)
    [StealthAPI]::SetWindowLong($bForm.Handle, [StealthAPI]::GWL_EXSTYLE, $ex -bor [StealthAPI]::WS_EX_TOOLWINDOW) | Out-Null
    [StealthAPI]::SetWindowPos($bForm.Handle, [StealthAPI]::HWND_TOPMOST, 0, 0, 0, 0, ([StealthAPI]::SWP_NOMOVE -bor [StealthAPI]::SWP_NOSIZE -bor [StealthAPI]::SWP_FRAMECHANGED)) | Out-Null
    if ($script:tabs.Count -eq 0) {
        Switch-BrowserTab "Gem" "https://gemini.google.com"
    }
})

function Toggle-StealthBrowser {
    if ($script:bVisible) {
        $bForm.Hide(); $script:bVisible = $false
        Write-Log "INFO" "Stealth Browser hidden."
    } else {
        $bForm.Show()
        [StealthAPI]::ApplyStealthAffinity($bForm.Handle, $script:config.StealthAffinity) | Out-Null
        [StealthAPI]::SetWindowPos($bForm.Handle, [StealthAPI]::HWND_TOPMOST, 0, 0, 0, 0, ([StealthAPI]::SWP_NOMOVE -bor [StealthAPI]::SWP_NOSIZE -bor [StealthAPI]::SWP_FRAMECHANGED)) | Out-Null
        $script:bVisible = $true
        Write-Log "INFO" "Stealth Browser displayed."
    }
}

# --- Dynamic Micro-Dot Overlay Bar ---
$DOT_SIZE = 19; $GAP = 4
$bar = New-Object System.Windows.Forms.Form
$bar.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$bar.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
$bar.TopMost         = $true
$bar.ShowInTaskbar   = $false
$bar.BackColor       = [System.Drawing.Color]::Magenta
$bar.TransparencyKey = [System.Drawing.Color]::Magenta

function MakeDotBtn($c, $label, $tipText, $fgColor = [System.Drawing.Color]::White) {
    $b = New-Object System.Windows.Forms.Button
    $b.Size     = New-Object System.Drawing.Size($DOT_SIZE, $DOT_SIZE)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::Magenta
    $b.FlatAppearance.MouseDownBackColor = $c
    $b.FlatAppearance.MouseOverBackColor = $c
    $b.BackColor = $c
    $b.ForeColor = $fgColor
    $b.Text      = $label
    $fSize = 7.5
    if ($label.Length -gt 1) { $fSize = 6.4 }
    $b.Font      = New-Object System.Drawing.Font("Segoe UI", $fSize, [System.Drawing.FontStyle]::Bold)
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $b.Padding   = [System.Windows.Forms.Padding]::Empty
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.TabStop   = $false

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(0, 0, $DOT_SIZE, $DOT_SIZE)
    $b.Region = New-Object System.Drawing.Region($path)

    $tip = New-Object System.Windows.Forms.ToolTip
    $tip.SetToolTip($b, $tipText)
    return $b
}

# Individual Separate Buttons with Instant Recognizable Identifiers
$btnCap    = MakeDotBtn ([System.Drawing.Color]::FromArgb(40, 110, 230)) "P"  "Screenshot to Clipboard (Ctrl+Shift+P)"
$btnBrw    = MakeDotBtn ([System.Drawing.Color]::FromArgb(35, 175, 80))  "B"  "Stealth Browser (Ctrl+Shift+B)"
$btnOCR    = MakeDotBtn ([System.Drawing.Color]::FromArgb(235, 115, 20)) "A"  "Auto-Solve MCQ (Screen & Tab) (Ctrl+Shift+T / Ctrl+Shift+S)"
$btnJava   = MakeDotBtn ([System.Drawing.Color]::FromArgb(210, 45, 45))  "J"  "Direct Solve in Java (Ctrl+Shift+J)"
$btnCpp    = MakeDotBtn ([System.Drawing.Color]::FromArgb(25, 175, 205)) "C"  "Direct Solve in C++ (Ctrl+Shift+C)"
$btnPy     = MakeDotBtn ([System.Drawing.Color]::FromArgb(240, 195, 30)) "Py" "Direct Solve in Python (Ctrl+Shift+Y)" ([System.Drawing.Color]::FromArgb(25, 25, 25))
$btnConfig = MakeDotBtn ([System.Drawing.Color]::FromArgb(120, 125, 145))"S"  "Settings & API Keys"

function Update-DotBarLayout {
    $bar.Controls.Clear()
    $activeButtons = @()

    if ($script:config.Buttons.Screenshot) { $activeButtons += $btnCap }
    if ($script:config.Buttons.Browser)    { $activeButtons += $btnBrw }
    if ($script:config.Buttons.AutoSolve -or $script:config.Buttons.TabSolve) { $activeButtons += $btnOCR }
    if ($script:config.Buttons.Java)       { $activeButtons += $btnJava }
    if ($script:config.Buttons.Cpp)        { $activeButtons += $btnCpp }
    if ($script:config.Buttons.Python)     { $activeButtons += $btnPy }
    if ($script:config.Buttons.Settings)   { $activeButtons += $btnConfig }

    if ($activeButtons.Count -eq 0) {
        $activeButtons += $btnConfig
    }

    $curX = 0
    foreach ($btn in $activeButtons) {
        $btn.Location = New-Object System.Drawing.Point($curX, 0)
        $bar.Controls.Add($btn)
        $curX += ($DOT_SIZE + $GAP)
    }

    $totalW = $curX - $GAP
    $bar.Size = New-Object System.Drawing.Size($totalW, $DOT_SIZE)
    $bar.Location = New-Object System.Drawing.Point(($screen.Width - $totalW - 12), ($screen.Height - $DOT_SIZE - 42))
}

# --- Infinite-Loop-Proof Screenshot Engine (Opacity-based, Zero Timers, Zero Shown Events) ---
$script:capBusy = $false
function Take-StealthScreenshot {
    if ($script:capBusy) { return }
    $script:capBusy = $true
    Write-Log "INFO" "Capturing stealth screenshot..."

    try {
        # Instantly make overlays 100% transparent without hiding form (prevents Shown re-triggering)
        $bar.Opacity = 0
        if ($bForm -and $script:bVisible) { $bForm.Opacity = 0 }
        if ($script:aiLabel)  { $script:aiLabel.Opacity = 0 }
        if ($script:codeForm) { $script:codeForm.Opacity = 0 }

        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 45

        $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
        $gfx.Dispose()

        # Retry clipboard set up to 3 times in case Windows clipboard is locked
        for ($retry = 0; $retry -lt 3; $retry++) {
            try {
                [System.Windows.Forms.Clipboard]::SetImage($bmp)
                break
            } catch {
                Start-Sleep -Milliseconds 30
            }
        }
        $bmp.Dispose()
        Write-Log "INFO" "Full-screen snapshot copied to clipboard."
    } catch {
        Write-Log "ERR" "Screenshot capture error: $($_.Exception.Message)"
    } finally {
        $bar.Opacity = 1
        if ($bForm -and $script:bVisible) { $bForm.Opacity = 1 }
        if ($script:aiLabel)  { $script:aiLabel.Opacity = 1 }
        if ($script:codeForm) { $script:codeForm.Opacity = 1 }
        $script:capBusy = $false
    }
}

$btnCap.Add_Click({ Take-StealthScreenshot })
$btnBrw.Add_Click({ Toggle-StealthBrowser })
$btnJava.Add_Click({ Start-AISolveFlow -SpecificLang "java" })
$btnCpp.Add_Click({ Start-AISolveFlow -SpecificLang "cpp" })
$btnPy.Add_Click({ Start-AISolveFlow -SpecificLang "python" })
$btnConfig.Add_Click({ Show-SettingsPanel })

# --- Execution of AI Async Pipeline with Proper Scoping & Logging ---
function Execute-AIAsyncSolve {
    param(
        [string]$TextToSolve,
        [string]$SpecificLang = "auto"
    )
    if (-not $TextToSolve) { return }

    $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(255, 215, 0)
    $target = if ($SpecificLang -ne "auto") { $SpecificLang } else { $script:currentMode }

    Write-Log "AI" "Sending to AI Engine (Mode: $target, Keys: $($script:config.Keys.Count))..."

    # Clean up previous runspace if still active
    if ($script:aiPs) { try { $script:aiPs.Dispose() } catch {} }
    if ($script:aiRs) { try { $script:aiRs.Close(); $script:aiRs.Dispose() } catch {} }
    if ($script:aiPollTimer) { try { $script:aiPollTimer.Stop(); $script:aiPollTimer.Dispose() } catch {} }

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs

    $ps.AddScript({
        param($q, $lang, $keysList, $kIdx)
        if (-not $keysList -or $keysList.Count -eq 0) {
            return @{ Success = $false; Error = "No API keys configured" }
        }

        $isCoding = $false
        if ($lang -in @("java", "cpp", "python")) {
            $isCoding = $true
        } elseif ($lang -eq "quiz") {
            $isCoding = $false
        } else {
            # Check for MCQ / Question patterns FIRST (e.g. A), B), Option A, Question 1)
            if ($q -match '(?i)(?:^|[\r\n])\s*[\(\[]?[A-D][\)\.\:\-\]]\s+' -or $q -match '(?i)\b(option\s+[A-D]|which of the following|what will be the output|correct option|choose the correct|select the correct|worst-case time complexity|what is the time complexity|question\s+[0-9]+)\b') {
                $isCoding = $false
            } elseif ($q -match '(?i)(class Solution|def\s+[a-zA-Z0-9_]+\s*\(|public static void|public\s+[a-zA-Z0-9_<>]+\s+[a-zA-Z0-9_]+\s*\(|vector<int>|int main\s*\(|Complete the [a-zA-Z0-9_]+ function|leetcode|hackerrank)') {
                $isCoding = $true
            } else {
                $isCoding = $false
            }
        }

        if ($lang -in @("java", "cpp", "python")) {
            $sysPrompt = "You are an expert competitive programmer.`nTarget: $lang.`n`nRULES:`n1. Output ONLY compilable optimal class Solution inside a markdown code block (```$lang).`n2. At top of code put: // Time: O(...) | Space: O(...)`n3. Zero conversational text, zero explanation outside code block. Just clean optimal solution."
        } else {
            $sysPrompt = "You are an intelligent dual-mode exam solver.`nFirst analyze the input to detect whether it is a CODING PROBLEM (LeetCode, algorithm, function to implement) or MCQ / APTITUDE QUESTIONS.`n`nIF CODING PROBLEM:`nOutput ONLY optimal compilable class Solution inside a markdown code block (```<language>).`nAt top of code: // Time: O(...) | Space: O(...)`nNo conversational text outside code.`n`nIF MCQ / APTITUDE:`nDetect ALL MCQs present in the text and output each question answered clearly with its number:`nQ1: Option [X] - [Option Text]`n- [Direct 1-2 sentence core reason / formula]`n`nQ2: Option [Y] - [Option Text]`n- [Direct 1-2 sentence core reason / formula]`n(Use original question numbers if present, e.g. Q14, Q15). Direct, concise, maximum 3 lines per question. Zero greetings."
        }

        $tried = 0
        $lastErr = ""
        while ($tried -lt $keysList.Count) {
            $entry = $keysList[($kIdx + $tried) % $keysList.Count]
            $tried++
            try {
                $model = if ($entry.Provider -eq 'groq') { 'qwen/qwen3.8-27b' } else { 'openrouter/free' }
                $body = @{
                    model       = $model
                    messages    = @(
                        @{ role = 'system'; content = $sysPrompt }
                        @{ role = 'user';   content = $q }
                    )
                    max_tokens  = if ($isCoding) { 2048 } else { 1024 }
                    temperature = 0.05
                } | ConvertTo-Json -Depth 5

                $url = if ($entry.Provider -eq 'groq') {
                    'https://api.groq.com/openai/v1/chat/completions'
                } else {
                    'https://openrouter.ai/api/v1/chat/completions'
                }

                $hdr = @{ 'Authorization' = "Bearer $($entry.Key)"; 'Content-Type' = 'application/json' }
                if ($entry.Provider -eq 'openrouter') {
                    $hdr['HTTP-Referer'] = 'https://github.com/stealth-assistant'
                    $hdr['X-Title']      = 'Stealth Assistant'
                }

                $res = Invoke-RestMethod -Uri $url -Method POST -Headers $hdr -Body $body -TimeoutSec 15 -ErrorAction Stop
                $rawAns = $res.choices[0].message.content.Trim()
                
                $isCodeRes = ($rawAns -match '(?s)```(?:[a-zA-Z0-9_#\+\-]+)?\s*[\r\n]+.*?```' -or $rawAns -match '(?m)^\s*(?:class\s+Solution|public\s+class|def\s+[a-zA-Z0-9_]+\s*\()' -or $lang -in @("java", "cpp", "python"))
                
                $detectedLang = "Ans"
                if ($isCodeRes) {
                    if ($lang -in @("java", "cpp", "python")) {
                        $detectedLang = $lang.ToUpper()
                    } elseif ($rawAns -match '(?i)```\s*(java|cpp|c\+\+|python|py)') {
                        $m = $matches[1].ToUpper()
                        $detectedLang = if ($m -eq "PY") { "PYTHON" } elseif ($m -eq "C++") { "CPP" } else { $m }
                    } elseif ($rawAns -match '(?i)\b(public static void|System\.out\.println)\b') {
                        $detectedLang = "JAVA"
                    } elseif ($rawAns -match '(?i)\b(vector<|std::|#include)\b') {
                        $detectedLang = "CPP"
                    } else {
                        $detectedLang = "CODE"
                    }
                }
                
                return @{
                    Success  = $true
                    IsCoding = $isCodeRes
                    Lang     = $detectedLang
                    Answer   = $rawAns
                    Provider = $entry.Provider.ToUpper()
                }
            } catch {
                $lastErr = $_.Exception.Message
                continue
            }
        }
        return @{ Success = $false; Error = "All keys failed. Last error: $lastErr" }
    }) | Out-Null

    $ps.AddArgument($TextToSolve) | Out-Null
    $ps.AddArgument($target) | Out-Null
    $ps.AddArgument($script:config.Keys) | Out-Null
    $ps.AddArgument($script:aiKeyIndex) | Out-Null

    $script:aiRs = $rs
    $script:aiPs = $ps
    $script:aiHandle = $ps.BeginInvoke()

    $pollTimer = New-Object System.Windows.Forms.Timer
    $pollTimer.Interval = 75
    $pollTimer.Add_Tick({
        param($snd,$ev)
        if ($script:aiHandle -and $script:aiHandle.IsCompleted) {
            $snd.Stop(); $snd.Dispose()
            $script:aiPollTimer = $null
            $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20)
            $script:ocrBusy = $false

            try {
                $out = $script:aiPs.EndInvoke($script:aiHandle)
                if ($out -and $out[0].Success) {
                    $resData = $out[0]
                    Write-Log "AI" "SUCCESS from $($resData.Provider): $($resData.Answer.Substring(0, [Math]::Min(60, $resData.Answer.Length)))..."
                    if ($resData.IsCoding) {
                        Show-CodeSolution -CodeText $resData.Answer -Lang $resData.Lang
                    } else {
                        Show-QuizAnswer -Answer $resData.Answer
                    }
                } else {
                    $errMsg = if ($out) { $out[0].Error } else { "Null response" }
                    Write-Log "ERR" "Solve failed: $errMsg"
                    $btnOCR.BackColor = [System.Drawing.Color]::Red
                    $rt = New-Object System.Windows.Forms.Timer; $rt.Interval = 2000
                    $rt.Add_Tick({ param($s,$e) $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20); $rt.Stop(); $rt.Dispose() })
                    $rt.Start()
                }
            } catch {
                Write-Log "ERR" "Exception processing AI response: $($_.Exception.Message)"
                $btnOCR.BackColor = [System.Drawing.Color]::Red
                $rt = New-Object System.Windows.Forms.Timer; $rt.Interval = 2000
                $rt.Add_Tick({ param($s,$e) $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20); $rt.Stop(); $rt.Dispose() })
                $rt.Start()
            }

            try { $script:aiPs.Dispose(); $script:aiRs.Close(); $script:aiRs.Dispose() } catch {}
            $script:aiPs = $null; $script:aiRs = $null; $script:aiHandle = $null
        }
    })

    $script:aiPollTimer = $pollTimer
    $pollTimer.Start()
}

# --- Screen OCR Solve Flow ---
function Start-AISolveFlow {
    param([string]$SpecificLang = "auto")
    if ($script:ocrBusy) { return }
    $script:ocrBusy = $true
    $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(255, 215, 0)
    Write-Log "OCR" "Capturing screen for OCR..."

    try {
        # Quick snap via opacity to prevent Shown loop
        $bar.Opacity = 0
        if ($bForm -and $script:bVisible) { $bForm.Opacity = 0 }
        if ($script:aiLabel)  { $script:aiLabel.Opacity = 0 }
        if ($script:codeForm) { $script:codeForm.Opacity = 0 }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 40

        $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
        $gfx.Dispose()
        $bmp.Save($script:ocrImgTmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()

        $bar.Opacity = 1
        if ($bForm -and $script:bVisible) { $bForm.Opacity = 1 }
        if ($script:aiLabel)  { $script:aiLabel.Opacity = 1 }
        if ($script:codeForm) { $script:codeForm.Opacity = 1 }

        # Native Direct WinRT OCR Execution (Takes ~140ms, Zero Polling Timers, Zero Deadlocks)
        $e = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
        if (-not $e) { $e = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new("en-US")) }
        
        $f  = Wait-WinRtTask ([Windows.Storage.StorageFile]::GetFileFromPathAsync($script:ocrImgTmp)) ([Windows.Storage.StorageFile])
        if (-not $f) {
            Write-Log "ERR" "Failed to access temporary screenshot file for OCR."
            $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20)
            return
        }
        $s  = Wait-WinRtTask ($f.OpenAsync([Windows.Storage.FileAccessMode]::Read))                     ([Windows.Storage.Streams.IRandomAccessStream])
        if (-not $s) {
            Write-Log "ERR" "Failed to open screenshot stream for OCR."
            $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20)
            return
        }
        $d  = Wait-WinRtTask ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($s))               ([Windows.Graphics.Imaging.BitmapDecoder])
        $sb = if ($d) { Wait-WinRtTask ($d.GetSoftwareBitmapAsync())                                   ([Windows.Graphics.Imaging.SoftwareBitmap]) } else { $null }
        $r  = if ($sb) { Wait-WinRtTask ($e.RecognizeAsync($sb))                                       ([Windows.Media.Ocr.OcrResult]) } else { $null }
        if ($s) { try { $s.Dispose() } catch {} }
        Remove-Item $script:ocrImgTmp -Force -EA SilentlyContinue

        if (-not $r) {
            Write-Log "ERR" "OCR recognition failed or returned null result."
            $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20)
            return
        }

        $lines = @()
        foreach ($ol in $r.Lines) { $lines += $ol.Text }
        $ocrText = $r.Text
        if ($lines.Count -gt 0) { $ocrText = $lines -join "`r`n" }
        $ocrText = $ocrText.Trim()

        if ($ocrText -ne "") {
            $script:latestOCRText = $ocrText
            try { [System.Windows.Forms.Clipboard]::SetText($ocrText) } catch {}
            Write-Log "OCR" "Recognized $($ocrText.Length) chars from screen."
            Execute-AIAsyncSolve -TextToSolve $ocrText -SpecificLang $SpecificLang
        } else {
            Write-Log "ERR" "No readable text detected on screen."
            $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20)
        }
    } catch {
        Write-Log "ERR" "Exception during OCR: $($_.Exception.Message)"
        $btnOCR.BackColor = [System.Drawing.Color]::FromArgb(235, 115, 20)
    } finally {
        $bar.Opacity = 1
        if ($bForm -and $script:bVisible) { $bForm.Opacity = 1 }
        if ($script:aiLabel)  { $script:aiLabel.Opacity = 0.94 }
        if ($script:codeForm) { $script:codeForm.Opacity = 0.94 }
        $script:ocrBusy = $false
    }
}

$btnOCR.Add_Click({ Start-CombinedSolveFlow -SpecificLang "auto" })

# --- Dragging the Micro Bar ---
$script:barDrag = $false
$script:barPt   = [System.Drawing.Point]::Empty

foreach ($b in @($btnCap, $btnBrw, $btnOCR, $btnJava, $btnCpp, $btnPy, $btnConfig)) {
    $b.Add_MouseDown({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:barDrag = $true
            $script:barPt   = [System.Windows.Forms.Cursor]::Position
        }
    })
    $b.Add_MouseMove({
        param($s, $e)
        if ($script:barDrag) {
            $n = [System.Windows.Forms.Cursor]::Position
            $dx = $n.X - $script:barPt.X
            $dy = $n.Y - $script:barPt.Y
            if ([Math]::Abs($dx) + [Math]::Abs($dy) -gt 2) {
                $bar.Left += $dx
                $bar.Top  += $dy
                $script:barPt = $n
            }
        }
    })
    $b.Add_MouseUp({ param($s, $e) $script:barDrag = $false })
}

# --- Dynamic Customizable Hotkey System (Supports Simple Keys, Combos, Never Mouse Clicks) ---
function Parse-ShortcutString([string]$str) {
    if (-not $str -or $str.Trim() -eq "") { return $null }
    $parts = $str.Trim() -split "\+"
    $mod = 0
    $keyStr = ""
    foreach ($p in $parts) {
        $t = $p.Trim().ToLower()
        if ($t -eq "ctrl" -or $t -eq "control") { $mod = $mod -bor 2 }
        elseif ($t -eq "shift") { $mod = $mod -bor 4 }
        elseif ($t -eq "alt")   { $mod = $mod -bor 1 }
        elseif ($t -eq "win")   { $mod = $mod -bor 8 }
        else { $keyStr = $p.Trim() }
    }
    $vk = 0
    try {
        $vk = [int][System.Enum]::Parse([System.Windows.Forms.Keys], $keyStr, $true)
    } catch {
        if ($keyStr.Length -eq 1) {
            $vk = [int][char]($keyStr.ToUpper())
        }
    }
    if ($vk -le 0) { return $null }
    return @{ Mod = $mod; Vk = $vk; Str = $str }
}

function Register-AllHotkeys {
    for ($i = 1; $i -le 8; $i++) {
        try { [StealthAPI]::UnregisterHotKey($bar.Handle, $i) | Out-Null } catch {}
    }

    $map = @(
        @{ Id = 1; Name = "Browser";    Default = "Ctrl+Shift+B" },
        @{ Id = 2; Name = "Screenshot"; Default = "Ctrl+Shift+P" },
        @{ Id = 3; Name = "AutoSolve";  Default = "Ctrl+Shift+T" },
        @{ Id = 4; Name = "Panic";      Default = "Ctrl+Shift+Q" },
        @{ Id = 5; Name = "Java";       Default = "Ctrl+Shift+J" },
        @{ Id = 6; Name = "Cpp";        Default = "Ctrl+Shift+C" },
        @{ Id = 7; Name = "Python";     Default = "Ctrl+Shift+Y" },
        @{ Id = 8; Name = "TabSolve";   Default = "Ctrl+Shift+S" }
    )

    $regCount = 0
    foreach ($item in $map) {
        $str = $item.Default
        if ($script:config.Hotkeys -and $script:config.Hotkeys.PSObject.Properties[$item.Name]) {
            $val = [string]$script:config.Hotkeys.$($item.Name)
            if ($val -and $val.Trim() -ne "") { $str = $val.Trim() }
        }
        $parsed = Parse-ShortcutString $str
        if ($parsed) {
            $ok = [StealthAPI]::RegisterHotKey($bar.Handle, $item.Id, [uint32]$parsed.Mod, [uint32]$parsed.Vk)
            if ($ok) { $regCount++ } else {
                Write-Log "WARN" "Hotkey conflict for $($item.Name): $str"
            }
        }
    }
    Write-Log "INFO" "Registered $regCount hotkeys."
}

# --- Settings & Configuration Panel ---
function Show-SettingsPanel {
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text            = "Settings and Configuration"
    $sf.Size            = New-Object System.Drawing.Size(620, 560)
    $sf.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $sf.BackColor       = [System.Drawing.Color]::FromArgb(20, 22, 30)
    $sf.ForeColor       = [System.Drawing.Color]::White
    $sf.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $sf.MaximizeBox     = $false
    $sf.MinimizeBox     = $false
    $sf.TopMost         = $true

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tabs.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
    $tabs.ItemSize = New-Object System.Drawing.Size(135, 30)
    $tabs.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
    $tabs.Add_DrawItem({
        param($s, $e)
        $g = $e.Graphics
        $tab = $s.TabPages[$e.Index]
        $rect = $s.GetTabRect($e.Index)
        $isSelected = ($s.SelectedIndex -eq $e.Index)
        $bgCol = if ($isSelected) { [System.Drawing.Color]::FromArgb(37, 99, 235) } else { [System.Drawing.Color]::FromArgb(26, 29, 40) }
        $brushBg = New-Object System.Drawing.SolidBrush($bgCol)
        $g.FillRectangle($brushBg, $rect)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $sfStr = New-Object System.Drawing.StringFormat
        $sfStr.Alignment = [System.Drawing.StringAlignment]::Center
        $sfStr.LineAlignment = [System.Drawing.StringAlignment]::Center
        $font = New-Object System.Drawing.Font("Segoe UI", 9.0, (if ($isSelected) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }))
        $g.DrawString($tab.Text, $font, $textBrush, [System.Drawing.RectangleF]$rect, $sfStr)
        $brushBg.Dispose(); $textBrush.Dispose(); $sfStr.Dispose(); $font.Dispose()
    })

    # ==================== Tab 1: Shortcuts Configuration ====================
    $tabShortcuts = New-Object System.Windows.Forms.TabPage("Shortcuts")
    $tabShortcuts.BackColor = [System.Drawing.Color]::FromArgb(20, 22, 30)

    $pnlSc = New-Object System.Windows.Forms.Panel
    $pnlSc.Dock = [System.Windows.Forms.DockStyle]::Fill
    $pnlSc.AutoScroll = $true
    $pnlSc.BackColor = [System.Drawing.Color]::FromArgb(20, 22, 30)
    $pnlSc.Padding = New-Object System.Windows.Forms.Padding(15)

    $lblScTip = New-Object System.Windows.Forms.Label
    $lblScTip.Text = "Click any box and press your key (e.g. F2, F9, or Ctrl+Shift+T). Mouse clicks are strictly ignored."
    $lblScTip.Location = New-Object System.Drawing.Point(15, 12)
    $lblScTip.Size = New-Object System.Drawing.Size(560, 22)
    $lblScTip.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
    $lblScTip.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $pnlSc.Controls.Add($lblScTip)

    $scActions = @(
        @{ Key = "AutoSolve";  Label = "Auto-Solve (MCQ / Code):"; Default = "Ctrl+Shift+T" },
        @{ Key = "TabSolve";   Label = "Active Browser Tab Solve:"; Default = "Ctrl+Shift+S" },
        @{ Key = "Java";       Label = "Solve in Java:";            Default = "Ctrl+Shift+J" },
        @{ Key = "Cpp";        Label = "Solve in C++:";             Default = "Ctrl+Shift+C" },
        @{ Key = "Python";     Label = "Solve in Python:";          Default = "Ctrl+Shift+Y" },
        @{ Key = "Browser";    Label = "Toggle Stealth Browser:";   Default = "Ctrl+Shift+B" },
        @{ Key = "Screenshot"; Label = "Stealth Screenshot:";      Default = "Ctrl+Shift+P" },
        @{ Key = "Panic";      Label = "Panic Kill / Exit:";        Default = "Ctrl+Shift+Q" }
    )

    $txtBoxes = @{}
    $curY = 40
    foreach ($sc in $scActions) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $sc.Label
        $lbl.Location = New-Object System.Drawing.Point(15, ($curY + 2))
        $lbl.Size = New-Object System.Drawing.Size(200, 22)
        $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold)
        $lbl.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)

        $txt = New-Object System.Windows.Forms.TextBox
        $curVal = $sc.Default
        if ($script:config.Hotkeys -and $script:config.Hotkeys.PSObject.Properties[$sc.Key]) {
            $curVal = [string]$script:config.Hotkeys.$($sc.Key)
        }
        $txt.Text = $curVal
        $txt.Tag  = $curVal
        $txt.Location = New-Object System.Drawing.Point(220, $curY)
        $txt.Size = New-Object System.Drawing.Size(160, 22)
        $txt.BackColor = [System.Drawing.Color]::FromArgb(30, 34, 48)
        $txt.ForeColor = [System.Drawing.Color]::FromArgb(56, 189, 248)
        $txt.Font = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Bold)
        $txt.ReadOnly = $true
        $txt.Cursor = [System.Windows.Forms.Cursors]::Hand

        # Ignore mouse clicks as shortcuts! Only capture physical keyboard keys.
        $txt.Add_KeyDown({
            param($s, $e)
            $e.SuppressKeyPress = $true
            # Ignore mouse virtual buttons if fired
            if ($e.KeyCode -in @([System.Windows.Forms.Keys]::LButton, [System.Windows.Forms.Keys]::RButton, [System.Windows.Forms.Keys]::MButton, [System.Windows.Forms.Keys]::XButton1, [System.Windows.Forms.Keys]::XButton2)) {
                return
            }
            # Ignore modifier keys pressed alone
            if ($e.KeyCode -in @([System.Windows.Forms.Keys]::ControlKey, [System.Windows.Forms.Keys]::ShiftKey, [System.Windows.Forms.Keys]::Menu, [System.Windows.Forms.Keys]::LWin, [System.Windows.Forms.Keys]::RWin)) {
                return
            }

            $parts = @()
            if ($e.Modifiers -band [System.Windows.Forms.Keys]::Control) { $parts += "Ctrl" }
            if ($e.Modifiers -band [System.Windows.Forms.Keys]::Alt)     { $parts += "Alt" }
            if ($e.Modifiers -band [System.Windows.Forms.Keys]::Shift)   { $parts += "Shift" }

            $keyName = $e.KeyCode.ToString()
            if ($keyName -match '^D[0-9]$') { $keyName = $keyName.Substring(1) }
            $parts += $keyName

            $newSc = $parts -join "+"
            $s.Text = $newSc
            $s.Tag  = $newSc
        })

        $pnlSc.Controls.Add($lbl)
        $pnlSc.Controls.Add($txt)
        $txtBoxes[$sc.Key] = $txt
        $curY += 34
    }

    $btnSaveSc = New-Object System.Windows.Forms.Button
    $btnSaveSc.Text = "Save and Apply Shortcuts"
    $btnSaveSc.Location = New-Object System.Drawing.Point(15, ($curY + 10))
    $btnSaveSc.Size = New-Object System.Drawing.Size(180, 32)
    $btnSaveSc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSaveSc.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $btnSaveSc.ForeColor = [System.Drawing.Color]::White
    $btnSaveSc.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $btnSaveSc.Add_Click({
        foreach ($k in $txtBoxes.Keys) {
            $script:config.Hotkeys.$k = $txtBoxes[$k].Text.Trim()
        }
        Save-Config
        Register-AllHotkeys
        (New-Object System.Windows.Forms.ToolTip).Show("Shortcuts updated and registered!", $btnSaveSc, 0, -25, 1500)
    })

    $btnResetSc = New-Object System.Windows.Forms.Button
    $btnResetSc.Text = "Reset Defaults"
    $btnResetSc.Location = New-Object System.Drawing.Point(205, ($curY + 10))
    $btnResetSc.Size = New-Object System.Drawing.Size(120, 32)
    $btnResetSc.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnResetSc.BackColor = [System.Drawing.Color]::FromArgb(47, 53, 72)
    $btnResetSc.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
    $btnResetSc.Add_Click({
        foreach ($sc in $scActions) {
            if ($txtBoxes.ContainsKey($sc.Key)) {
                $txtBoxes[$sc.Key].Text = $sc.Default
                $txtBoxes[$sc.Key].Tag  = $sc.Default
            }
        }
    })

    $pnlSc.Controls.Add($btnSaveSc)
    $pnlSc.Controls.Add($btnResetSc)
    $tabShortcuts.Controls.Add($pnlSc)

    # ==================== Tab 2: API Keys ====================
    $tabKeys = New-Object System.Windows.Forms.TabPage("API Keys")
    $tabKeys.BackColor = [System.Drawing.Color]::FromArgb(20, 22, 30)

    $keysList = New-Object System.Windows.Forms.ListBox
    $keysList.Dock = [System.Windows.Forms.DockStyle]::Top; $keysList.Height = 160
    $keysList.BackColor = [System.Drawing.Color]::FromArgb(14, 16, 22); $keysList.ForeColor = [System.Drawing.Color]::FromArgb(210, 230, 250)
    $keysList.Font = New-Object System.Drawing.Font("Consolas", 9.5)

    function Refresh-KeysList {
        $keysList.Items.Clear()
        foreach ($k in $script:config.Keys) {
            $masked = if ($k.Key.Length -gt 15) { $k.Key.Substring(0, 10) + "..." + $k.Key.Substring($k.Key.Length - 4) } else { $k.Key }
            $keysList.Items.Add("$($k.Provider.ToUpper()): $masked") | Out-Null
        }
    }
    Refresh-KeysList

    $pnlAdd = New-Object System.Windows.Forms.Panel
    $pnlAdd.Dock = [System.Windows.Forms.DockStyle]::Fill; $pnlAdd.Padding = New-Object System.Windows.Forms.Padding(10)
    $pnlAdd.BackColor = [System.Drawing.Color]::FromArgb(20, 22, 30)

    $lblProv = New-Object System.Windows.Forms.Label
    $lblProv.Text = "Provider:"; $lblProv.Location = New-Object System.Drawing.Point(10, 15); $lblProv.Size = New-Object System.Drawing.Size(65, 20)
    $lblProv.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)

    $cbProv = New-Object System.Windows.Forms.ComboBox
    $cbProv.Items.AddRange(@("groq", "openrouter"))
    $cbProv.SelectedIndex = 0; $cbProv.Location = New-Object System.Drawing.Point(80, 12); $cbProv.Size = New-Object System.Drawing.Size(100, 22)
    $cbProv.BackColor = [System.Drawing.Color]::FromArgb(30, 34, 48); $cbProv.ForeColor = [System.Drawing.Color]::White

    $lblKey = New-Object System.Windows.Forms.Label
    $lblKey.Text = "API Key:"; $lblKey.Location = New-Object System.Drawing.Point(190, 15); $lblKey.Size = New-Object System.Drawing.Size(60, 20)
    $lblKey.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)

    $txtKey = New-Object System.Windows.Forms.TextBox
    $txtKey.Location = New-Object System.Drawing.Point(255, 12); $txtKey.Size = New-Object System.Drawing.Size(200, 22)
    $txtKey.BackColor = [System.Drawing.Color]::FromArgb(30, 34, 48); $txtKey.ForeColor = [System.Drawing.Color]::White

    $btnAddKey = New-Object System.Windows.Forms.Button
    $btnAddKey.Text = "Add Key"; $btnAddKey.Location = New-Object System.Drawing.Point(465, 10); $btnAddKey.Size = New-Object System.Drawing.Size(80, 26)
    $btnAddKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnAddKey.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $btnAddKey.ForeColor = [System.Drawing.Color]::White
    $btnAddKey.Add_Click({
        $newK = $txtKey.Text.Trim()
        if ($newK) {
            $script:config.Keys += [PSCustomObject]@{ Provider = $cbProv.SelectedItem.ToString(); Key = $newK }
            $txtKey.Clear()
            Refresh-KeysList
            Save-Config
        }
    })

    $btnDelKey = New-Object System.Windows.Forms.Button
    $btnDelKey.Text = "Delete Selected"; $btnDelKey.Location = New-Object System.Drawing.Point(10, 50); $btnDelKey.Size = New-Object System.Drawing.Size(120, 28)
    $btnDelKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnDelKey.BackColor = [System.Drawing.Color]::FromArgb(180, 50, 50)
    $btnDelKey.ForeColor = [System.Drawing.Color]::White
    $btnDelKey.Add_Click({
        $idx = $keysList.SelectedIndex
        if ($idx -ge 0 -and $idx -lt $script:config.Keys.Count) {
            $newArr = @()
            for ($i = 0; $i -lt $script:config.Keys.Count; $i++) {
                if ($i -ne $idx) { $newArr += $script:config.Keys[$i] }
            }
            $script:config.Keys = $newArr
            Refresh-KeysList
            Save-Config
        }
    })

    $btnTestKeys = New-Object System.Windows.Forms.Button
    $btnTestKeys.Text = "Test All Keys"; $btnTestKeys.Location = New-Object System.Drawing.Point(140, 50); $btnTestKeys.Size = New-Object System.Drawing.Size(120, 28)
    $btnTestKeys.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnTestKeys.BackColor = [System.Drawing.Color]::FromArgb(40, 140, 70)
    $btnTestKeys.ForeColor = [System.Drawing.Color]::White
    $btnTestKeys.Add_Click({
        $btnTestKeys.Text = "Testing..."
        $validCount = 0
        foreach ($k in $script:config.Keys) {
            try {
                $url = if ($k.Provider -eq 'groq') { 'https://api.groq.com/openai/v1/chat/completions' } else { 'https://openrouter.ai/api/v1/chat/completions' }
                $mod = if ($k.Provider -eq 'groq') { 'qwen/qwen3.8-27b' } else { 'openrouter/free' }
                $hdr = @{ 'Authorization' = "Bearer $($k.Key)"; 'Content-Type' = 'application/json' }
                if ($k.Provider -eq 'openrouter') { $hdr['HTTP-Referer'] = 'https://github.com'; $hdr['X-Title'] = 'Test' }
                $body = @{ model = $mod; messages = @(@{ role = 'user'; content = 'PONG' }); max_tokens = 5 } | ConvertTo-Json
                $res = Invoke-RestMethod -Uri $url -Method POST -Headers $hdr -Body $body -TimeoutSec 7 -ErrorAction Stop
                $validCount++
            } catch {}
        }
        $btnTestKeys.Text = "$validCount/$($script:config.Keys.Count) Working"
        Write-Log "INFO" "Key test: $validCount of $($script:config.Keys.Count) keys active."
    })

    $pnlAdd.Controls.AddRange(@($lblProv, $cbProv, $lblKey, $txtKey, $btnAddKey, $btnDelKey, $btnTestKeys))
    $tabKeys.Controls.Add($pnlAdd); $tabKeys.Controls.Add($keysList)

    # ==================== Tab 3: Buttons and Dots ====================
    $tabButtons = New-Object System.Windows.Forms.TabPage("Buttons and Dots")
    $tabButtons.BackColor = [System.Drawing.Color]::FromArgb(20, 22, 30)

    $pnlDots = New-Object System.Windows.Forms.Panel
    $pnlDots.Dock = [System.Windows.Forms.DockStyle]::Fill; $pnlDots.Padding = New-Object System.Windows.Forms.Padding(15)
    $pnlDots.BackColor = [System.Drawing.Color]::FromArgb(20, 22, 30)

    $chkCap    = New-Object System.Windows.Forms.CheckBox; $chkCap.Text    = "[P] Blue: Screenshot to Clipboard"; $chkCap.Checked = $script:config.Buttons.Screenshot; $chkCap.Location = New-Object System.Drawing.Point(20, 20); $chkCap.AutoSize = $true; $chkCap.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $chkBrw    = New-Object System.Windows.Forms.CheckBox; $chkBrw.Text    = "[B] Green: Stealth Browser"; $chkBrw.Checked = $script:config.Buttons.Browser; $chkBrw.Location = New-Object System.Drawing.Point(20, 50); $chkBrw.AutoSize = $true; $chkBrw.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $chkOCR    = New-Object System.Windows.Forms.CheckBox; $chkOCR.Text    = "[A] Orange: Auto-Solve (MCQ / Code)"; $chkOCR.Checked = $script:config.Buttons.AutoSolve; $chkOCR.Location = New-Object System.Drawing.Point(20, 80); $chkOCR.AutoSize = $true; $chkOCR.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $chkTab    = New-Object System.Windows.Forms.CheckBox; $chkTab.Text    = "[W] Purple: Browser Tab Solver"; $chkTab.Checked = $script:config.Buttons.TabSolve; $chkTab.Location = New-Object System.Drawing.Point(20, 110); $chkTab.AutoSize = $true; $chkTab.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $chkJava   = New-Object System.Windows.Forms.CheckBox; $chkJava.Text   = "[J] Red: Java Code Solver"; $chkJava.Checked = $script:config.Buttons.Java; $chkJava.Location = New-Object System.Drawing.Point(20, 140); $chkJava.AutoSize = $true; $chkJava.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $chkCpp    = New-Object System.Windows.Forms.CheckBox; $chkCpp.Text    = "[C] Cyan: C++ Code Solver"; $chkCpp.Checked = $script:config.Buttons.Cpp; $chkCpp.Location = New-Object System.Drawing.Point(20, 170); $chkCpp.AutoSize = $true; $chkCpp.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $chkPy     = New-Object System.Windows.Forms.CheckBox; $chkPy.Text     = "[Py] Yellow: Python Code Solver"; $chkPy.Checked = $script:config.Buttons.Python; $chkPy.Location = New-Object System.Drawing.Point(20, 200); $chkPy.AutoSize = $true; $chkPy.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $chkConfig = New-Object System.Windows.Forms.CheckBox; $chkConfig.Text = "[S] Gray: Settings Panel"; $chkConfig.Checked = $script:config.Buttons.Settings; $chkConfig.Location = New-Object System.Drawing.Point(20, 230); $chkConfig.AutoSize = $true; $chkConfig.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)

    $btnApplyDots = New-Object System.Windows.Forms.Button
    $btnApplyDots.Text = "Save and Apply Dot Visibility"
    $btnApplyDots.Location = New-Object System.Drawing.Point(20, 275); $btnApplyDots.Size = New-Object System.Drawing.Size(200, 32)
    $btnApplyDots.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnApplyDots.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $btnApplyDots.ForeColor = [System.Drawing.Color]::White
    $btnApplyDots.Add_Click({
        $script:config.Buttons.Screenshot = $chkCap.Checked
        $script:config.Buttons.Browser    = $chkBrw.Checked
        $script:config.Buttons.AutoSolve  = $chkOCR.Checked
        $script:config.Buttons.TabSolve   = $chkTab.Checked
        $script:config.Buttons.Java       = $chkJava.Checked
        $script:config.Buttons.Cpp        = $chkCpp.Checked
        $script:config.Buttons.Python     = $chkPy.Checked
        $script:config.Buttons.Settings   = $chkConfig.Checked
        Save-Config
        Update-DotBarLayout
        (New-Object System.Windows.Forms.ToolTip).Show("Dot layout updated!", $btnApplyDots, 0, -25, 1200)
    })

    $pnlDots.Controls.AddRange(@($chkCap, $chkBrw, $chkOCR, $chkTab, $chkJava, $chkCpp, $chkPy, $chkConfig, $btnApplyDots))
    $tabButtons.Controls.Add($pnlDots)

    # ==================== Tab 4: Preferences ====================
    $tabPref = New-Object System.Windows.Forms.TabPage("Preferences")
    $tabPref.BackColor = [System.Drawing.Color]::FromArgb(20, 22, 30)

    $chkAffinity = New-Object System.Windows.Forms.CheckBox
    $chkAffinity.Text = "Screen-Capture Invisibility (Invisible to OBS, Zoom, Teams, Proctoring)"; $chkAffinity.Checked = $script:config.StealthAffinity
    $chkAffinity.Location = New-Object System.Drawing.Point(20, 20); $chkAffinity.AutoSize = $true; $chkAffinity.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)

    $chkConsole = New-Object System.Windows.Forms.CheckBox
    $chkConsole.Text = "Show Live Console for Testing / Debugging"; $chkConsole.Checked = $script:config.ShowConsole
    $chkConsole.Location = New-Object System.Drawing.Point(20, 55); $chkConsole.AutoSize = $true; $chkConsole.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)

    $btnResetPos = New-Object System.Windows.Forms.Button
    $btnResetPos.Text = "Reset Window Position and Size"; $btnResetPos.Location = New-Object System.Drawing.Point(20, 90); $btnResetPos.Size = New-Object System.Drawing.Size(240, 30)
    $btnResetPos.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnResetPos.BackColor = [System.Drawing.Color]::FromArgb(47, 53, 72); $btnResetPos.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
    $btnResetPos.Add_Click({
        $script:winX = -1; $script:winY = -1; $script:winW = 480; $script:winH = 280
        $script:config.WindowPos.X = -1; $script:config.WindowPos.Y = -1; $script:config.WindowPos.W = 480; $script:config.WindowPos.H = 280
        Save-Config
        (New-Object System.Windows.Forms.ToolTip).Show("Window position and size reset!", $btnResetPos, 0, -25, 1200)
    })

    $btnOpenLogs = New-Object System.Windows.Forms.Button
    $btnOpenLogs.Text = "Open Live GUI Log Console"; $btnOpenLogs.Location = New-Object System.Drawing.Point(20, 130); $btnOpenLogs.Size = New-Object System.Drawing.Size(240, 30)
    $btnOpenLogs.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnOpenLogs.BackColor = [System.Drawing.Color]::FromArgb(47, 53, 72); $btnOpenLogs.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
    $btnOpenLogs.Add_Click({ Show-LogWindow })

    $lblTimeout = New-Object System.Windows.Forms.Label
    $lblTimeout.Text = "Quiz Answer Auto-Hide (sec):"; $lblTimeout.Location = New-Object System.Drawing.Point(20, 175); $lblTimeout.Size = New-Object System.Drawing.Size(180, 20); $lblTimeout.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)

    $txtTimeout = New-Object System.Windows.Forms.TextBox
    $txtTimeout.Text = $script:config.AnswerTimeoutSec.ToString(); $txtTimeout.Location = New-Object System.Drawing.Point(200, 173); $txtTimeout.Size = New-Object System.Drawing.Size(60, 22)
    $txtTimeout.BackColor = [System.Drawing.Color]::FromArgb(30, 34, 48); $txtTimeout.ForeColor = [System.Drawing.Color]::White

    $btnSavePref = New-Object System.Windows.Forms.Button
    $btnSavePref.Text = "Save Preferences"; $btnSavePref.Location = New-Object System.Drawing.Point(20, 220); $btnSavePref.Size = New-Object System.Drawing.Size(160, 32)
    $btnSavePref.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnSavePref.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235); $btnSavePref.ForeColor = [System.Drawing.Color]::White
    $btnSavePref.Add_Click({
        $script:config.StealthAffinity  = $chkAffinity.Checked
        $script:config.ShowConsole      = $chkConsole.Checked
        $t = 40; [int]::TryParse($txtTimeout.Text, [ref]$t) | Out-Null
        $script:config.AnswerTimeoutSec = $t
        Save-Config
        [StealthAPI]::ApplyStealthAffinity($bar.Handle, $script:config.StealthAffinity) | Out-Null
        [StealthAPI]::ApplyStealthAffinity($bForm.Handle, $script:config.StealthAffinity) | Out-Null
        if ($script:codeForm -and -not $script:codeForm.IsDisposed) {
            [StealthAPI]::ApplyStealthAffinity($script:codeForm.Handle, $script:config.StealthAffinity) | Out-Null
        }
        (New-Object System.Windows.Forms.ToolTip).Show("Preferences saved!", $btnSavePref, 0, -25, 1200)
    })

    $tabPref.Controls.AddRange(@($chkAffinity, $chkConsole, $btnResetPos, $btnOpenLogs, $lblTimeout, $txtTimeout, $btnSavePref))

    $tabs.TabPages.AddRange(@($tabShortcuts, $tabKeys, $tabButtons, $tabPref))
    $sf.Controls.Add($tabs)

    [StealthAPI]::ApplyStealthAffinity($sf.Handle, $script:config.StealthAffinity) | Out-Null
    $sf.ShowDialog() | Out-Null
    $sf.Dispose()
}

# --- Context Menu (Right Click on Dots) ---
function Quit-StealthAssistant {
    $script:isQuitting = $true
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 1) | Out-Null } catch {}
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 2) | Out-Null } catch {}
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 3) | Out-Null } catch {}
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 4) | Out-Null } catch {}
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 5) | Out-Null } catch {}
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 6) | Out-Null } catch {}
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 7) | Out-Null } catch {}
    try { [StealthAPI]::UnregisterHotKey($bar.Handle, 8) | Out-Null } catch {}

    try { if ($bar) { $bar.Hide(); $bar.Close(); $bar.Dispose() } } catch {}
    try { if ($bForm) { $bForm.Hide(); $bForm.Close(); $bForm.Dispose() } } catch {}
    try { if ($script:aiLabel) { $script:aiLabel.Close(); $script:aiLabel.Dispose() } } catch {}
    try { if ($script:codeForm) { $script:codeForm.Close(); $script:codeForm.Dispose() } } catch {}
    try { if ($script:guiLogForm) { $script:guiLogForm.Close(); $script:guiLogForm.Dispose() } } catch {}

    try { [System.Windows.Forms.Application]::Exit() } catch {}
    try { Stop-Process -Id $PID -Force } catch {}
}

$ctx = New-Object System.Windows.Forms.ContextMenuStrip

$modeMenu = New-Object System.Windows.Forms.ToolStripMenuItem("Solving Mode")
$modes = @("Auto Detect", "Quiz / MCQ", "Java Code", "C++ Code", "Python Code")
foreach ($m in $modes) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem($m)
    $item.Tag = switch ($m) {
        "Auto Detect" { "auto" }
        "Quiz / MCQ"  { "quiz" }
        "Java Code"   { "java" }
        "C++ Code"    { "cpp" }
        "Python Code" { "python" }
    }
    $item.Add_Click({
        param($s,$e)
        $script:currentMode = $s.Tag
        $script:config.DefaultMode = $s.Tag
        Save-Config
        foreach ($sub in $modeMenu.DropDownItems) { $sub.Checked = ($sub.Tag -eq $script:currentMode) }
        Write-Log "INFO" "Mode switched to: $($script:currentMode.ToUpper())"
    })
    if ($item.Tag -eq $script:currentMode) { $item.Checked = $true }
    $modeMenu.DropDownItems.Add($item) | Out-Null
}

$mBrw    = New-Object System.Windows.Forms.ToolStripMenuItem("Stealth Browser (Ctrl+Shift+B)")
$mCap    = New-Object System.Windows.Forms.ToolStripMenuItem("Screenshot to Clipboard (Ctrl+Shift+P)")
$mSolve  = New-Object System.Windows.Forms.ToolStripMenuItem("Auto-Solve MCQ (Ctrl+Shift+T / S)")
$mJava   = New-Object System.Windows.Forms.ToolStripMenuItem("Solve in Java (Ctrl+Shift+J)")
$mCpp    = New-Object System.Windows.Forms.ToolStripMenuItem("Solve in C++ (Ctrl+Shift+C)")
$mPy     = New-Object System.Windows.Forms.ToolStripMenuItem("Solve in Python (Ctrl+Shift+Y)")
$mConfig = New-Object System.Windows.Forms.ToolStripMenuItem("Settings & API Keys...")
$mLogs   = New-Object System.Windows.Forms.ToolStripMenuItem("Open Live Debug Console")
$mEsc    = New-Object System.Windows.Forms.ToolStripMenuItem("Dismiss Overlays (Esc)")
$mQuit   = New-Object System.Windows.Forms.ToolStripMenuItem("Panic Kill / Exit (Ctrl+Shift+Q)")
$mQuit.ForeColor = [System.Drawing.Color]::FromArgb(240, 60, 60)

$mBrw.Add_Click({ Toggle-StealthBrowser })
$mCap.Add_Click({ Take-StealthScreenshot })
$mSolve.Add_Click({ Start-CombinedSolveFlow -SpecificLang "auto" })
$mJava.Add_Click({ Start-AISolveFlow -SpecificLang "java" })
$mCpp.Add_Click({ Start-AISolveFlow -SpecificLang "cpp" })
$mPy.Add_Click({ Start-AISolveFlow -SpecificLang "python" })
$mConfig.Add_Click({ Show-SettingsPanel })
$mLogs.Add_Click({ Show-LogWindow })
$mEsc.Add_Click({
    if ($script:aiLabel)  { $script:aiLabel.Close();  $script:aiLabel = $null }
    if ($script:codeForm) { $script:codeForm.Close(); $script:codeForm = $null }
})
$mQuit.Add_Click({ Quit-StealthAssistant })

$ctx.Items.AddRange(@(
    $modeMenu,
    (New-Object System.Windows.Forms.ToolStripSeparator),
    $mBrw, $mCap, $mSolve,
    (New-Object System.Windows.Forms.ToolStripSeparator),
    $mJava, $mCpp, $mPy,
    (New-Object System.Windows.Forms.ToolStripSeparator),
    $mConfig, $mLogs, $mEsc, $mQuit
))

foreach ($b in @($btnCap, $btnBrw, $btnOCR, $btnJava, $btnCpp, $btnPy, $btnConfig, $bar)) {
    $b.ContextMenuStrip = $ctx
}

Update-DotBarLayout

# Only initialize once so Shown event never creates multiple hotkey hooks
$script:barInitialized = $false
$bar.Add_Shown({
    if ($script:barInitialized) { return }
    $script:barInitialized = $true

    [StealthAPI]::ApplyStealthAffinity($bar.Handle, $script:config.StealthAffinity) | Out-Null
    $ex = [StealthAPI]::GetWindowLong($bar.Handle, [StealthAPI]::GWL_EXSTYLE)
    [StealthAPI]::SetWindowLong($bar.Handle, [StealthAPI]::GWL_EXSTYLE, $ex -bor [StealthAPI]::WS_EX_TOOLWINDOW) | Out-Null
    [StealthAPI]::SetWindowPos($bar.Handle, [StealthAPI]::HWND_TOPMOST, 0, 0, 0, 0, ([StealthAPI]::SWP_NOMOVE -bor [StealthAPI]::SWP_NOSIZE -bor [StealthAPI]::SWP_FRAMECHANGED)) | Out-Null

    try {
        $script:hkw = New-Object StealthHotkeyNW($bar.Handle)
        Register-AllHotkeys
        Write-Log "INFO" "Global hotkeys registered successfully."
    } catch {
        Write-Log "ERR" "Failed to register hotkeys: $($_.Exception.Message)"
    }
})

$hkTimer = New-Object System.Windows.Forms.Timer
$hkTimer.Interval = 80
$hkTimer.Add_Tick({
    try {
        $k = [StealthHotkeyNW]::LastKey
        if ($k -gt 0) {
            [StealthHotkeyNW]::LastKey = 0
            switch ($k) {
                1 { Toggle-StealthBrowser }
                2 { Take-StealthScreenshot }
                3 { Start-CombinedSolveFlow -SpecificLang "auto" }
                4 { Quit-StealthAssistant }
                5 { Start-AISolveFlow -SpecificLang "java" }
                6 { Start-AISolveFlow -SpecificLang "cpp" }
                7 { Start-AISolveFlow -SpecificLang "python" }
                8 { Start-CombinedSolveFlow -SpecificLang "auto" }
            }
        }
    } catch {}
})
$hkTimer.Start()

Write-Log "INFO" "Universal Stealth Assistant is running. Press Ctrl+Shift+Q to exit."

if ($MyInvocation.InvocationName -ne '.') {
    [System.Windows.Forms.Application]::Run($bar)
}
