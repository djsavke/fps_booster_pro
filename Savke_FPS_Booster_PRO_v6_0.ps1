Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =========================
#  GLOBAL SETTINGS
# =========================
$CurrentVersion = "6.1.0"
$AppTitle       = "Savke FPS Booster PRO v6.1 ULTIMATE SMOOTH"
$UpdateInfoUrl  = "https://example.com/savke_fps_booster_version.txt"

$LogFolder = "C:\SavkeFPSBooster"
$LogFile   = Join-Path $LogFolder "log.txt"

if (!(Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# =========================
#  LOG FUNKCIJE
# =========================
function Write-LogFile {
    param([string]$Text)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "[$timestamp] $Text"
}

function Add-Log {
    param(
        [System.Windows.Controls.TextBox]$Box,
        [string]$Text
    )
    if (-not $Box) { return }
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $msg = "[$timestamp] $Text"
    $Box.AppendText("$msg`r`n")
    $Box.ScrollToEnd()
    Write-LogFile $Text
}

# =========================
#  ADMIN CHECK
# =========================
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    [System.Windows.MessageBox]::Show(
        "Pokreni kao Administrator (Right-click > Run with PowerShell).",
        "Savke FPS Booster PRO"
    ) | Out-Null
    exit
}

# =========================
#  HELPER: USAGE BAR
# =========================
function Get-UsageBar {
    param(
        [double]$Percent,
        [int]$Width = 24
    )
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }

    $filled = [int]([math]::Round($Percent / 100 * $Width))
    if ($filled -gt $Width) { $filled = $Width }
    $empty  = $Width - $filled

    return ("[{0}{1}] {2:N0}%%" -f ("#" * $filled), ("-" * $empty), $Percent)
}

# =========================
#  OSNOVNI TWEAKOVI
# =========================
function Set-PowerPlan {
    param($LogBox)
    try {
        Add-Log $LogBox "Podesavam power plan na High / Ultimate Performance..."
        $ultimate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $highPerf = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

        if (powercfg -list | Select-String $ultimate) {
            powercfg -setactive $ultimate | Out-Null
            Add-Log $LogBox "Ultimate Performance aktivan."
        } else {
            powercfg -setactive $highPerf | Out-Null
            Add-Log $LogBox "High Performance aktivan."
        }
    } catch {
        Add-Log $LogBox "Power plan tweak neuspesan: $($_.Exception.Message)"
    }
}

function Disable-GameBarDVR {
    param($LogBox)
    try {
        Add-Log $LogBox "Gasim Xbox Game Bar / Game DVR..."
        $paths = @(
            "HKCU:\System\GameConfigStore",
            "HKCU:\Software\Microsoft\GameBar"
        )
        foreach ($p in $paths) {
            if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        }

        Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force
        Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Value 0 -Type DWord -Force
        Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "GamebarPresenceWriter" -Value 0 -Type DWord -Force

        Add-Log $LogBox "Game Bar / DVR ugaseni."
    } catch {
        Add-Log $LogBox "Game Bar tweak neuspesan."
    }
}

function Optimize-Services {
    param($LogBox)
    try {
        Add-Log $LogBox "Zaustavljam neke background servise..."
        $services = @(
            "SysMain",
            "XblGameSave",
            "XboxGipSvc",
            "XboxNetApiSvc"
        )
        foreach ($s in $services) {
            try {
                Stop-Service $s -Force -ErrorAction SilentlyContinue
                Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
                Add-Log $LogBox "Servis $s zaustavljen / onemogucen."
            } catch {}
        }
    } catch {
        Add-Log $LogBox "Service tweak neuspesan."
    }
}

