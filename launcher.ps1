<#
.SYNOPSIS
Flight Simulator System Monitor
Checks for required USB devices and running applications. Launches a process automatically when ready, or manually via an override button.

.PARAMETER LaunchCommand
An optional string that specifies the process to launch, including any arguments.
Example: -LaunchCommand '"C:\Games\MSFS\msfs.exe" -vr'
#>
param(
    [string]$ExecutablePath,
    [string[]]$Arguments
)

# Flight Simulator System Monitor
# Checks USB devices and required applications status

# Load configuration from PSD1 file
$configPath = Join-Path $PSScriptRoot "launcher_config.psd1"

# uncomment the line below to use the current directory
# $configPath =  "launcher_config.psd1"

$config = Import-PowerShellDataFile -Path $configPath

# Extract configuration variables
$USB_DEVICES = $config.USB_DEVICES
$REQUIRED_PROCESSES = $config.REQUIRED_PROCESSES
$DEFAULT_AUDIO_DEVICE = $config.DEFAULT_AUDIO_DEVICE
$DEFAULT_OPENXR_RUNTIME = $config.DEFAULT_OPENXR_RUNTIME
$CLOSE_APPS_ON_STARTUP = $config.CLOSE_APPS_ON_STARTUP
if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
    $ExecutablePath = $config.EXECUTABLE_PATH
    $Arguments = $config.ARGUMENTS
}

$Runtimes = @{
    # "oculus" = "C:\Program Files\Oculus\Support\oculus-runtime\oculus_openxr_64.json"
    "pimax" = "C:\Program Files\Pimax\Runtime\PiOpenXR_64.json"
}

# Fix Unicode display in PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Custom colors
$COLOR_GREEN = [System.Drawing.Color]::FromArgb(46, 125, 50)
$COLOR_RED = [System.Drawing.Color]::FromArgb(211, 47, 47)
$COLOR_BLUE = [System.Drawing.Color]::FromArgb(33, 150, 243)
$COLOR_BACKGROUND = [System.Drawing.Color]::FromArgb(37, 37, 38)
$COLOR_TEXT = [System.Drawing.Color]::White
$COLOR_PANEL = [System.Drawing.Color]::FromArgb(45, 45, 48)

# Use AudioDeviceCmdlets module if available
function Set-DefaultAudioDevice {
    param([string]$DeviceName)

    if (-not $DeviceName) {
        return $true
    }
    
    if (Get-Module -ListAvailable -Name AudioDeviceCmdlets) {
        Import-Module AudioDeviceCmdlets
        $devices = Get-AudioDevice -List | Where-Object { $_.Name -like "*$DeviceName*" }
        
        if ($devices.Count -eq 0) {
            Write-Error "No audio device found matching name: $DeviceName"
            return $false
        }
        
        if ($devices.Count -gt 1) {
            Write-Warning "Multiple devices found matching '$DeviceName'. Using first match: $($devices[0].Name)"
        }
        
        Set-AudioDevice -InputObject $devices[0]
        Write-Host "Set default audio device to: $($devices[0].Name)" -ForegroundColor Green
        return $true
    } else {
        Write-Warning "AudioDeviceCmdlets module not found. run: Install-Module -Name AudioDeviceCmdlets -Force -Scope CurrentUser"
    }
    
    return $false
}

