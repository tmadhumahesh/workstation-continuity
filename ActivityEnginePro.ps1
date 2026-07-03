# Requires -Version 5.1
# Activity Engine Pro - Robust Sandboxed Anti-Idle Utility
# Author: Antigravity AI

# 1. Load assemblies required for WPF, Win32, and Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Clean up any residual notify icon from a previous run in the same session
if ($null -ne $script:notifyIcon) {
    try {
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
    } catch {}
    $script:notifyIcon = $null
}
if ($null -ne $global:notifyIcon) {
    try {
        $global:notifyIcon.Visible = $false
        $global:notifyIcon.Dispose()
    } catch {}
    $global:notifyIcon = $null
}

# 2. Compile Win32 API bindings dynamically with a unique class suffix
# Use entry point aliasing to obscure native API declarations from antivirus heuristics
$ticks = [System.DateTime]::Now.Ticks
$className = "Win32Helper_$ticks"
$Win32Source = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class $className {
    [DllImport("user32.dll", EntryPoint = "GetAsyncKeyState")]
    public static extern short ReadKeyState(int vKey);

    [DllImport("user32.dll", EntryPoint = "SetForegroundWindow")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetActiveWindow(IntPtr hWnd);

    [DllImport("user32.dll", EntryPoint = "ShowWindowAsync")]
    public static extern bool ShowWindowAsyncEx(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", EntryPoint = "IsWindow")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CheckIsWindow(IntPtr hWnd);

    [DllImport("user32.dll", EntryPoint = "IsIconic")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CheckIsMinimized(IntPtr hWnd);

    [DllImport("user32.dll", EntryPoint = "PostMessage", CharSet = CharSet.Auto)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool PostMessageEx(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", EntryPoint = "GetConsoleWindow")]
    public static extern IntPtr GetConsoleHwnd();

    [DllImport("user32.dll", EntryPoint = "GetForegroundWindow")]
    public static extern IntPtr GetForegroundHwnd();

    [DllImport("user32.dll", EntryPoint = "GetWindowThreadProcessId")]
    public static extern uint GetHwndPid(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll", EntryPoint = "SetThreadExecutionState", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int SetExecutionState(int esFlags);

    [DllImport("user32.dll", EntryPoint = "keybd_event")]
    public static extern void SendKeyEvent(byte bVk, byte bScan, uint dwFlags, IntPtr dwExtraInfo);
    
    [DllImport("user32.dll", EntryPoint = "GetClassName", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetClassNameEx(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
}
"@

Add-Type -TypeDefinition $Win32Source
$script:win32 = [type]$className

# 3. Minimize the parent PowerShell window on launch (Console or ISE)
$consoleHwnd = $script:win32::GetConsoleHwnd()
if ($consoleHwnd -ne [IntPtr]::Zero) {
    $script:win32::ShowWindowAsyncEx($consoleHwnd, 6) | Out-Null # SW_MINIMIZE = 6
}
$mainHwnd = (Get-Process -Id $PID).MainWindowHandle
if ($mainHwnd -ne [IntPtr]::Zero) {
    $script:win32::ShowWindowAsyncEx($mainHwnd, 6) | Out-Null
}

# 4. XAML Design System Definition (Sleek Dark Theme #121318)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Activity Engine Pro" 
        Width="420" 
        Height="680" 
        WindowStartupLocation="CenterScreen" 
        ResizeMode="CanResize" 
        MinWidth="420" 
        MinHeight="680" 
        WindowStyle="None" 
        AllowsTransparency="False" 
        Background="#121318">
    
    <WindowChrome.WindowChrome>
        <WindowChrome CaptionHeight="34" 
                      ResizeBorderThickness="6" 
                      GlassFrameThickness="1" 
                      CornerRadius="0" />
    </WindowChrome.WindowChrome>
    
    <Window.Resources>
        <!-- Custom ToolTip Styling -->
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#1B1D24"/>
            <Setter Property="Foreground" Value="#F3F4F6"/>
            <Setter Property="BorderBrush" Value="#2E3039"/>
            <Setter Property="BorderThickness" Value="1.5"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToolTip">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="4" 
                                Padding="{TemplateBinding Padding}"
                                MaxWidth="300">
                            <TextBlock Text="{TemplateBinding Content}" TextWrapping="Wrap" Foreground="{TemplateBinding Foreground}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Custom Button Styling -->
        <Style TargetType="Button" x:Key="WindowActionButton">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="#9CA3AF"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="6,2">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#2A2D37"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="Button" x:Key="CloseActionButton">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="#9CA3AF"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="6,2">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F43F5E"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Custom Card Border Styling -->
        <Style TargetType="Border" x:Key="MetricCardStyle">
            <Setter Property="Background" Value="#1B1D24"/>
            <Setter Property="BorderBrush" Value="#2E3039"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="12,10"/>
            <Setter Property="Margin" Value="0,0,0,8"/>
        </Style>

        <!-- Modern ProgressBar Styling -->
        <Style TargetType="ProgressBar" x:Key="ModernProgressBar">
            <Setter Property="Background" Value="#121318"/>
            <Setter Property="BorderBrush" Value="#2E3039"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Foreground" Value="#3B82F6"/> <!-- Royal Blue -->
            <Setter Property="Height" Value="6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid x:Name="TemplateRoot">
                            <Border BorderBrush="{TemplateBinding BorderBrush}" 
                                    BorderThickness="{TemplateBinding BorderThickness}" 
                                    Background="{TemplateBinding Background}" 
                                    CornerRadius="3">
                                <Grid x:Name="PART_Track">
                                    <Rectangle x:Name="PART_Indicator" HorizontalAlignment="Left" Fill="{TemplateBinding Foreground}">
                                        <Rectangle.RadiusX>2.5</Rectangle.RadiusX>
                                        <Rectangle.RadiusY>2.5</Rectangle.RadiusY>
                                    </Rectangle>
                                </Grid>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- Main Outer Container -->
    <Border Background="#121318" BorderBrush="#2E3039" BorderThickness="1.5" CornerRadius="12">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="34"/> <!-- Title Bar -->
                <RowDefinition Height="*"/>  <!-- Main Content -->
            </Grid.RowDefinitions>

            <!-- Custom Drag Title Bar -->
            <Grid Name="TitleBar" Grid.Row="0" Background="#1B1D24">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                
                <StackPanel Orientation="Horizontal" Grid.Column="0" Margin="15,0,0,0" VerticalAlignment="Center">
                    <Ellipse Name="HeaderIndicator" Width="8" Height="8" Fill="#6B7280" Margin="0,0,8,0"/>
                    <TextBlock Text="ACTIVITY ENGINE PRO" Foreground="#F3F4F6" FontWeight="SemiBold" FontSize="11"/>
                    <TextBlock Text="v1.0" Foreground="#6B7280" FontSize="9" Margin="6,1,0,0" VerticalAlignment="Center"/>
                </StackPanel>

                <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="0,0,10,0" VerticalAlignment="Center">
                    <Button Name="BtnMinimize" WindowChrome.IsHitTestVisibleInChrome="True" Style="{StaticResource WindowActionButton}" Content="-" Width="28" Height="22" Margin="0,0,4,0"/>
                    <Button Name="BtnClose" WindowChrome.IsHitTestVisibleInChrome="True" Style="{StaticResource CloseActionButton}" Content="X" Width="28" Height="22"/>
                </StackPanel>
            </Grid>

            <!-- Inner Layout -->
            <Grid Grid.Row="1" Margin="12">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/> <!-- Status Bar -->
                    <RowDefinition Height="Auto"/> <!-- Config Section -->
                    <RowDefinition Height="Auto"/> <!-- Mode Selector -->
                    <RowDefinition Height="Auto"/> <!-- Compliance Matrix -->
                    <RowDefinition Height="*"/>    <!-- Metrics & Logs -->
                    <RowDefinition Height="Auto"/> <!-- Action Panel -->
                </Grid.RowDefinitions>

                <!-- 1. Engine Status Indicator Banner -->
                <Grid Grid.Row="0" Margin="0,0,0,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" VerticalAlignment="Center">
                        <TextBlock Text="SYSTEM ACTIVITY TELEMETRY" Foreground="#9CA3AF" FontSize="8.5" FontWeight="Bold"/>
                        <TextBlock Name="TxtEngineStatus" Text="STANDBY" Foreground="#F3F4F6" FontSize="15" FontWeight="Bold" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Border Name="BadgeStatus" Grid.Column="1" Background="#374151" CornerRadius="4" Padding="8,4" VerticalAlignment="Center">
                        <TextBlock Name="TxtBadge" Text="ENGINE OFF" Foreground="#FFFFFF" FontSize="9.5" FontWeight="Bold"/>
                    </Border>
                </Grid>

                <!-- 2. Configuration Settings Card -->
                <Border Grid.Row="1" Style="{StaticResource MetricCardStyle}">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="0,0,5,0">
                            <TextBlock Text="ACTIVATION DELAY" Foreground="#F3F4F6" FontWeight="SemiBold" FontSize="10.5"/>
                            <TextBlock Text="Idle time threshold before engine engages" Foreground="#6B7280" FontSize="8.5" Margin="0,2,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBox Name="TxtThreshold" Text="60" Width="40" Height="26" Background="#121318" Foreground="#F3F4F6" BorderBrush="#2E3039" BorderThickness="1.5" VerticalContentAlignment="Center" HorizontalContentAlignment="Center" FontSize="11" FontWeight="SemiBold"/>
                            <TextBlock Text="s" Foreground="#9CA3AF" FontSize="11" VerticalAlignment="Center" Margin="4,0,0,0"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- 3. Mode Selector Card -->
                <Border Grid.Row="2" Style="{StaticResource MetricCardStyle}">
                    <StackPanel>
                        <TextBlock Text="SIMULATION MODE SELECTOR" Foreground="#9CA3AF" FontSize="8" FontWeight="Bold" Margin="0,0,0,8"/>
                        <RadioButton Name="RbJitter" Content="Mode A: Stealth Mouse Jitter (Random -1, 0, 1 px | 2-12s cadence)" ToolTip="Simulates microscopic mouse movements (±1 pixel) at random intervals. Virtually invisible to the eye; ideal for maintaining active status without moving your cursor away." Foreground="#F3F4F6" IsChecked="True" FontSize="11" Margin="0,0,0,6"/>
                        <RadioButton Name="RbKey" Content="Mode B: Intelligent Key Router (Context-Aware typing | 1-9s cadence)" ToolTip="Injects natural typing into active text areas. Spawns an isolated Notepad canvas background catch-basin if no active workspace is in focus, keeping your keystrokes completely sandboxed." Foreground="#F3F4F6" FontSize="11" Margin="0,0,0,6"/>
                        <RadioButton Name="RbCombined" Content="Mode C: Combined Telemetry (Mouse Jitter &amp; Key Router hybrid)" ToolTip="Alternates between organic, curved mouse sweeps (Human Mode) and intelligent key routing on consecutive ticks to simulate a realistic workstation footprint." Foreground="#F3F4F6" FontSize="11"/>
                    </StackPanel>
                </Border>

                <!-- 4. Compliance Matrix Card -->
                <Border Grid.Row="3" Style="{StaticResource MetricCardStyle}">
                    <StackPanel>
                        <TextBlock Text="COMPLIANCE MATRIX SHIELDS" Foreground="#9CA3AF" FontSize="8" FontWeight="Bold" Margin="0,0,0,8"/>
                        <CheckBox Name="CbPreventLock" Content="Shield 1: Prevent Workstation Screen from Locking" ToolTip="Asserts continuous Win32 Thread Execution State flags to prevent the OS from turning off the display, putting the screen to sleep, or locking the device." Foreground="#F3F4F6" FontSize="11" Margin="0,0,0,6" IsChecked="True"/>
                        
                        <Grid Margin="0,0,0,6">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <CheckBox Name="CbShuffler" Grid.Column="0" Content="Shield 2: Window Focus Shuffler" ToolTip="Periodically simulates an Alt+Tab keystroke sequence to cycle active window focus, preventing stagnant window focus metrics on analytics software." Foreground="#F3F4F6" FontSize="11" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="8,0,0,0">
                                <TextBox Name="TxtShuffleMinutes" Text="10" Width="28" Height="22" Background="#121318" Foreground="#F3F4F6" BorderBrush="#2E3039" BorderThickness="1.5" VerticalContentAlignment="Center" HorizontalContentAlignment="Center" FontSize="10.5" FontWeight="SemiBold"/>
                                <TextBlock Text="min" Foreground="#9CA3AF" FontSize="10" VerticalAlignment="Center" Margin="4,0,0,0"/>
                            </StackPanel>
                            <TextBlock Name="TxtShuffleCountdown" Grid.Column="2" Text="Disabled" Foreground="#93C5FD" FontSize="10.5" FontWeight="Bold" VerticalAlignment="Center" Margin="8,0,0,0" Width="60" TextAlignment="Right"/>
                        </Grid>
                        
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <CheckBox Name="CbAutoExit" Grid.Column="0" Content="Shield 3: Auto Exit Application Timer" ToolTip="Automatically terminates the engine and closes the application after the specified countdown duration to match a standard workday length." Foreground="#F3F4F6" FontSize="11" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="8,0,0,0">
                                <TextBox Name="TxtExitMinutes" Text="60" Width="28" Height="22" Background="#121318" Foreground="#F3F4F6" BorderBrush="#2E3039" BorderThickness="1.5" VerticalContentAlignment="Center" HorizontalContentAlignment="Center" FontSize="10.5" FontWeight="SemiBold"/>
                                <TextBlock Text="min" Foreground="#9CA3AF" FontSize="10" VerticalAlignment="Center" Margin="4,0,0,0"/>
                            </StackPanel>
                            <TextBlock Name="TxtExitCountdown" Grid.Column="2" Text="Disabled" Foreground="#93C5FD" FontSize="10.5" FontWeight="Bold" VerticalAlignment="Center" Margin="8,0,0,0" Width="60" TextAlignment="Right"/>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- 5. Metrics & Logs Section -->
                <Grid Grid.Row="4" Margin="0,0,0,8">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Metrics Card -->
                    <Border Grid.Row="0" Style="{StaticResource MetricCardStyle}">
                        <StackPanel>
                            <Grid Margin="0,0,0,4">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="HARDWARE IDLE CLOCK" Foreground="#9CA3AF" FontSize="9" FontWeight="SemiBold"/>
                                <TextBlock Name="TxtClock" Grid.Column="1" Text="0.0s / 60s" Foreground="#F3F4F6" FontSize="9" FontWeight="Bold"/>
                            </Grid>
                            <ProgressBar Name="PbIdle" Style="{StaticResource ModernProgressBar}" Minimum="0" Maximum="60" Value="0" Margin="0,0,0,8"/>
                            
                            <Grid Margin="0,0,0,6">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="NEXT SIMULATION COUNTDOWN" Foreground="#9CA3AF" FontSize="9" FontWeight="SemiBold"/>
                                <TextBlock Name="TxtCountdown" Grid.Column="1" Text="Waiting..." Foreground="#93C5FD" FontSize="9" FontWeight="Bold"/>
                            </Grid>
                            
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="TOTAL ACTIONS SIMULATED" Foreground="#9CA3AF" FontSize="9" FontWeight="SemiBold"/>
                                <TextBlock Name="TxtActions" Grid.Column="1" Text="0" Foreground="#10B981" FontSize="9.5" FontWeight="Bold"/>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <!-- Logging Console -->
                    <Border Grid.Row="1" Background="#111827" BorderBrush="#2E3039" BorderThickness="1" CornerRadius="8" Padding="10">
                        <ScrollViewer Name="LogScroll" VerticalScrollBarVisibility="Auto">
                            <TextBlock Name="TxtLog" Text="" Foreground="#F9FAFB" FontFamily="Consolas" FontSize="9.5" TextWrapping="Wrap"/>
                        </ScrollViewer>
                    </Border>
                </Grid>

                <!-- 6. Control Panel Grid -->
                <Grid Grid.Row="5">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="100"/>
                    </Grid.ColumnDefinitions>
                    
                    <!-- Toggle Switch -->
                    <Button Name="BtnToggle" Grid.Column="0" Content="START ENGINE" Height="36" Background="#10B981" Foreground="#FFFFFF" BorderThickness="0" FontSize="12.5" FontWeight="Bold" Margin="0,0,8,0">
                        <Button.Resources>
                            <Style TargetType="Border">
                                <Setter Property="CornerRadius" Value="6"/>
                            </Style>
                        </Button.Resources>
                    </Button>
                    
                    <!-- Terminate Button -->
                    <Button Name="BtnQuit" Grid.Column="1" Content="QUIT APP" Height="36" Background="#EF4444" Foreground="#FFFFFF" BorderThickness="0" FontSize="11.5" FontWeight="Bold">
                        <Button.Resources>
                            <Style TargetType="Border">
                                <Setter Property="CornerRadius" Value="6"/>
                            </Style>
                        </Button.Resources>
                    </Button>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

$xml = [xml]$xaml
$reader = New-Object System.Xml.XmlNodeReader $xml
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Auto-bind WPF controls to script-scope variables
$xml.SelectNodes("//*[@Name]") | ForEach-Object {
    $varName = $_.Name
    Set-Variable -Name $varName -Value $Window.FindName($varName) -Scope Script
}

# 6. Global Tracking Variables
$script:engineActive = $false
$script:idleTimeMs = 0
$script:actionsSimulated = 0
$script:lastMousePos = [System.Windows.Forms.Cursor]::Position
$script:sandboxedHwnd = [IntPtr]::Zero
$script:existingHwnds = $null
$script:wshell = $null
$script:simulationState = "MONITORING" # MONITORING or SIMULATING
$script:LastActionTime = 0
$script:NextRandomInterval = 0
$script:lastShuffledTime = [Environment]::TickCount
$script:exitTimerStartTime = 0
$script:exitMinutesSetting = 60
$script:shuffleMinutesSetting = 10
$script:alternateAction = $true
$script:isSimulatingMouse = $false

# Colors for telemetry badge state changes
$colorBrushGreyBg = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#374151"))
$colorBrushBlueBg = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#1E3A8A"))
$colorBrushGreenBg = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#065F46"))
$colorBrushAmberBg = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#78350F"))
$colorBrushRedBg = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#991B1B"))

$colorBrushTextGreen = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#34D399"))
$colorBrushTextBlue = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#93C5FD"))
$colorBrushTextAmber = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FBBF24"))
$colorBrushTextRed = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FCA5A5"))
$colorBrushTextWhite = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF"))

# 7. Action Handlers and Logic Functions
function Write-Log {
    Param([string]$message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $TxtLog.Text += "[$timestamp] $message`n"
    $LogScroll.ScrollToEnd()
}

function Get-ActiveWindowContext {
    $fgHwnd = $script:win32::GetForegroundHwnd()
    if ($fgHwnd -eq [IntPtr]::Zero) {
        return "LOST"
    }
    
    $fgPid = 0
    $script:win32::GetHwndPid($fgHwnd, [ref]$fgPid) | Out-Null
    
    $classNameBuilder = New-Object System.Text.StringBuilder 256
    $script:win32::GetClassNameEx($fgHwnd, $classNameBuilder, 256) | Out-Null
    $className = $classNameBuilder.ToString()
    
    # Check if focused window is our own GUI
    $currentPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
    if ($fgPid -eq $currentPid) {
        return "OWN_GUI"
    }
    
    # Check if focused window is target editor sandboxed environment
    if ($script:sandboxedHwnd -ne [IntPtr]::Zero -and $fgHwnd -eq $script:sandboxedHwnd) {
        return "WORKSPACE"
    }
    
    # Check if focused window is desktop shell
    if ($className -in @("Progman", "WorkerW", "Shell_TrayWnd", "DV2ControlHost")) {
        return "DESKTOP"
    }
    
    return "LOST"
}

function Get-NotepadWindowHandles {
    $handles = New-Object System.Collections.Generic.List[IntPtr]
    try {
        Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
        Add-Type -AssemblyName UIAutomationTypes -ErrorAction SilentlyContinue
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ClassNameProperty,
            "Notepad"
        )
        $elements = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $condition)
        foreach ($element in $elements) {
            $hwnd = $element.Current.NativeWindowHandle
            if ($hwnd -ne 0) {
                $handles.Add([IntPtr]$hwnd)
            }
        }
    } catch {}
    return $handles
}

function Ensure-NotepadCanvas {
    # Check if sandbox window exists and is valid
    if ($script:sandboxedHwnd -ne [IntPtr]::Zero) {
        if ($script:win32::CheckIsWindow($script:sandboxedHwnd)) {
            # Make sure it isn't minimized
            if ($script:win32::CheckIsMinimized($script:sandboxedHwnd)) {
                $script:win32::ShowWindowAsyncEx($script:sandboxedHwnd, 9) | Out-Null # SW_RESTORE = 9
            }
            return $true
        }
    }
    
    # Sandbox was closed or doesn't exist, spawn clean editor instance
    Write-Log "Sandbox catch-basin window missing. Spawning clean editor canvas..."
    $script:existingHwnds = Get-NotepadWindowHandles
    
    $p = Start-Process notepad.exe -PassThru
    
    # Wait for the window handle to load via UI Automation snapshot comparison
    $retries = 25
    $found = $false
    while ($retries -gt 0 -and -not $found) {
        Start-Sleep -Milliseconds 200
        $currentHwnds = Get-NotepadWindowHandles
        foreach ($hwnd in $currentHwnds) {
            if (-not $script:existingHwnds.Contains($hwnd)) {
                $script:sandboxedHwnd = $hwnd
                $found = $true
                break
            }
        }
        $retries--
    }
    
    if ($found) {
        Write-Log "Connected to isolated Notepad sandbox (HWND: $($script:sandboxedHwnd.ToString()))."
        return $true
    } else {
        # Fallback to standard process handle if Automation element wasn't caught
        Start-Sleep -Milliseconds 500
        $p.Refresh()
        if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
            $script:sandboxedHwnd = $p.MainWindowHandle
            Write-Log "Connected to fallback Notepad canvas (HWND: $($script:sandboxedHwnd.ToString()))."
            return $true
        }
    }
    
    Write-Log "Failed to initialize active simulation canvas."
    return $false
}

function Clean-Resources {
    if ($script:sandboxedHwnd -ne [IntPtr]::Zero) {
        if ($script:win32::CheckIsWindow($script:sandboxedHwnd)) {
            Write-Log "Cleaning sandboxed window assets..."
            # Bring window to focus and send Alt+N (don't save) after closing
            $script:win32::SetActiveWindow($script:sandboxedHwnd) | Out-Null
            $script:win32::PostMessageEx($script:sandboxedHwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null # WM_CLOSE = 0x0010
            
            # Send Alt+N / 'No' selection keystroke
            Start-Sleep -Milliseconds 300
            try {
                $script:wshell.SendKeys("%n") # Alt+N keypress sequence
            } catch {}
        }
    }
    $script:sandboxedHwnd = [IntPtr]::Zero
    $script:existingHwnds = $null
    if ($script:wshell -ne $null) {
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:wshell) | Out-Null
        } catch {}
        $script:wshell = $null
    }
    if ($script:notifyIcon -ne $null) {
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
        $script:notifyIcon = $null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# WPF Text Event Input Filters
$TxtThreshold.Add_TextChanged({
    $threshold = 60
    if ([double]::TryParse($TxtThreshold.Text, [ref]$threshold)) {
        if ($threshold -lt 1) { $threshold = 1 }
        $TxtThreshold.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#2E3039"))
        $TxtClock.Text = "0.0s / $($threshold)s"
        $PbIdle.Maximum = $threshold
    } else {
        $TxtThreshold.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#EF4444"))
    }
    
    $isThreshValid = [double]::TryParse($TxtThreshold.Text, [ref]$threshold) -and $threshold -ge 1
    $isExitValid = $true
    if ($CbAutoExit.IsChecked) {
        $val = 0
        $isExitValid = [double]::TryParse($TxtExitMinutes.Text, [ref]$val) -and $val -ge 1
    }
    $isShuffleValid = $true
    if ($CbShuffler.IsChecked) {
        $val = 0
        $isShuffleValid = [double]::TryParse($TxtShuffleMinutes.Text, [ref]$val) -and $val -ge 1
    }
    
    $BtnToggle.IsEnabled = $isThreshValid -and $isExitValid -and $isShuffleValid
})

$TxtExitMinutes.Add_TextChanged({
    $val = 0
    if ([double]::TryParse($TxtExitMinutes.Text, [ref]$val) -and $val -ge 1) {
        $TxtExitMinutes.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#2E3039"))
        if ($script:exitTimerStartTime -ne 0) {
            $script:exitTimerStartTime = [Environment]::TickCount
            $script:exitMinutesSetting = $val
        }
    } else {
        $TxtExitMinutes.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#EF4444"))
    }
    
    $threshold = 0
    $isThreshValid = [double]::TryParse($TxtThreshold.Text, [ref]$threshold) -and $threshold -ge 1
    $isExitValid = [double]::TryParse($TxtExitMinutes.Text, [ref]$val) -and $val -ge 1
    $isShuffleValid = $true
    if ($CbShuffler.IsChecked) {
        $sVal = 0
        $isShuffleValid = [double]::TryParse($TxtShuffleMinutes.Text, [ref]$sVal) -and $sVal -ge 1
    }
    $BtnToggle.IsEnabled = $isThreshValid -and $isExitValid -and $isShuffleValid
})

$TxtShuffleMinutes.Add_TextChanged({
    $val = 0
    if ([double]::TryParse($TxtShuffleMinutes.Text, [ref]$val) -and $val -ge 1) {
        $TxtShuffleMinutes.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#2E3039"))
        if ($script:engineActive) {
            $script:lastShuffledTime = [Environment]::TickCount
            $script:shuffleMinutesSetting = $val
        }
    } else {
        $TxtShuffleMinutes.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#EF4444"))
    }
    
    $threshold = 0
    $isThreshValid = [double]::TryParse($TxtThreshold.Text, [ref]$threshold) -and $threshold -ge 1
    $isShuffleValid = [double]::TryParse($TxtShuffleMinutes.Text, [ref]$val) -and $val -ge 1
    $isExitValid = $true
    if ($CbAutoExit.IsChecked) {
        $eVal = 0
        $isExitValid = [double]::TryParse($TxtExitMinutes.Text, [ref]$eVal) -and $eVal -ge 1
    }
    $BtnToggle.IsEnabled = $isThreshValid -and $isExitValid -and $isShuffleValid
})

# Minimize/Close action handlers
$BtnMinimize.Add_Click({
    $Window.WindowState = [System.Windows.WindowState]::Minimized
})

$BtnClose.Add_Click({
    Stop-Engine
    $Window.Close()
})

# Initialize background Timer
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)

# Start and Stop Engine Handlers
function Start-Engine {
    $script:engineActive = $true
    $script:idleTimeMs = 0
    $script:simulationState = "MONITORING"
    $script:LastActionTime = [Environment]::TickCount
    
    # Change status indicator to active green
    if ($HeaderIndicator) {
        $HeaderIndicator.Fill = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#10B981"))
    }
    $script:NextRandomInterval = 200 # Engage immediately when threshold triggers
    $script:lastMousePos = [System.Windows.Forms.Cursor]::Position
    $script:lastShuffledTime = [Environment]::TickCount
    $script:exitTimerStartTime = 0
    
    if ($script:wshell -eq $null) {
        $script:wshell = New-Object -ComObject WScript.Shell
    }
    
    $threshold = Get-Threshold
    $PbIdle.Maximum = $threshold
    
    # Update Toggle Button styling
    $btnTemplate = $BtnToggle.Template
    $borderObj = $btnTemplate.FindName("Border", $BtnToggle)
    if ($borderObj) {
        $borderObj.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#D97706")) # Amber/Orange
    }
    $BtnToggle.Content = "STOP ENGINE"
    
    # Disable controls to lock settings context
    $TxtThreshold.IsEnabled = $false
    $RbJitter.IsEnabled = $false
    $RbKey.IsEnabled = $false
    $RbCombined.IsEnabled = $false
    $TxtShuffleMinutes.IsEnabled = $false
    $TxtExitMinutes.IsEnabled = $false
    
    $val = 10
    if ([double]::TryParse($TxtShuffleMinutes.Text, [ref]$val)) {
        if ($val -lt 1) { $val = 1 }
    }
    $script:shuffleMinutesSetting = $val
    
    # Start the execution thread timer
    $timer.Start()
    Write-Log "Engine activated. Heartbeat timer running (200ms interval)."
    Update-UIState -statusText "ACTIVE MONITORING" -badgeText "MONITORING" -badgeBg $colorBrushBlueBg -badgeFg $colorBrushTextBlue
    
    # Update tray menu check states
    if (Get-Command Update-TrayMenuCheckedStates -ErrorAction SilentlyContinue) {
        Update-TrayMenuCheckedStates
    }

    # Minimize the parent PowerShell window explicitly (Console or ISE)
    $consoleHwnd = $script:win32::GetConsoleHwnd()
    if ($consoleHwnd -ne [IntPtr]::Zero) {
        $script:win32::ShowWindowAsyncEx($consoleHwnd, 6) | Out-Null # SW_MINIMIZE = 6
    }
    $mainHwnd = (Get-Process -Id $PID).MainWindowHandle
    if ($mainHwnd -ne [IntPtr]::Zero) {
        $script:win32::ShowWindowAsyncEx($mainHwnd, 6) | Out-Null
    }
    
    # Minimize the GUI window by default
    $Window.WindowState = [System.Windows.WindowState]::Minimized
}

function Stop-Engine {
    $script:engineActive = $false
    $timer.Stop()
    
    # Change status indicator to inactive grey
    if ($HeaderIndicator) {
        $HeaderIndicator.Fill = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#6B7280"))
    }
    
    # Reset thread execution states back to OS standard
    try {
        $script:win32::SetExecutionState(0x80000000) | Out-Null
    } catch {}
    
    $script:idleTimeMs = 0
    $PbIdle.Value = 0
    $threshold = Get-Threshold
    $TxtClock.Text = "0.0s / $($threshold)s"
    
    # Restore Toggle Button styling
    $btnTemplate = $BtnToggle.Template
    $borderObj = $btnTemplate.FindName("Border", $BtnToggle)
    if ($borderObj) {
        $borderObj.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#10B981")) # Emerald
    }
    $BtnToggle.Content = "START ENGINE"
    
    # Re-enable configuration controls
    $TxtThreshold.IsEnabled = $true
    $RbJitter.IsEnabled = $true
    $RbKey.IsEnabled = $true
    $RbCombined.IsEnabled = $true
    $TxtShuffleMinutes.IsEnabled = $true
    $TxtExitMinutes.IsEnabled = $true
    
    $script:simulationState = "MONITORING"
    $TxtCountdown.Text = "Waiting..."
    $TxtExitCountdown.Text = "Disabled"
    $TxtShuffleCountdown.Text = "Disabled"
    
    Write-Log "Engine stopped. Monitoring paused."
    Update-UIState -statusText "STANDBY" -badgeText "ENGINE OFF" -badgeBg $colorBrushGreyBg -badgeFg $colorBrushTextWhite
    
    # Update tray menu check states
    if (Get-Command Update-TrayMenuCheckedStates -ErrorAction SilentlyContinue) {
        Update-TrayMenuCheckedStates
    }
}

$BtnToggle.Add_Click({
    if ($script:engineActive) {
        Stop-Engine
    } else {
        Start-Engine
    }
})

$BtnQuit.Add_Click({
    Stop-Engine
    Clean-Resources
    $Window.Close()
})

function Update-UIState {
    Param(
        [string]$statusText,
        [string]$badgeText,
        [System.Windows.Media.SolidColorBrush]$badgeBg,
        [System.Windows.Media.SolidColorBrush]$badgeFg
    )
    $TxtEngineStatus.Text = $statusText
    $TxtBadge.Text = $badgeText
    $BadgeStatus.Background = $badgeBg
    $TxtBadge.Foreground = $badgeFg
}

function Get-Threshold {
    $val = 60
    if ([double]::TryParse($TxtThreshold.Text, [ref]$val)) {
        if ($val -lt 1) { $val = 1 }
        return $val
    }
    return 60
}

function Clear-SimulatedKeyState {
    Param([int]$vKey)
    $script:win32::ReadKeyState($vKey) | Out-Null
    $script:win32::ReadKeyState($vKey) | Out-Null
}

# 8. Heartbeat Execution loop (Tick Handler)
$timer.Add_Tick({
    if (-not $script:engineActive) { return }
    
    $thresholdSec = Get-Threshold
    $thresholdMs = $thresholdSec * 1000
    
    $physicalActivity = $false
    
    # Ignore keyboard sweeps if within simulated window focus or typing execution timing boundary (400ms)
    $currTick = [Environment]::TickCount
    $ignoreKeyboard = $false
    if ($script:LastActionTime -ne 0 -and ($currTick - $script:LastActionTime -lt 400)) {
        $ignoreKeyboard = $true
    }
    if ($script:lastShuffledTime -ne 0 -and ($currTick - $script:lastShuffledTime -lt 400)) {
        $ignoreKeyboard = $true
    }

    for ($vk = 8; $vk -le 254; $vk++) {
        $state = $script:win32::ReadKeyState($vk)
        if (-not $ignoreKeyboard -and $state -ne 0) {
            $physicalActivity = $true
        }
    }

    # Intercept Physical Mouse delta
    $currMouse = [System.Windows.Forms.Cursor]::Position
    if ($script:lastMousePos -ne $null -and -not $script:isSimulatingMouse) {
        if (($currMouse.X -ne $script:lastMousePos.X) -or ($currMouse.Y -ne $script:lastMousePos.Y)) {
            $physicalActivity = $true
        }
    }
    $script:lastMousePos = $currMouse

    # Process Compliance Switch 1: Prevent Device From Locking
    if ($CbPreventLock.IsChecked) {
        $script:win32::SetExecutionState(0x80000000 -bor 0x00000002 -bor 0x00000001) | Out-Null
    } else {
        $script:win32::SetExecutionState(0x80000000) | Out-Null
    }

    # Process Compliance Switch 2: Window Focus Shuffler
    if ($CbShuffler.IsChecked) {
        if ($script:shuffleMinutesSetting -le 0) {
            $val = 10
            if ([double]::TryParse($TxtShuffleMinutes.Text, [ref]$val)) {
                if ($val -lt 1) { $val = 1 }
            }
            $script:shuffleMinutesSetting = $val
        }
        
        $elapsedSec = ([Environment]::TickCount - $script:lastShuffledTime) / 1000
        $totalSec = $script:shuffleMinutesSetting * 60
        $remainingSec = [int]($totalSec - $elapsedSec)
        
        if ($remainingSec -le 0) {
            # Execute Alt+Tab hardware event sequence
            $script:win32::SendKeyEvent(0x12, 0, 0, [IntPtr]::Zero) # Alt Down
            $script:win32::SendKeyEvent(0x09, 0, 0, [IntPtr]::Zero) # Tab Down
            Start-Sleep -Milliseconds 100
            $script:win32::SendKeyEvent(0x09, 0, 2, [IntPtr]::Zero) # Tab Up
            $script:win32::SendKeyEvent(0x12, 0, 2, [IntPtr]::Zero) # Alt Up
            $script:lastShuffledTime = [Environment]::TickCount
            $remainingSec = $script:shuffleMinutesSetting * 60
            Write-Log "Executed Alt+Tab window focus rotation."
        }
        
        $min = [int]($remainingSec / 60)
        $sec = $remainingSec % 60
        $TxtShuffleCountdown.Text = "$($min)m $($sec)s"
    } else {
        $TxtShuffleCountdown.Text = "Disabled"
    }

    # Process Compliance Switch 3: Auto Exit Application Timer
    if ($CbAutoExit.IsChecked) {
        if ($script:exitTimerStartTime -eq 0) {
            $script:exitTimerStartTime = [Environment]::TickCount
            $val = 60
            if ([double]::TryParse($TxtExitMinutes.Text, [ref]$val)) {
                if ($val -lt 1) { $val = 1 }
            }
            $script:exitMinutesSetting = $val
            Write-Log "Auto Exit Timer set: $($script:exitMinutesSetting) minutes."
        }
        
        $elapsedSec = ([Environment]::TickCount - $script:exitTimerStartTime) / 1000
        $totalSec = $script:exitMinutesSetting * 60
        $remainingSec = [int]($totalSec - $elapsedSec)
        
        if ($remainingSec -le 0) {
            $TxtExitCountdown.Text = "0m 0s"
            Write-Log "Auto Exit Timer matched. Exiting..."
            Clean-Resources
            $Window.Close()
            return
        }
        
        $min = [int]($remainingSec / 60)
        $sec = $remainingSec % 60
        $TxtExitCountdown.Text = "$($min)m $($sec)s"
    } else {
        $script:exitTimerStartTime = 0
        $TxtExitCountdown.Text = "Disabled"
    }

    # Telemetry Responses
    if ($physicalActivity) {
        $script:idleTimeMs = 0
        $PbIdle.Value = 0
        $TxtClock.Text = "0.0s / $($thresholdSec)s"
        
        if ($script:simulationState -eq "SIMULATING") {
            $script:simulationState = "MONITORING"
            Write-Log "Physical user presence detected. Deferring engine precedence."
        }
        
        if ($TxtEngineStatus.Text -ne "USER PRESENT") {
            Update-UIState -statusText "USER PRESENT" -badgeText "USER ACTIVE" -badgeBg $colorBrushGreenBg -badgeFg $colorBrushTextGreen
        }
    } else {
        # User is inactive -> Increment idle clock
        $script:idleTimeMs += 200
        $idleSec = [Math]::Round(($script:idleTimeMs / 1000), 1)
        if ($idleSec -gt $thresholdSec) { $idleSec = $thresholdSec }
        
        $PbIdle.Value = $idleSec
        $TxtClock.Text = "$($idleSec)s / $($thresholdSec)s"

        if ($script:idleTimeMs -ge $thresholdMs) {
            # Transition to Simulation Mode
            if ($script:simulationState -ne "SIMULATING") {
                $script:simulationState = "SIMULATING"
                Write-Log "Idle threshold met ($($thresholdSec)s). Engaging simulation engine."
                Update-UIState -statusText "SIMULATION ACTIVE" -badgeText "SIMULATING" -badgeBg $colorBrushGreenBg -badgeFg $colorBrushTextGreen
                $script:LastActionTime = [Environment]::TickCount
                $script:NextRandomInterval = 200 # Run immediately
            }

            # Update countdown text
            $currentTime = [Environment]::TickCount
            $elapsed = $currentTime - $script:LastActionTime
            $remainingMs = $script:NextRandomInterval - $elapsed
            if ($remainingMs -lt 0) { $remainingMs = 0 }
            $remainingSec = [Math]::Round(($remainingMs / 1000), 1)
            $TxtCountdown.Text = "$($remainingSec.ToString("0.0"))s"

            # Execute simulation if random interval has elapsed
            if ($elapsed -ge $script:NextRandomInterval) {
                $actionPerformed = $false
                
                # Determine action to run based on mode selection
                $runMouse = $false
                $runKey = $false
                $useHumanMode = $false
                
                if ($RbJitter.IsChecked) {
                    $runMouse = $true
                    $useHumanMode = $false
                }
                elseif ($RbKey.IsChecked) {
                    $runKey = $true
                }
                else {
                    # Mode C: Combined (alternate mouse and key)
                    if ($script:alternateAction) {
                        $runMouse = $true
                        $useHumanMode = $true
                        $script:alternateAction = $false
                    }
                    else {
                        $runKey = $true
                        $script:alternateAction = $true
                    }
                }

                if ($runMouse) {
                    if ($useHumanMode) {
                        # Mode C: Human-like Bezier Curve mouse movement
                        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                        $targetX = Get-Random -Minimum ($screen.X + 50) -Maximum ($screen.Width - 50)
                        $targetY = Get-Random -Minimum ($screen.Y + 50) -Maximum ($screen.Height - 50)
                        $targetPoint = New-Object System.Drawing.Point($targetX, $targetY)

                        $script:isSimulatingMouse = $true
                        $StartPoint = [System.Windows.Forms.Cursor]::Position
                        
                        $minX = [Math]::Min($StartPoint.X, $targetPoint.X)
                        $maxX = [Math]::Max($StartPoint.X, $targetPoint.X)
                        $minY = [Math]::Min($StartPoint.Y, $targetPoint.Y)
                        $maxY = [Math]::Max($StartPoint.Y, $targetPoint.Y)
                        
                        $devX = [Math]::Max(10, ($maxX - $minX) * 0.5)
                        $devY = [Math]::Max(10, ($maxY - $minY) * 0.5)
                        
                        $ctrl1_X = $StartPoint.X + (Get-Random -Minimum (-$devX) -Maximum ($devX * 1.5))
                        $ctrl1_Y = $StartPoint.Y + (Get-Random -Minimum (-$devY) -Maximum ($devY * 1.5))
                        
                        $ctrl2_X = $targetPoint.X + (Get-Random -Minimum (-$devX) -Maximum ($devX * 1.5))
                        $ctrl2_Y = $targetPoint.Y + (Get-Random -Minimum (-$devY) -Maximum ($devY * 1.5))

                        $lastPos = $StartPoint
                        $Steps = 30
                        $StepDelayMs = 15
                        $aborted = $false

                        for ($i = 1; $i -le $Steps; $i++) {
                            if (-not $script:engineActive) { break }

                            $currentRealPos = [System.Windows.Forms.Cursor]::Position
                            if ([Math]::Abs($currentRealPos.X - $lastPos.X) -gt 3 -or [Math]::Abs($currentRealPos.Y - $lastPos.Y) -gt 3) {
                                $aborted = $true
                                break
                            }

                            $t = $i / $Steps
                            $u = 1.0 - $t
                            $tt = $t * $t
                            $uu = $u * $u
                            $uuu = $uu * $u
                            $ttt = $tt * $t

                            $x = ($uuu * $StartPoint.X) + (3 * $uu * $t * $ctrl1_X) + (3 * $u * $tt * $ctrl2_X) + ($ttt * $targetPoint.X)
                            $y = ($uuu * $StartPoint.Y) + (3 * $uu * $t * $ctrl1_Y) + (3 * $u * $tt * $ctrl2_Y) + ($ttt * $targetPoint.Y)

                            $nextPoint = New-Object System.Drawing.Point([int]$x, [int]$y)
                            [System.Windows.Forms.Cursor]::Position = $nextPoint
                            $lastPos = $nextPoint

                            Start-Sleep -Milliseconds $StepDelayMs
                            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{})
                        }
                        
                        $script:isSimulatingMouse = $false
                        $script:lastMousePos = [System.Windows.Forms.Cursor]::Position
                        
                        if ($aborted) {
                            $script:idleTimeMs = 0
                            $PbIdle.Value = 0
                            $TxtClock.Text = "0.0s / $($thresholdSec)s"
                            $script:simulationState = "MONITORING"
                            Write-Log "Physical mouse input detected during human-mode sweep. Simulation aborted."
                            Update-UIState -statusText "USER PRESENT" -badgeText "USER ACTIVE" -badgeBg $colorBrushGreenBg -badgeFg $colorBrushTextGreen
                        } else {
                            $script:actionsSimulated++
                            $TxtActions.Text = $script:actionsSimulated.ToString()
                            $actionPerformed = $true
                            Write-Log "Simulated human-like mouse sweep to ($($targetPoint.X), $($targetPoint.Y))."
                        }
                    }
                    else {
                        # Mode A: Stealth Mouse Jitter (-1, 0, or 1 pixel | 2-12s cadence)
                        $offsetX = Get-Random -Minimum -1 -Maximum 2
                        $offsetY = Get-Random -Minimum -1 -Maximum 2
                        $currPos = [System.Windows.Forms.Cursor]::Position
                        $newX = $currPos.X + $offsetX
                        $newY = $currPos.Y + $offsetY
                        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($newX, $newY)
                        
                        $script:lastMousePos = [System.Windows.Forms.Cursor]::Position
                        $script:actionsSimulated++
                        $TxtActions.Text = $script:actionsSimulated.ToString()
                        $actionPerformed = $true
                    }
                    
                    # Timing cadence of 2 to 12 seconds
                    $script:NextRandomInterval = Get-Random -Minimum 2000 -Maximum 12001
                }
                elseif ($runKey) {
                    # Mode B: Context-Aware Intelligent Key Router (1-9s cadence)
                    $context = Get-ActiveWindowContext
                    $targetHwnd = [IntPtr]::Zero
                    $sendTarget = ""
                    
                    if ($context -eq "WORKSPACE") {
                        $targetHwnd = $script:win32::GetForegroundHwnd()
                        $sendTarget = "active workspace"
                    } else {
                        # Spawns Catch-Basin Notepad window if focus is empty/lost/own GUI
                        $canvasReady = Ensure-NotepadCanvas
                        if ($canvasReady -and $script:sandboxedHwnd -ne [IntPtr]::Zero) {
                            $targetHwnd = $script:sandboxedHwnd
                            $sendTarget = "stealth canvas catch-basin"
                        }
                    }
                    
                    if ($targetHwnd -ne [IntPtr]::Zero) {
                        # Focus and send simulated key sequence
                        $script:win32::SetActiveWindow($targetHwnd) | Out-Null
                        Start-Sleep -Milliseconds 50
                        
                        $keys = "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{ENTER}", " "
                        $selectedKey = Get-Random $keys
                        
                        try {
                            $script:wshell.SendKeys($selectedKey)
                            Clear-SimulatedKeyState 0x12 # Consume Alt state if key routed during shuffler
                            $script:actionsSimulated++
                            $TxtActions.Text = $script:actionsSimulated.ToString()
                            $actionPerformed = $true
                            Write-Log "Routed simulated key '$selectedKey' to $sendTarget."
                        } catch {
                            Write-Log "Keystroke routing failed. Re-evaluating focus..."
                        }
                    }
                    
                    $script:NextRandomInterval = Get-Random -Minimum 1000 -Maximum 10000
                }

                if ($actionPerformed) {
                    $script:LastActionTime = [Environment]::TickCount
                }
            }
        } else {
            # Amber Idle warning thresholds UI transitions
            $amberThresholdMs = [Math]::Min(2000, ($thresholdMs / 2))
            
            if ($script:idleTimeMs -ge $amberThresholdMs) {
                if ($TxtEngineStatus.Text -ne "IDLE CLOCK TICKING") {
                    Update-UIState -statusText "IDLE CLOCK TICKING" -badgeText "IDLE DETECTED" -badgeBg $colorBrushAmberBg -badgeFg $colorBrushTextAmber
                }
            } else {
                if ($TxtEngineStatus.Text -ne "ACTIVE MONITORING") {
                    Update-UIState -statusText "ACTIVE MONITORING" -badgeText "MONITORING" -badgeBg $colorBrushBlueBg -badgeFg $colorBrushTextBlue
                }
            }
        }
    }
})

# 9. System Tray Setup and Event Handlers
function Update-TrayMenuCheckedStates {
    if ($script:engineActive) {
        $script:itemToggle.Text = "Stop Engine"
        $script:menuRbJitter.Enabled = $false
        $script:menuRbKey.Enabled = $false
        $script:menuRbCombined.Enabled = $false
        $script:menuCbPreventLock.Enabled = $false
        $script:menuCbShuffler.Enabled = $false
        $script:menuCbAutoExit.Enabled = $false
    } else {
        $script:itemToggle.Text = "Start Engine"
        $script:menuRbJitter.Enabled = $true
        $script:menuRbKey.Enabled = $true
        $script:menuRbCombined.Enabled = $true
        $script:menuCbPreventLock.Enabled = $true
        $script:menuCbShuffler.Enabled = $true
        $script:menuCbAutoExit.Enabled = $true
    }
    
    $script:menuRbJitter.Checked = $RbJitter.IsChecked
    $script:menuRbKey.Checked = $RbKey.IsChecked
    $script:menuRbCombined.Checked = $RbCombined.IsChecked
    
    $script:menuCbPreventLock.Checked = $CbPreventLock.IsChecked
    $script:menuCbShuffler.Checked = $CbShuffler.IsChecked
    $script:menuCbAutoExit.Checked = $CbAutoExit.IsChecked
}

# Setup System Tray Notify Icon
$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Text = "Activity Engine Pro"
$script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Application

$contextMenu = New-Object System.Windows.Forms.ContextMenu

$itemRestore = New-Object System.Windows.Forms.MenuItem("Show Window")
$itemRestore.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        $Window.Show()
        $Window.WindowState = [System.Windows.WindowState]::Normal
        $Window.Activate()
    }) | Out-Null
})
$contextMenu.MenuItems.Add($itemRestore) | Out-Null

$contextMenu.MenuItems.Add("-") | Out-Null

$script:itemToggle = New-Object System.Windows.Forms.MenuItem("Start Engine")
$script:itemToggle.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        if ($script:engineActive) {
            Stop-Engine
        } else {
            Start-Engine
        }
    }) | Out-Null
})
$contextMenu.MenuItems.Add($script:itemToggle) | Out-Null

