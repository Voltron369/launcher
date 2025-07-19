# Flight Simulator System Monitor
# Checks USB joystick and required applications status

# Fix Unicode display in PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# CONFIGURATION - Update these with your specific details
$USB_JOYSTICK_NAME = "Moza AB9 Joysick"  # Change to your joystick name
$USB_JOYSTICK_VID_PID = "VID_346E&PID_1000"  # Optional: VID_1234&PID_5678 format

# List of required applications (process names without .exe)
$REQUIRED_PROCESSES = @(
    "SimHaptic",
    "SimAppPro",
    "MOZA Cockpit",
    "PimaxClient",
    "VoiceAttack",
    "cmd:EZWATCH",
    "OpenTabletDriver.Daemon",
    "OpenKneeboardApp",
    "PlatformManager"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Custom colors
$COLOR_GREEN = [System.Drawing.Color]::FromArgb(46, 125, 50)
$COLOR_RED = [System.Drawing.Color]::FromArgb(211, 47, 47)
$COLOR_BACKGROUND = [System.Drawing.Color]::FromArgb(37, 37, 38)
$COLOR_TEXT = [System.Drawing.Color]::White
$COLOR_PANEL = [System.Drawing.Color]::FromArgb(45, 45, 48)

function Check-USBJoystick {
    param([string]$DeviceName, [string]$VidPid = "")
    
    try {
        $usbDevices = Get-WmiObject -Class Win32_USBHub | Where-Object { $_.Name -ne $null }
        $pnpDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.DeviceID -like "*USB*" }
        
        $deviceFound = $false
        
        if ($DeviceName) {
            $deviceFound = ($usbDevices | Where-Object { $_.Name -like "*$DeviceName*" }) -or 
                          ($pnpDevices | Where-Object { $_.Name -like "*$DeviceName*" })
        }
        
        if (!$deviceFound -and $VidPid) {
            $deviceFound = $pnpDevices | Where-Object { $_.DeviceID -like "*$VidPid*" }
        }
        
        return [bool]$deviceFound
    }
    catch {
        return $false
    }
}

function Check-ProcessStatus {
    param([string[]]$ProcessNames)
    
    $status = @{}
    foreach ($processName in $ProcessNames) {
        # Check if it's a PowerShell script with specific arguments
        if ($processName.StartsWith("powershell:") -or $processName.StartsWith("cmd:")) {
            if ($processName.StartsWith("powershell:")) {
                $scriptToFind = $processName.Substring(11)  # Remove "powershell:" prefix
            }
            if ($processName.StartsWith("cmd:")) {
                $scriptToFind = $processName.Substring(4)  # Remove "powershell:" prefix
            }
            
            # Get all PowerShell processes and check their command lines
            $psProcesses = Get-WmiObject -Class Win32_Process | Where-Object { 
                $_.Name -eq "powershell.exe" -or $_.Name -eq "pwsh.exe" -or $_.Name -eq "cmd.exe"
            }
            
            $found = $false
            foreach ($proc in $psProcesses) {
                try {
                    $commandLine = $proc.CommandLine
                    if ($commandLine -and $commandLine.Contains($scriptToFind)) {
                        # Make sure it's not THIS script
                        if (!$commandLine.Contains($PSCommandPath)) {
                            $found = $true
                            break
                        }
                    }
                }
                catch {
                    # Skip if we can't access command line
                }
            }
            $status[$processName] = $found
        }
        else {
            # Regular process check
            $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
            $status[$processName] = [bool]$process
        }
    }
    return $status
}

function Create-StatusPanel {
    param(
        [string]$Title,
        [bool]$IsRunning,
        [int]$Y
    )
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(580, 35)
    $panel.Location = New-Object System.Drawing.Point(10, $Y)
    $panel.BackColor = $COLOR_PANEL
    $panel.BorderStyle = "FixedSingle"
    
    # Status indicator (circle)
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = if ($IsRunning) { "●" } else { "●" }
    $statusLabel.ForeColor = if ($IsRunning) { $COLOR_GREEN } else { $COLOR_RED }
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $statusLabel.Size = New-Object System.Drawing.Size(30, 35)
    $statusLabel.Location = New-Object System.Drawing.Point(10, 5)
    $statusLabel.TextAlign = "MiddleCenter"
    
    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.ForeColor = $COLOR_TEXT
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 35)
    $titleLabel.Location = New-Object System.Drawing.Point(45, 0)
    $titleLabel.TextAlign = "MiddleLeft"
    
    # Status text
    $statusText = New-Object System.Windows.Forms.Label
    $statusText.Text = if ($IsRunning) { "RUNNING" } else { "STOPPED" }
    $statusText.ForeColor = if ($IsRunning) { $COLOR_GREEN } else { $COLOR_RED }
    $statusText.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $statusText.Size = New-Object System.Drawing.Size(120, 35)
    $statusText.Location = New-Object System.Drawing.Point(450, 0)
    $statusText.TextAlign = "MiddleRight"
    
    $panel.Controls.AddRange(@($statusLabel, $titleLabel, $statusText))
    return $panel
}

