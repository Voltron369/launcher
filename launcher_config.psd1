@{
    # USB Devices Configuration
    # Dictionary of device display names to VID/PID (VID_XXXX&PID_YYYY format, or "" if not used)
    USB_DEVICES = @{
        "Moza AB9 Joystick" = "VID_346E&PID_1000"
        "Tablet" = "VID_256C&PID_0064"
        "Pimax VR Headset" = "VID_04D8&PID_E7EB"
        "Winwing PTO 2" = "VID_4098&PID_BF05"
        "WinWing Orion 2 Throttle" = "VID_4098&PID_BE62"
        "HS-2100" = ""  # has same VID/PID as QS-BT1 so use name.
        "QS-BT1" = ""
        "Thrustmaster Rudder" = "VID_044F&PID_B679"
        "Buttkicker Pro" = "VID_33A1&PID_52DA"
    }

    # Required Processes Configuration
    # List of required applications with their start commands
    # Format: ProcessName = "Path\to\executable.exe" or "command"
    REQUIRED_PROCESSES = @{
        "SimHaptic" = "C:\Users\gdeca\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\SimHaptic.lnk"
        "SimAppPro" = "C:\Users\gdeca\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\SimAppPro.lnk"
        "MOZA Cockpit" = "C:\Program Files (x86)\MOZA Cockpit\MOZA Cockpit.exe"
        "PimaxClient" = "C:\Program Files\Pimax\PimaxClient\pimaxui\PimaxClient.exe"
        "VoiceAttack" = "C:\Users\gdeca\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\VoiceAttack.lnk"
        "cmd:EZWATCH" = "C:\Users\gdeca\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\EZWATCH.lnk"
        "OpenTabletDriver.Daemon" = "C:\Users\gdeca\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\OpenTabletDriver.UX.Wpf.lnk"
        "OpenKneeboardApp" = "C:\Users\gdeca\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\OpenKneeboard.lnk"
        "PlatformManager" = "C:\Users\gdeca\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Platform Manager"
    }

}