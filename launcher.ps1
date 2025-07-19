# USB Device Monitor - Shows warning window if specific device not connected
# Replace these values with your specific USB device details
$TARGET_DEVICE_NAME = "Your USB Device Name"  # Change this to your device name
$TARGET_VID_PID = "USB\VID_346E&PID_1000\2C002C00014E56444E5A2020"        # Change this to your device VID/PID (optional)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Check-USBDevice {
    param(
        [string]$DeviceName,
        [string]$VidPid = ""
    )
    
    try {
        # Get all USB devices
        $usbDevices = Get-WmiObject -Class Win32_USBHub | Where-Object { $_.Name -ne $null }
        $pnpDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.DeviceID -like "*USB*" }
        
        # Check by device name
        $deviceFound = $false
        
        if ($DeviceName) {
            $deviceFound = ($usbDevices | Where-Object { $_.Name -like "*$DeviceName*" }) -or 
                          ($pnpDevices | Where-Object { $_.Name -like "*$DeviceName*" })
        }

        # Check by VID/PID if provided
        if (!$deviceFound -and $VidPid) {
            $deviceFound = $pnpDevices | Where-Object { $_.DeviceID -like "*$VidPid*" }
        }
        
        return [bool]$deviceFound
    }
    catch {
        Write-Host "Error checking USB devices: $($_.Exception.Message)"
        return $false
    }
}

function Show-WarningWindow {
    param([string]$DeviceName)
    
    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "USB Device Warning"
    $form.Size = New-Object System.Drawing.Size(600, 300)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::DarkRed
    $form.ForeColor = [System.Drawing.Color]::White
    
    # Create the warning label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "WARNING`n`n$DeviceName`nNOT CONNECTED`n`nPlease connect the device"
    $label.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
    $label.TextAlign = "MiddleCenter"
    $label.Dock = "Fill"
    $label.AutoSize = $false
    
    # Create retry button
    $retryButton = New-Object System.Windows.Forms.Button
    $retryButton.Text = "Check Again"
    $retryButton.Size = New-Object System.Drawing.Size(100, 30)
    $retryButton.Location = New-Object System.Drawing.Point(250, 220)
    $retryButton.BackColor = [System.Drawing.Color]::White
    $retryButton.ForeColor = [System.Drawing.Color]::Black
    
    # Add retry button click event
    $retryButton.Add_Click({
        if (Check-USBDevice -DeviceName $TARGET_DEVICE_NAME -VidPid $TARGET_VID_PID) {
            $form.Close()
        }
    })
    
    # Add controls to form
    $form.Controls.Add($retryButton)
    $form.Controls.Add($label)

    
    # Show the form
    $form.ShowDialog() | Out-Null
}

# Main execution
Write-Host "Checking for USB device: $TARGET_DEVICE_NAME"

if (Check-USBDevice -DeviceName $TARGET_DEVICE_NAME -VidPid $TARGET_VID_PID) {
    Write-Host "Device found. Exiting normally."
    exit 0
} else {
    Write-Host "Device NOT found. Showing warning window."
    Show-WarningWindow -DeviceName $TARGET_DEVICE_NAME
    exit 1
}

# Instructions for use:
# 1. Replace $TARGET_DEVICE_NAME with your actual USB device name
# 2. Optionally replace $TARGET_VID_PID with your device's Vendor ID and Product ID
# 3. Save as .ps1 file and run with PowerShell
# 4. To find your device details, run: Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.DeviceID -like "*USB*" } | Select Name, DeviceID