function Show-SystemMonitor {
    # Create the main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Flight Simulator - System Monitor"
    $form.Size = New-Object System.Drawing.Size(620, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = $COLOR_BACKGROUND
    $form.TopMost = $true
    
    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "FLIGHT SIMULATOR SYSTEM STATUS"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $COLOR_TEXT
    $titleLabel.Size = New-Object System.Drawing.Size(600, 30)
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $titleLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($titleLabel)
    
    # Function to refresh status
    function Refresh-Status {
        $form.SuspendLayout()
        # Clear existing panels
        $panelsToRemove = @()
        foreach ($control in $form.Controls) {
            if ($control -is [System.Windows.Forms.Panel]) {
                $panelsToRemove += $control
            }
        }
        foreach ($panel in $panelsToRemove) {
            $form.Controls.Remove($panel)
        }
        
        $yPosition = 50
        
        # Check USB Joystick
        $joystickConnected = Check-USBJoystick -DeviceName $USB_JOYSTICK_NAME -VidPid $USB_JOYSTICK_VID_PID
        $joystickPanel = Create-StatusPanel -Title "USB Joystick ($USB_JOYSTICK_NAME)" -IsRunning $joystickConnected -Y $yPosition
        $form.Controls.Add($joystickPanel)
        $yPosition += 40
        
        # Check all required processes
        $processStatus = Check-ProcessStatus -ProcessNames $REQUIRED_PROCESSES
        $allProcessesRunning = $true
        
        foreach ($processName in $REQUIRED_PROCESSES) {
            $isRunning = $processStatus[$processName]
            if (!$isRunning) { $allProcessesRunning = $false }
            
            $processPanel = Create-StatusPanel -Title $processName -IsRunning $isRunning -Y $yPosition
            $form.Controls.Add($processPanel)
            $yPosition += 40
        }
        
        # Overall status summary
        $summaryY = $yPosition + 10
        $overallStatus = $joystickConnected -and $allProcessesRunning
        
        # Close form if everything is ready
        if ($overallStatus) {
            $timer.Stop()
            # Minimize all windows
            $shell = New-Object -ComObject Shell.Application
            $shell.MinimizeAll()

            # Launch your application
            Start-Process "C:\Falcon BMS 4.38\Launcher\FalconBMS_Alternative_Launcher.exe"  # Replace with your application
            $form.Close()
            return
        }
        
        $summaryPanel = New-Object System.Windows.Forms.Panel
        $summaryPanel.Size = New-Object System.Drawing.Size(580, 40)
        $summaryPanel.Location = New-Object System.Drawing.Point(10, $summaryY)
        $summaryPanel.BackColor = if ($overallStatus) { $COLOR_GREEN } else { $COLOR_RED }
        $summaryPanel.BorderStyle = "FixedSingle"
        
        $summaryLabel = New-Object System.Windows.Forms.Label
        $summaryLabel.Text = if ($overallStatus) { "✈️ READY FOR FLIGHT ✈️" } else { "⚠️ SYSTEM NOT READY ⚠️" }
        $summaryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $summaryLabel.ForeColor = $COLOR_TEXT
        $summaryLabel.Dock = "Fill"
        $summaryLabel.TextAlign = "MiddleCenter"
        
        $summaryPanel.Controls.Add($summaryLabel)
        $form.Controls.Add($summaryPanel)
        
        # Update form height
        $form.Height = $summaryY + 80
        $form.ResumeLayout()
    }
    
    # Initial status check
    Refresh-Status
    
    # Auto-refresh timer
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 2000  # Refresh every 2 seconds
    $timer.Add_Tick({ Refresh-Status })
    $timer.Start()
    
    # Manual refresh button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = "Refresh Now"
    $refreshButton.Size = New-Object System.Drawing.Size(100, 30)
    $refreshButton.Location = New-Object System.Drawing.Point(260, ($form.Height - 70))
    $refreshButton.BackColor = $COLOR_PANEL
    $refreshButton.ForeColor = $COLOR_TEXT
    $refreshButton.FlatStyle = "Flat"
    $refreshButton.Add_Click({ Refresh-Status })
    #$form.Controls.Add($refreshButton)
    
    # Show the form
    $form.Add_FormClosed({ $timer.Stop() })
    $form.ShowDialog() | Out-Null
}

# Main execution
Write-Host "Starting Flight Simulator System Monitor..."
Show-SystemMonitor

# To find your specific USB joystick name, run this command:
# Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Name -like "*joystick*" -or $_.Name -like "*game*" } | Select Name, DeviceID

# To find running processes, use:
# Get-Process | Where-Object { $_.ProcessName -like "*flight*" -or $_.ProcessName -like "*sim*" } | Select ProcessName