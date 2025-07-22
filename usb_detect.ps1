# USB Device Monitor - Uses polling to detect device changes
# Monitors for USB devices being added by comparing device lists


if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $CommandLine = "-File `"$($MyInvocation.MyCommand.Path)`" $($MyInvocation.UnboundArguments)"
    Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList $CommandLine
    exit
}

Write-Host "USB Device Monitor Started (Polling Method)" -ForegroundColor Green
Write-Host "Monitoring for USB device additions..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Cyan
Write-Host ("-" * 50)

# Function to extract VID and PID from device ID
function Get-VidPid {
    param([string]$DeviceID)
    
    if ($DeviceID -match "VID_([0-9A-F]{4}).*PID_([0-9A-F]{4})") {
        return "VID_$($matches[1])&PID_$($matches[2])"
    }
    return $null
}

# Function to get current USB devices
function Get-CurrentUSBDevices {
    try {
        $devices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.DeviceID -like "*VID_*" } | Select Name, DeviceID
        return $devices
    }
    catch {
        Write-Warning "Error getting USB devices: $_"
        return @()
    }
}

# Function to format device info for display
function Show-DeviceInfo {
    param($Device)
    
    $vidPid = Get-VidPid -DeviceID $Device.DeviceID
    if ($vidPid) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $deviceName = if ($Device.Name) { $Device.Name } else { "Unknown Device" }
        
        Write-Host "[$timestamp] USB Device Added:" -ForegroundColor Green
        Write-Host "  Name: $deviceName" -ForegroundColor White
        Write-Host "  ID: $vidPid" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Get initial device list
Write-Host "Getting initial USB device list..."
$previousDevices = Get-CurrentUSBDevices
Write-Host "Found $($previousDevices.Count) USB devices currently connected" -ForegroundColor Gray
Write-Host "Ready to monitor for changes..." -ForegroundColor Green
Write-Host ""

# Polling interval in seconds
$pollInterval = 1

try {
    while ($true) {
        Start-Sleep -Seconds $pollInterval
        
        # Get current devices
        $currentDevices = Get-CurrentUSBDevices
        
        # Compare with previous list to find new devices
        $newDevices = @()
        
        foreach ($currentDevice in $currentDevices) {
            $isNew = $true
            foreach ($previousDevice in $previousDevices) {
                if ($currentDevice.DeviceID -eq $previousDevice.DeviceID) {
                    $isNew = $false
                    break
                }
            }
            
            if ($isNew) {
                $newDevices += $currentDevice
            }
        }
        
        # Display any new devices found
        foreach ($newDevice in $newDevices) {
            Show-DeviceInfo -Device $newDevice
        }
        
        # Update previous devices list
        $previousDevices = $currentDevices
    }
}
catch [System.Management.Automation.PipelineStoppedException] {
    # Handle Ctrl+C gracefully
    Write-Host "`nMonitoring stopped by user." -ForegroundColor Red
}
catch {
    Write-Error "An error occurred during monitoring: $_"
}
finally {
    Write-Host "USB Device Monitor stopped." -ForegroundColor Yellow
}