function Check-USBDevice {
    param([string]$DeviceName, [string]$VidPid = "", $usbDevices, $pnpDevices)
    
    try {
        
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

function Check-AllDevices {
    param([hashtable]$DeviceConfig)
    
    $usbDevices = Get-WmiObject -Class Win32_USBHub | Where-Object { $_.Name -ne $null }
    $pnpDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.DeviceID -like "*USB*" }
    $deviceStatus = @{}
    foreach ($deviceName in $DeviceConfig.Keys) {
        $vidPid = $DeviceConfig[$deviceName]
        $deviceStatus[$deviceName] = Check-USBDevice -DeviceName $deviceName -VidPid $vidPid -usbDevices $usbDevices -pnpDevices $pnpDevices
    }
    return $deviceStatus
}

function Check-ProcessStatus {
    param([hashtable]$ProcessConfig)
    
    $status = @{}
    $processes = Get-WmiObject -Class Win32_Process
    foreach ($processName in $ProcessConfig.Keys) {
        # Check if it's a PowerShell script with specific arguments
        if ($processName.StartsWith("powershell:") -or $processName.StartsWith("cmd:")) {
            if ($processName.StartsWith("powershell:")) {
                $scriptToFind = $processName.Substring(11)  # Remove "powershell:" prefix
            }
            if ($processName.StartsWith("cmd:")) {
                $scriptToFind = $processName.Substring(4)  # Remove "cmd:" prefix
            }
            
            # Get all PowerShell processes and check their command lines
            $psProcesses = $processes | Where-Object { 
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
            $process = $processes | Where-Object { 
                $_.Name -like "*$processName*"
            }
            $status[$processName] = [bool]$process
        }
    }
    return $status
}

function Create-StatusPanel {
    param(
        [string]$Title,
        [bool]$IsRunning,
        [int]$Y,
        [string]$ProcessName = "",
        [string]$StartCommand = ""
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
    $titleLabel.Size = New-Object System.Drawing.Size(300, 35)
    $titleLabel.Location = New-Object System.Drawing.Point(45, 0)
    $titleLabel.TextAlign = "MiddleLeft"
    
    # Status text
    $statusText = New-Object System.Windows.Forms.Label
    $statusText.Text = if ($IsRunning) { "RUNNING" } else { "STOPPED" }
    $statusText.ForeColor = if ($IsRunning) { $COLOR_GREEN } else { $COLOR_RED }
    $statusText.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $statusText.Size = New-Object System.Drawing.Size(80, 35)
    $statusText.Location = New-Object System.Drawing.Point(350, 0)
    $statusText.TextAlign = "MiddleRight"
    
    $panel.Controls.AddRange(@($statusLabel, $titleLabel, $statusText))
    
    # Add Start button if this is a process panel (not device)
    if ($ProcessName -and $StartCommand) {
        $startButton = New-Object System.Windows.Forms.Button
        $startButton.Text = "Start"
        $startButton.Size = New-Object System.Drawing.Size(60, 25)
        $startButton.Location = New-Object System.Drawing.Point(440, 5)
        $startButton.BackColor = $COLOR_BLUE
        $startButton.ForeColor = $COLOR_TEXT
        $startButton.FlatStyle = "Flat"
        $startButton.Enabled = !$IsRunning  # Disable if already running
        $startButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        
        # Add click event to start the process
        $capturedProcessName = $ProcessName
        $capturedStartCommand = $StartCommand
        
        $startButton.Add_Click({
            try {
                Write-Host "Starting $capturedProcessName with command: $capturedStartCommand"
                
                # Use Invoke-Expression to handle commands with arguments and different types
                # Invoke-Expression -Command "Start-Process $capturedStartCommand"
                Start-Process -FilePath $capturedStartCommand

                Write-Host "Started $capturedProcessName successfully"
                
                Start-Sleep -Seconds 2
                if ($script:RefreshFunction) {
                    & $script:RefreshFunction
                }
            }
            catch {
                Write-Host "Failed to start $capturedProcessName : $($_.Exception.Message)"
                [System.Windows.Forms.MessageBox]::Show("Failed to start $capturedProcessName`n`n$capturedStartCommand`n`nError: $($_.Exception.Message)`n`nPlease check the path in the configuration.", "Start Process Error", "OK", "Warning")
            }
        }.GetNewClosure())
        
        $panel.Controls.Add($startButton)
    }
    
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
        
        $statusLabel = $Panel.Controls[0]
        $statusText = $Panel.Controls[2]
        
        $statusLabel.Text = "●"
        $statusLabel.ForeColor = if ($IsRunning) { $COLOR_GREEN } else { $COLOR_RED }
        
        $statusText.Text = if ($IsRunning) { "RUNNING" } else { "STOPPED" }
        $statusText.ForeColor = if ($IsRunning) { $COLOR_GREEN } else { $COLOR_RED }
        
        if ($Panel.Controls.Count -gt 3) {
            $startButton = $Panel.Controls[3]
            $startButton.Enabled = !$IsRunning
        }
        
        $Panel.Refresh()
    }
    
    # --- CORRECTED: Shared Launch Function to handle spaces in path ---
    function Invoke-LaunchAndClose {
        param(
            [string]$commandToRun,
            [string[]]$arguments
        )
        Set-DefaultAudioDevice -DeviceName $DEFAULT_AUDIO_DEVICE

        if ($DEFAULT_OPENXR_RUNTIME) {
            $runtimePath = $Runtimes[$DEFAULT_OPENXR_RUNTIME]
            if (-not $runtimePath -or -not (Test-Path $runtimePath)) {
                Write-Warning "Runtime path not found for $RuntimeName`: $runtimePath"
                return $false
            }
            $env:XR_RUNTIME_JSON = $runtimePath
        }

        if ([string]::IsNullOrWhiteSpace($commandToRun)) { return }

        $timer.Stop()
        try {
            $executable = $commandToRun
            
            Write-Host "Minimizing windows and launching..."
            Write-Host "Executable: $executable"
            Write-Host "Arguments: $arguments"

            $shell = New-Object -ComObject Shell.Application
            $shell.MinimizeAll()
            
            if ($Arguments -and $Arguments.Count -gt 0) {
                Start-Process -FilePath $ExecutablePath -ArgumentList $Arguments
            } else {
                Start-Process -FilePath $ExecutablePath
            }
            

            $form.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to launch application.`n`nCommand: $commandToRun`n`nError: $($_.Exception.Message)", "Launch Error", "OK", "Error")
            $timer.Start()
        }
    }

    # Function to refresh status smoothly
    function Refresh-Status {
        # Check devices and processes
        $deviceStatus = Check-AllDevices -DeviceConfig $USB_DEVICES
        $allDevicesConnected = ($deviceStatus.Values | Where-Object { $_ -eq $false }).Count -eq 0
        
        $processStatus = Check-ProcessStatus -ProcessConfig $REQUIRED_PROCESSES
        $allProcessesRunning = ($processStatus.Values | Where-Object { $_ -eq $false }).Count -eq 0
        
        $overallStatus = $allDevicesConnected -and $allProcessesRunning

        if ($script:initialSetup) {
            # Initial setup - create all panels
            $form.SuspendLayout()
            
            $yPosition = 50
            # Create device and process panels
            foreach ($deviceName in $USB_DEVICES.Keys) {
                $panel = Create-StatusPanel -Title "USB Device ($deviceName)" -IsRunning $deviceStatus[$deviceName] -Y $yPosition
                $form.Controls.Add($panel)
                $script:statusPanels["device_$deviceName"] = $panel
                $yPosition += 40
            }
            foreach ($processName in $REQUIRED_PROCESSES.Keys) {
                $displayName = $processName
                if ($processName.StartsWith("powershell:")) { $displayName = "PowerShell: " + $processName.Substring(11) }
                elseif ($processName.StartsWith("cmd:")) { $displayName = "Cmd: " + $processName.Substring(4) }
                $panel = Create-StatusPanel -Title $displayName -IsRunning $processStatus[$processName] -Y $yPosition -ProcessName $processName -StartCommand $REQUIRED_PROCESSES[$processName]
                $form.Controls.Add($panel)
                $script:statusPanels[$processName] = $panel
                $yPosition += 40
            }
            
            # Create summary panel
            $summaryY = $yPosition + 10
            $script:summaryPanel = New-Object System.Windows.Forms.Panel
            $script:summaryPanel.Size = New-Object System.Drawing.Size(580, 40)
            $script:summaryPanel.Location = New-Object System.Drawing.Point(10, $summaryY)
            $script:summaryPanel.BackColor = if ($overallStatus) { $COLOR_GREEN } else { $COLOR_RED }
            $script:summaryPanel.BorderStyle = "FixedSingle"
            $summaryLabel = New-Object System.Windows.Forms.Label
            $summaryLabel.Text = if ($overallStatus) { "READY FOR FLIGHT" } else { "SYSTEM NOT READY" }
            $summaryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
            $summaryLabel.ForeColor = $COLOR_TEXT
            $summaryLabel.Dock = "Fill"
            $summaryLabel.TextAlign = "MiddleCenter"
            $script:summaryPanel.Controls.Add($summaryLabel)
            $form.Controls.Add($script:summaryPanel)

            # Create Manual Override Launch Button
            if (-not [string]::IsNullOrWhiteSpace($ExecutablePath)) {

                $launchButtonY = $summaryY + 50
                $launchButton = New-Object System.Windows.Forms.Button
                $launchButton.Size = New-Object System.Drawing.Size(580, 40)
                $launchButton.Location = New-Object System.Drawing.Point(10, $launchButtonY)
                $launchButton.BackColor = $COLOR_BLUE
                $launchButton.ForeColor = $COLOR_TEXT
                $launchButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
                $launchButton.FlatStyle = "Flat"
            
                $launchButton.Text = "Launch Now: $(Split-Path $ExecutablePath -Leaf)"
                $launchButton.Enabled = $true

                $launchButton.Add_Click({ Invoke-LaunchAndClose -commandToRun $ExecutablePath -arguments $Arguments })
                $form.Controls.Add($launchButton)
                $form.Height = $launchButtonY + 90
            } else {
                $form.Height = $summaryY + 90
            }


            
            $form.ResumeLayout()
            $script:initialSetup = $false
        }
        else {
            # Smooth update
            foreach ($deviceName in $USB_DEVICES.Keys) {
                Update-StatusPanel -Panel $script:statusPanels["device_$deviceName"] -IsRunning $deviceStatus[$deviceName]
            }
            foreach ($processName in $REQUIRED_PROCESSES.Keys) {
                Update-StatusPanel -Panel $script:statusPanels[$processName] -IsRunning $processStatus[$processName]
            }
            
            # Update summary panel
            $script:summaryPanel.BackColor = if ($overallStatus) { $COLOR_GREEN } else { $COLOR_RED }
            $summaryLabel = $script:summaryPanel.Controls[0]
            $summaryLabel.Text = if ($overallStatus) { "READY FOR FLIGHT" } else { "SYSTEM NOT READY" }
            $script:summaryPanel.Refresh()
        }
        
        # Automatic Launch on Ready
        if ($overallStatus) {
            Invoke-LaunchAndClose -commandToRun $ExecutablePath -arguments $Arguments
        }
    }
    
    $script:RefreshFunction = ${function:Refresh-Status}
    
    # Initial status check
    Refresh-Status
    
    # Auto-refresh timer
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 2000
    $timer.Add_Tick({ 
        # Check if form still exists before refreshing, to prevent errors on close
        if ($form.IsDisposed) {
            $timer.Stop()
        } else {
            Refresh-Status 
        }
    })
    $timer.Start()
    
    $form.Add_FormClosed({ $timer.Stop() })
    $form.ShowDialog() | Out-Null
}

# Main execution
Write-Host "Starting Flight Simulator System Monitor..."

# Shut down specified applications in parallel
$jobs = foreach ($AppName in $CLOSE_APPS_ON_STARTUP) {
    Start-Job -ScriptBlock {
        # We must pass the app name in as an argument
        param($name)

        $process = Get-Process $name -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Name $name -Force
            return "Successfully closed '$name'."
        } else {
            return "'$name' is not currently running."
        }
    } -ArgumentList $AppName
}

# Wait for all jobs to complete and then display their output
$jobs | Wait-Job | Receive-Job

Write-Host "cleanup complete." -ForegroundColor Cyan

# Clean up the completed jobs
$jobs | Remove-Job

Show-SystemMonitor