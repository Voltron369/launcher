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
    
    # Store panel references for smooth updates
    $script:statusPanels = @{}
    $script:summaryPanel = $null
    $script:initialSetup = $true
    
    # Function to update panel status smoothly
    function Update-StatusPanel {
        param($Panel, $IsRunning)
        
        $statusLabel = $Panel.Controls[0]  # Status indicator
        $statusText = $Panel.Controls[2]   # Status text
        
        # Update with smooth transition
        $statusLabel.Text = if ($IsRunning) { "●" } else { "●" }
        $statusLabel.ForeColor = if ($IsRunning) { $COLOR_GREEN } else { $COLOR_RED }
        
        $statusText.Text = if ($IsRunning) { "RUNNING" } else { "STOPPED" }
        $statusText.ForeColor = if ($IsRunning) { $COLOR_GREEN } else { $COLOR_RED }
        
        # Force refresh
        $Panel.Refresh()
    }
    
    # Function to refresh status smoothly
    function Refresh-Status {

        $yPosition = 50
        
        # Check USB Joystick
        $joystickConnected = Check-USBJoystick -DeviceName $USB_JOYSTICK_NAME -VidPid $USB_JOYSTICK_VID_PID
        
        # Check all required processes
        $processStatus = Check-ProcessStatus -ProcessNames $REQUIRED_PROCESSES
        $allProcessesRunning = $true
        
        # Check if all processes are running
        foreach ($processName in $REQUIRED_PROCESSES) {
            if (!$processStatus[$processName]) { 
                $allProcessesRunning = $false 
                break
            }
        }

        if ($script:initialSetup) {
            # Initial setup - create all panels
            $form.SuspendLayout()
            
            # Create joystick panel
            $joystickPanel = Create-StatusPanel -Title "USB Joystick ($USB_JOYSTICK_NAME)" -IsRunning $joystickConnected -Y $yPosition
            $form.Controls.Add($joystickPanel)
            $script:statusPanels["joystick"] = $joystickPanel
            $yPosition += 40
            
            # Create process panels
            foreach ($processName in $REQUIRED_PROCESSES) {
                $isRunning = $processStatus[$processName]
                
                # Clean display name for PowerShell scripts
                $displayName = if ($processName.StartsWith("powershell:")) {
                    "PowerShell: " + $processName.Substring(11)
                } else {
                    $processName
                }

                # Clean display name for PowerShell scripts
                $displayName = if ($processName.StartsWith("cmd:")) {
                    "Cmd: " + $processName.Substring(4)
                } else {
                    $processName
                }

                $processPanel = Create-StatusPanel -Title $displayName -IsRunning $isRunning -Y $yPosition
                $form.Controls.Add($processPanel)
                $script:statusPanels[$processName] = $processPanel
                $yPosition += 40
            }
            
            # Create summary panel
            $summaryY = $yPosition + 10
            $overallStatus = $joystickConnected -and $allProcessesRunning
            
            $script:summaryPanel = New-Object System.Windows.Forms.Panel
            $script:summaryPanel.Size = New-Object System.Drawing.Size(580, 40)
            $script:summaryPanel.Location = New-Object System.Drawing.Point(10, $summaryY)
            $script:summaryPanel.BackColor = if ($overallStatus) { $COLOR_GREEN } else { $COLOR_RED }
            $script:summaryPanel.BorderStyle = "FixedSingle"
            
            $summaryLabel = New-Object System.Windows.Forms.Label
            $summaryLabel.Text = if ($overallStatus) { "✈️ READY FOR FLIGHT ✈️" } else { "⚠️ SYSTEM NOT READY ⚠️" }
            $summaryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
            $summaryLabel.ForeColor = $COLOR_TEXT
            $summaryLabel.Dock = "Fill"
            $summaryLabel.TextAlign = "MiddleCenter"
            
            $script:summaryPanel.Controls.Add($summaryLabel)
            $form.Controls.Add($script:summaryPanel)
            
            # Update form height
            $form.Height = $summaryY + 80
            $form.ResumeLayout()
            $script:initialSetup = $false
        }
        else {
            # Smooth update - just change existing panels

            # Update joystick status
            Update-StatusPanel -Panel $script:statusPanels["joystick"] -IsRunning $joystickConnected
            
            # Update process statuses
            foreach ($processName in $REQUIRED_PROCESSES) {
                $isRunning = $processStatus[$processName]
                Update-StatusPanel -Panel $script:statusPanels[$processName] -IsRunning $isRunning
            }
            
            # Update summary panel
            $overallStatus = $joystickConnected -and $allProcessesRunning
            $script:summaryPanel.BackColor = if ($overallStatus) { $COLOR_GREEN } else { $COLOR_RED }
            $summaryLabel = $script:summaryPanel.Controls[0]
            $summaryLabel.Text = if ($overallStatus) { "✈️ READY FOR FLIGHT ✈️" } else { "⚠️ SYSTEM NOT READY ⚠️" }
            $script:summaryPanel.Refresh()
        }
        
        # Close form if everything is ready
        $overallStatus = $joystickConnected -and $allProcessesRunning
        if ($overallStatus) {
            # Minimize all windows
            $shell = New-Object -ComObject Shell.Application
            $shell.MinimizeAll()

            # Launch your application
            Start-Process "C:\Falcon BMS 4.38\Launcher\FalconBMS_Alternative_Launcher.exe"  # Replace with your application

            if ($timer) {
                $timer.Stop()
                $form.Close()
            }
            return
        }
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
    $form.Controls.Add($refreshButton)

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