function Clean-Temp {
    param($LogBox)
    try {
        Add-Log $LogBox "Cistim TEMP foldere..."
        $paths = @($env:TEMP, "$env:WINDIR\Temp")
        foreach ($p in $paths) {
            try {
                if (Test-Path $p) {
                    Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }
        Add-Log $LogBox "TEMP ociscen."
    } catch {
        Add-Log $LogBox "Temp cleanup neuspesan."
    }
}

function Flush-DNS {
    param($LogBox)
    try {
        Add-Log $LogBox "Flushing DNS cache..."
        ipconfig /flushdns | Out-Null
        Add-Log $LogBox "DNS cache ociscen."
    } catch {
        Add-Log $LogBox "DNS flush neuspesan."
    }
}

# =========================
#  CS2 TWEAKOVI
# =========================
function Apply-CS2Tweaks {
    param($LogBox)

    Add-Log $LogBox "Primena CS2 specific tweake-va..."

    try {
        $gpu = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (!(Test-Path $gpu)) { New-Item -Path $gpu -Force | Out-Null }

        Set-ItemProperty $gpu -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
        Set-ItemProperty $gpu -Name "SystemResponsiveness"   -Value 0 -Type DWord -Force

        $games = "$gpu\Tasks\Games"
        if (!(Test-Path $games)) { New-Item -Path $games -Force | Out-Null }

        Set-ItemProperty $games -Name "GPU Priority" -Value 8 -Type DWord -Force
        Set-ItemProperty $games -Name "Priority"     -Value 6 -Type DWord -Force
        Add-Log $LogBox "CS2 GPU High Priority postavljen."
    } catch {
        Add-Log $LogBox "CS2 GPU priority tweak neuspesan."
    }

    try {
        $shaderCache = "$env:LOCALAPPDATA\Steam\shadercache"
        if (Test-Path $shaderCache) {
            Remove-Item "$shaderCache\*" -Recurse -Force -ErrorAction SilentlyContinue
            Add-Log $LogBox "Steam shadercache ociscen."
        }
    } catch {
        Add-Log $LogBox "Shader cache cleanup neuspesan."
    }

    Add-Log $LogBox "CS2 tweake-vi primenjeni."
}

# =========================
#  NVIDIA DRIVER BOOST
# =========================
function Apply-GPUDriverBoost {
    param($LogBox)

    Add-Log $LogBox "Pokrecem NVIDIA GPU Driver Boost..."

    $paths = @(
        "C:\ProgramData\NVIDIA Corporation\NV_Cache",
        "$env:LOCALAPPDATA\NVIDIA\DXCache",
        "$env:LOCALAPPDATA\NVIDIA\GLCache"
    )
    foreach ($p in $paths) {
        try {
            if (Test-Path $p) {
                Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                Add-Log $LogBox "Cache ociscen: $p"
            }
        } catch {}
    }

    Add-Log $LogBox "GPU Driver Boost zavrsen."
}

# =========================
#  EXTREME MODE & PRESETI
# =========================
function Run-ExtremeMode {
    param($LogBox)

    Add-Log $LogBox "EXTREME MODE start..."

    try {
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
        Add-Log $LogBox "CPU throttle min/max -> 100%."
    } catch {
        Add-Log $LogBox "CPU throttle tweak neuspesan."
    }

    try {
        $net = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        if (!(Test-Path $net)) { New-Item -Path $net -Force | Out-Null }

        Set-ItemProperty $net -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
        Set-ItemProperty $net -Name "TCPNoDelay"     -Value 1 -Type DWord -Force
        Set-ItemProperty $net -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force

        Add-Log $LogBox "Network EXTREME tweaks primenjeni."
    } catch {
        Add-Log $LogBox "Network EXTREME tweaks neuspesni."
    }

    Add-Log $LogBox "EXTREME MODE zavrsen. Restart preporucen."
}

function Invoke-SafeBoost {
    param($LogBox)

    Add-Log $LogBox "SAFE BOOST start..."
    Set-PowerPlan      -LogBox $LogBox
    Disable-GameBarDVR -LogBox $LogBox
    Optimize-Services  -LogBox $LogBox
    Flush-DNS          -LogBox $LogBox
    Add-Log $LogBox "SAFE BOOST zavrsen."
}

function Invoke-HardBoost {
    param($LogBox)

    Add-Log $LogBox "HARD BOOST start..."
    Set-PowerPlan        -LogBox $LogBox
    Disable-GameBarDVR   -LogBox $LogBox
    Optimize-Services    -LogBox $LogBox
    Clean-Temp           -LogBox $LogBox
    Flush-DNS            -LogBox $LogBox
    Apply-CS2Tweaks      -LogBox $LogBox
    Apply-GPUDriverBoost -LogBox $LogBox
    Run-ExtremeMode      -LogBox $LogBox
    Add-Log $LogBox "HARD BOOST zavrsen."
}

function Run-CS2OnlyPreset {
    param($LogBox)

    Add-Log $LogBox "CS2 ONLY MODE start..."
    Apply-CS2Tweaks      -LogBox $LogBox
    Apply-GPUDriverBoost -LogBox $LogBox

    try {
        $net = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        if (!(Test-Path $net)) { New-Item -Path $net -Force | Out-Null }

        Set-ItemProperty $net -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
        Set-ItemProperty $net -Name "TCPNoDelay"     -Value 1 -Type DWord -Force
        Set-ItemProperty $net -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force

        Add-Log $LogBox "CS2 network tweaks primenjeni."
    } catch {
        Add-Log $LogBox "CS2 network tweaks neuspesni."
    }

    Add-Log $LogBox "CS2 ONLY MODE zavrsen."
}

# =========================
#  HAGS
# =========================
function Get-HAGSState {
    try {
        $reg = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        $v = (Get-ItemProperty $reg -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
        if ($v -eq 2) { return "ON" }
        if ($v -eq 1) { return "OFF" }
        return "DEFAULT"
    } catch { return "DEFAULT" }
}

function Set-HAGS {
    param(
        [bool]$Enable,
        $LogBox
    )
    try {
        $reg = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (!(Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }

        $val = if ($Enable) { 2 } else { 1 }
        Set-ItemProperty $reg -Name "HwSchMode" -Value $val -Type DWord -Force

        Add-Log $LogBox "HAGS: $Enable (restart za pun efekat)."
    } catch {
        Add-Log $LogBox "HAGS tweak neuspesan."
    }
}

# =========================
#  UPDATE CHECK
# =========================
function Check-ForUpdate {
    param($LogBox)

    if ([string]::IsNullOrWhiteSpace($UpdateInfoUrl)) {
        Add-Log $LogBox "Update URL nije podesen."
        return
    }

    try {
        Add-Log $LogBox "Proveravam update..."
        $resp = Invoke-WebRequest -Uri $UpdateInfoUrl -UseBasicParsing -TimeoutSec 5
        $remoteVer = $resp.Content.Trim()

        if ($remoteVer -and $remoteVer -ne $CurrentVersion) {
            Add-Log $LogBox "Nova verzija: $remoteVer"
            [System.Windows.MessageBox]::Show(
                "Dostupna je nova verzija: $remoteVer`nOtvori stranicu za preuzimanje.",
                "Update"
            ) | Out-Null
        } else {
            Add-Log $LogBox "Vec imas najnoviju verziju."
        }
    } catch {
        Add-Log $LogBox "Ne mogu da proverim update (net/URL problem)."
    }
}

# =========================
#  XAML WPF UI
# =========================
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$AppTitle" Height="560" Width="900"
        Background="#050518" ResizeMode="CanResizeWithGrip"
        WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="220"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- LEFT PANEL -->
    <Border Grid.RowSpan="3" Grid.Column="0" Background="#10102A" CornerRadius="12" Padding="10" Margin="0,0,10,0">
      <StackPanel>
        <Border Height="170" Background="#05050F" CornerRadius="12" Margin="0,0,0,10">
          <Image x:Name="LogoImage" Stretch="Uniform" Margin="5"/>
        </Border>
        <TextBlock Text="Savke FPS Booster" FontSize="18" FontWeight="Bold"
                   Foreground="#00C8FF" Margin="0,0,0,2"/>
        <TextBlock Text="ULTRA v6.1 ULTIMATE SMOOTH" FontSize="12" Foreground="#CCCCCC" Margin="0,0,0,10"/>
        <TextBlock Text="Tip:" FontWeight="Bold" Foreground="#FFFFFF"/>
        <TextBlock Text="SAFE = lagani boost, HARD = full send, CS2 ONLY = samo CS2/net/gpu."
                   TextWrapping="Wrap" Foreground="#AAAAAA" FontSize="11"/>
      </StackPanel>
    </Border>

    <!-- HEADER / STATUS -->
    <StackPanel Grid.Column="1" Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Top">
      <TextBlock x:Name="StatusLabel"
                 Text="Status: Ready"
                 Foreground="#00DC96"
                 FontSize="14"
                 Margin="0,0,10,0"
                 VerticalAlignment="Center"/>
      <Button x:Name="UpdateButton"
              Content="Check for Update"
              Width="130" Height="26"
              Margin="0,0,0,0"
              Padding="4"
              FontSize="11"
              Background="#283060"
              Foreground="White"
              BorderBrush="#00C8FF"
              BorderThickness="1"/>
    </StackPanel>

    <!-- MAIN CONTENT -->
    <StackPanel Grid.Column="1" Grid.Row="1" Margin="0,10,0,10">
      <!-- HUD -->
      <Border Background="#10102A" CornerRadius="10" Padding="10" Margin="0,0,0,8">
        <StackPanel>
          <TextBlock Text="Live HUD" Foreground="#FFFFFF" FontSize="13" FontWeight="Bold" Margin="0,0,0,6"/>
          <TextBlock x:Name="HudCpu" Text="CPU: ..." Foreground="#CCCCCC" FontFamily="Consolas"/>
          <TextBlock x:Name="HudRam" Text="RAM: ..." Foreground="#CCCCCC" FontFamily="Consolas"/>
        </StackPanel>
      </Border>

      <!-- BUTTON ROW 1 -->
      <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
        <Button x:Name="SafeButton" Content="SAFE BOOST" Width="150" Height="32" Margin="0,0,6,0"/>
        <Button x:Name="HardButton" Content="HARD BOOST" Width="150" Height="32" Margin="0,0,6,0"/>
        <Button x:Name="Cs2OnlyButton" Content="CS2 ONLY MODE" Width="150" Height="32" Margin="0,0,6,0"/>
      </StackPanel>

      <!-- BUTTON ROW 2 -->
      <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
        <Button x:Name="GpuButton" Content="GPU DRIVER BOOST" Width="150" Height="30" Margin="0,0,6,0"/>
        <Button x:Name="ExtremeButton" Content="EXTREME MODE" Width="150" Height="30" Margin="0,0,6,0"/>
        <Button x:Name="MonitorButton" Content="REALTIME MONITOR" Width="150" Height="30" Margin="0,0,6,0"/>
      </StackPanel>

      <!-- BUTTON ROW 3 -->
      <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
        <Button x:Name="BenchmarkButton" Content="BENCHMARK OVERLAY" Width="150" Height="28" Margin="0,0,6,0"/>
        <Button x:Name="HagsButton" Content="HAGS: ?" Width="150" Height="28" Margin="0,0,6,0"/>
      </StackPanel>

      <!-- LOG -->
      <Border Background="#050518" CornerRadius="10" Padding="6" Margin="0,6,0,0">
        <TextBox x:Name="LogBox"
                 FontFamily="Consolas"
                 FontSize="11"
                 Foreground="White"
                 Background="#050518"
                 BorderThickness="0"
                 IsReadOnly="True"
                 VerticalScrollBarVisibility="Auto"
                 TextWrapping="NoWrap"
                 AcceptsReturn="True"
                 Height="260"/>
      </Border>
    </StackPanel>

    <!-- FOOTER -->
    <TextBlock Grid.Column="1" Grid.Row="2"
               Text="Savke FPS Booster PRO WPF Smooth Edition v6.1 – by Savke &amp; ChatGPT"
               Foreground="#666666" FontSize="11" HorizontalAlignment="Right"/>
  </Grid>
</Window>
"@

# =========================
#  LOAD XAML
# =========================
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# GET CONTROLS
$StatusLabel     = $window.FindName("StatusLabel")
$UpdateButton    = $window.FindName("UpdateButton")
$HudCpu          = $window.FindName("HudCpu")
$HudRam          = $window.FindName("HudRam")
$SafeButton      = $window.FindName("SafeButton")
$HardButton      = $window.FindName("HardButton")
$Cs2OnlyButton   = $window.FindName("Cs2OnlyButton")
$GpuButton       = $window.FindName("GpuButton")
$ExtremeButton   = $window.FindName("ExtremeButton")
$MonitorButton   = $window.FindName("MonitorButton")
$BenchmarkButton = $window.FindName("BenchmarkButton")
$HagsButton      = $window.FindName("HagsButton")
$LogBox          = $window.FindName("LogBox")
$LogoImage       = $window.FindName("LogoImage")

# =========================
#  LOGO LOAD
# =========================
try {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir -or $scriptDir -eq "") {
        if ($MyInvocation.MyCommand.Path) {
            $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        } else {
            $scriptDir = (Get-Location).Path
        }
    }
    $logoPath = Join-Path $scriptDir "logo.png"
    if (Test-Path $logoPath) {
        $uri = New-Object System.Uri($logoPath, [System.UriKind]::Absolute)
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.UriSource = $uri
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $LogoImage.Source = $bmp
    }
} catch { }

# =========================
#  FADE-IN ANIMACIJA
# =========================
$script:fadeTimer = $null
$window.Opacity = 0.0
$window.Add_Loaded({
    $script:fadeTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:fadeTimer.Interval = [System.TimeSpan]::FromMilliseconds(30)
    $script:fadeTimer.Add_Tick({
        try {
            if ($window -and $window.IsVisible -and $window.Opacity -lt 1.0) {
                $window.Opacity += 0.05
            } else {
                if ($script:fadeTimer) { $script:fadeTimer.Stop() }
            }
        } catch {
            if ($script:fadeTimer) { $script:fadeTimer.Stop() }
        }
    })
    $script:fadeTimer.Start()
})

# =========================
#  TRAY ICON / MINIMIZE TO TRAY
# =========================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Text = $AppTitle
$notifyIcon.Visible = $true

$notifyIcon.Add_MouseClick({
    if (-not $window.IsVisible -or $window.WindowState -eq 'Minimized') {
        $window.Show()
        $window.WindowState = 'Normal'
        $window.Activate()
    }
})

$window.Add_StateChanged({
    if ($window.WindowState -eq 'Minimized') {
        $window.Hide()
        $notifyIcon.ShowBalloonTip(
            800,
            "Savke FPS Booster",
            "App je minimizovan u tray.",
            [System.Windows.Forms.ToolTipIcon]::Info
        )
    }
})

$window.Add_Closed({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
})

# =========================
#  STATUS & ANIMACIJA
# =========================
$script:Animating = $false
$script:BaseStatusText = "Status: Working"

$statusTimer = New-Object System.Windows.Threading.DispatcherTimer
$statusTimer.Interval = [System.TimeSpan]::FromMilliseconds(300)
$dotState = 0
$statusTimer.Add_Tick({
    if ($script:Animating -and $StatusLabel) {
        $dots = "." * $dotState
        $StatusLabel.Text = "$($script:BaseStatusText)$dots"
        $dotState = ($dotState + 1) % 4
    }
})
$statusTimer.Start()

# =========================
#  SMOOTH HUD TIMER
# =========================
$HudTimer = New-Object System.Windows.Threading.DispatcherTimer
$HudTimer.Interval = [System.TimeSpan]::FromMilliseconds(1500)
$HudTimer.Add_Tick({
    try {
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
        if ($HudCpu) { $HudCpu.Text = "CPU " + (Get-UsageBar -Percent $cpu -Width 28) }
    } catch {}
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $total = $os.TotalVisibleMemorySize
        $free  = $os.FreePhysicalMemory
        $used  = ($total - $free) / $total * 100
        if ($HudRam) { $HudRam.Text = "RAM " + (Get-UsageBar -Percent $used -Width 28) }
    } catch {}
})
$HudTimer.Start()

# =========================
#  HAGS INITIAL
# =========================
$initialHags = Get-HAGSState
if ($initialHags -eq "ON") {
    $HagsButton.Content = "HAGS: ON (RTX)"
    $HagsButton.Background = "DarkGreen"
    $HagsButton.Foreground = "White"
    $HagsButton.Tag = $true
} else {
    $HagsButton.Content = "HAGS: OFF"
    $HagsButton.Background = "#283060"
    $HagsButton.Foreground = "White"
    $HagsButton.Tag = $false
}

# =========================
#  EVENT HANDLERS
# =========================
$SafeButton.Add_Click({
    $script:Animating = $true
    $script:BaseStatusText = "Status: SAFE BOOST"
    Invoke-SafeBoost -LogBox $LogBox
    $script:Animating = $false
    $StatusLabel.Text = "Status: SAFE BOOST finished"
})

$HardButton.Add_Click({
    $script:Animating = $true
    $script:BaseStatusText = "Status: HARD BOOST"
    Invoke-HardBoost -LogBox $LogBox
    $script:Animating = $false
    $StatusLabel.Text = "Status: HARD BOOST finished"
})

$Cs2OnlyButton.Add_Click({
    $script:Animating = $true
    $script:BaseStatusText = "Status: CS2 ONLY"
    Run-CS2OnlyPreset -LogBox $LogBox
    $script:Animating = $false
    $StatusLabel.Text = "Status: CS2 ONLY finished"
})

$GpuButton.Add_Click({
    $script:Animating = $true
    $script:BaseStatusText = "Status: GPU BOOST"
    Apply-GPUDriverBoost -LogBox $LogBox
    $script:Animating = $false
    $StatusLabel.Text = "Status: GPU BOOST finished"
})

$ExtremeButton.Add_Click({
    $script:Animating = $true
    $script:BaseStatusText = "Status: EXTREME MODE"
    Run-ExtremeMode -LogBox $LogBox
    $script:Animating = $false
    $StatusLabel.Text = "Status: EXTREME MODE finished"
})

$UpdateButton.Add_Click({
    Check-ForUpdate -LogBox $LogBox
})

$HagsButton.Add_Click({
    $current = [bool]$HagsButton.Tag
    $enable  = -not $current
    Set-HAGS -Enable $enable -LogBox $LogBox
    if ($enable) {
        $HagsButton.Content = "HAGS: ON (RTX)"
        $HagsButton.Background = "DarkGreen"
        $HagsButton.Tag = $true
    } else {
        $HagsButton.Content = "HAGS: OFF"
        $HagsButton.Background = "#283060"
        $HagsButton.Tag = $false
    }
})

# -------- REALTIME MONITOR (FIX: dodato monTimer.Start) ----------
$MonitorButton.Add_Click({
    $monXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Savke Monitor" Height="170" Width="260"
        Background="#0A0A20" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Topmost="True">
  <StackPanel Margin="10">
    <TextBlock Text="Realtime Monitor" Foreground="White" FontWeight="Bold" Margin="0,0,0,8"/>
    <TextBlock x:Name="MonCpu" Text="CPU: ..." Foreground="#CCCCCC" Margin="0,0,0,4"/>
    <TextBlock x:Name="MonRam" Text="RAM: ..." Foreground="#CCCCCC" Margin="0,0,0,4"/>
    <TextBlock x:Name="MonInfo" Text="GPU 3D: ..." Foreground="#CCCCCC" Margin="0,0,0,4"/>
    <Button x:Name="CloseBtn" Content="Close" Width="70" Height="24" HorizontalAlignment="Center" Margin="0,8,0,0"/>
  </StackPanel>
</Window>
"@
    $r = New-Object System.Xml.XmlNodeReader ([xml]$monXaml)
    $monWindow = [System.Windows.Markup.XamlReader]::Load($r)
    $MonCpu  = $monWindow.FindName("MonCpu")
    $MonRam  = $monWindow.FindName("MonRam")
    $MonInfo = $monWindow.FindName("MonInfo")
    $CloseBtn= $monWindow.FindName("CloseBtn")

    $monTimer = New-Object System.Windows.Threading.DispatcherTimer
    $monTimer.Interval = [System.TimeSpan]::FromSeconds(1)
    $monTimer.Add_Tick({
        try {
            $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
            $MonCpu.Text = ("CPU: {0:N1}%%" -f $cpu)
        } catch {}
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $total = $os.TotalVisibleMemorySize
            $free  = $os.FreePhysicalMemory
            $used  = ($total - $free) / $total * 100
            $MonRam.Text = ("RAM: {0:N1}%%" -f $used)
        } catch {}
        try {
            $gpuCounter = '\GPU Engine(*engtype_3D)\Utilization Percentage'
            $val = (Get-Counter $gpuCounter -ErrorAction SilentlyContinue).CounterSamples |
                Select-Object -First 1
            if ($val) { $MonInfo.Text = ("GPU 3D: {0:N1}%%" -f $val.CookedValue) }
        } catch {}
    })

    $CloseBtn.Add_Click({
        $monTimer.Stop()
        $monWindow.Close()
    })

    $monWindow.Add_Closed({
        $monTimer.Stop()
    }) | Out-Null

    # >>> OVO JE BILO PROBLEM – TIMER NIKAD NIJE KRENUO <<<
    $monTimer.Start()
    $monWindow.ShowDialog() | Out-Null
})

# -------- BENCHMARK OVERLAY (FIX: dodato benchTimer.Start) ----------
$BenchmarkButton.Add_Click({
    $benchXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Savke Benchmark" Height="160" Width="260"
        Background="#050518" ResizeMode="NoResize"
        Topmost="True" WindowStartupLocation="CenterScreen">
  <StackPanel Margin="10">
    <TextBlock Text="Live benchmark (CPU/RAM)" Foreground="White" Margin="0,0,0,8"/>
    <TextBlock x:Name="BenchCpu" Text="CPU: ..." Foreground="#CCCCCC" Margin="0,0,0,4"/>
    <TextBlock x:Name="BenchRam" Text="RAM: ..." Foreground="#CCCCCC" Margin="0,0,0,4"/>
    <Button x:Name="BenchClose" Content="Close" Width="70" Height="24" HorizontalAlignment="Center" Margin="0,8,0,0"/>
  </StackPanel>
</Window>
"@
    $rr = New-Object System.Xml.XmlNodeReader ([xml]$benchXaml)
    $benchWindow = [System.Windows.Markup.XamlReader]::Load($rr)
    $BenchCpu   = $benchWindow.FindName("BenchCpu")
    $BenchRam   = $benchWindow.FindName("BenchRam")
    $BenchClose = $benchWindow.FindName("BenchClose")

    $benchTimer = New-Object System.Windows.Threading.DispatcherTimer
    $benchTimer.Interval = [System.TimeSpan]::FromSeconds(1)
    $benchTimer.Add_Tick({
        try {
            $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
            $os = Get-CimInstance Win32_OperatingSystem
            $total = $os.TotalVisibleMemorySize
            $free  = $os.FreePhysicalMemory
            $used  = ($total - $free) / $total * 100

            $BenchCpu.Text = ("CPU: {0:N1}%%" -f $cpu)
            $BenchRam.Text = ("RAM: {0:N1}%%" -f $used)
        } catch {}
    })

    $BenchClose.Add_Click({
        $benchTimer.Stop()
        $benchWindow.Close()
    })

    $benchWindow.Add_Closed({
        $benchTimer.Stop()
    }) | Out-Null

    $benchTimer.Start()
    Add-Log $LogBox "Benchmark overlay start..."
    $benchWindow.ShowDialog() | Out-Null
    Add-Log $LogBox "Benchmark overlay closed."
})

# =========================
#  WINDOW CLOSING CLEANUP
# =========================
$window.Add_Closed({
    $statusTimer.Stop()
    $HudTimer.Stop()
    if ($script:fadeTimer) { $script:fadeTimer.Stop() }
})

# =========================
#  RUN APP
# =========================
$window.ShowDialog() | Out-Null