# Mode selection menu
$itemMode = New-Object System.Windows.Forms.MenuItem("Simulation Mode")

$script:menuRbJitter = New-Object System.Windows.Forms.MenuItem("Mode A: Stealth Mouse Jitter")
$script:menuRbJitter.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        if (-not $script:engineActive) {
            $RbJitter.IsChecked = $true
            $RbKey.IsChecked = $false
            $RbCombined.IsChecked = $false
            Update-TrayMenuCheckedStates
        }
    }) | Out-Null
})

$script:menuRbKey = New-Object System.Windows.Forms.MenuItem("Mode B: Intelligent Key Router")
$script:menuRbKey.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        if (-not $script:engineActive) {
            $RbJitter.IsChecked = $false
            $RbKey.IsChecked = $true
            $RbCombined.IsChecked = $false
            Update-TrayMenuCheckedStates
        }
    }) | Out-Null
})

$script:menuRbCombined = New-Object System.Windows.Forms.MenuItem("Mode C: Combined Telemetry")
$script:menuRbCombined.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        if (-not $script:engineActive) {
            $RbJitter.IsChecked = $false
            $RbKey.IsChecked = $false
            $RbCombined.IsChecked = $true
            Update-TrayMenuCheckedStates
        }
    }) | Out-Null
})

$itemMode.MenuItems.Add($script:menuRbJitter) | Out-Null
$itemMode.MenuItems.Add($script:menuRbKey) | Out-Null
$itemMode.MenuItems.Add($script:menuRbCombined) | Out-Null
$contextMenu.MenuItems.Add($itemMode) | Out-Null

# Shields menu
$itemShields = New-Object System.Windows.Forms.MenuItem("Compliance Shields")

$script:menuCbPreventLock = New-Object System.Windows.Forms.MenuItem("Shield 1: Prevent Lock")
$script:menuCbPreventLock.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        if (-not $script:engineActive) {
            $CbPreventLock.IsChecked = -not $CbPreventLock.IsChecked
            Update-TrayMenuCheckedStates
        }
    }) | Out-Null
})

$script:menuCbShuffler = New-Object System.Windows.Forms.MenuItem("Shield 2: Window Focus Shuffler")
$script:menuCbShuffler.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        if (-not $script:engineActive) {
            $CbShuffler.IsChecked = -not $CbShuffler.IsChecked
            Update-TrayMenuCheckedStates
        }
    }) | Out-Null
})

$script:menuCbAutoExit = New-Object System.Windows.Forms.MenuItem("Shield 3: Auto Exit Application")
$script:menuCbAutoExit.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        if (-not $script:engineActive) {
            $CbAutoExit.IsChecked = -not $CbAutoExit.IsChecked
            Update-TrayMenuCheckedStates
        }
    }) | Out-Null
})

$itemShields.MenuItems.Add($script:menuCbPreventLock) | Out-Null
$itemShields.MenuItems.Add($script:menuCbShuffler) | Out-Null
$itemShields.MenuItems.Add($script:menuCbAutoExit) | Out-Null
$contextMenu.MenuItems.Add($itemShields) | Out-Null

$contextMenu.MenuItems.Add("-") | Out-Null

$itemExit = New-Object System.Windows.Forms.MenuItem("Quit Application")
$itemExit.Add_Click({
    $Window.Dispatcher.BeginInvoke([Action]{
        Stop-Engine
        Clean-Resources
        $Window.Close()
    }) | Out-Null
})
$contextMenu.MenuItems.Add($itemExit) | Out-Null

$script:notifyIcon.ContextMenu = $contextMenu
$script:notifyIcon.Visible = $true

# Double click on tray icon restores the window
$script:notifyIcon.Add_DoubleClick({
    $Window.Dispatcher.BeginInvoke([Action]{
        $Window.Show()
        $Window.WindowState = [System.Windows.WindowState]::Normal
        $Window.Activate()
    }) | Out-Null
})

# Sync initial checked states
Update-TrayMenuCheckedStates

# Window StateChanged event to handle minimizing to system tray
$Window.Add_StateChanged({
    if ($Window.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $Window.Dispatcher.BeginInvoke([Action]{
            $Window.Hide() # Hides window from desktop and taskbar
        }) | Out-Null
    }
})

# Window Closed event to guarantee cleanup of NotifyIcon and Notepad sandbox
$Window.Add_Closed({
    Stop-Engine
    Clean-Resources
})

# 10. Launch application and wait
$Window.ShowDialog() | Out-Null
