# Flight Simulator System Monitor

A PowerShell script with a graphical user interface (GUI) that checks the status of your flight simulator setup before launch. It verifies that your USB devices are connected and all required background applications are running, ensuring you're ready for flight\!

<p align="center">
<img width="454" height="685" alt="Image" src="https://github.com/user-attachments/assets/5b6a745f-2d78-4ebf-b569-43d8b6728c89" />
</p>

-----

## Features

  * **GUI Status Panel**: A clean, "always on top" window shows the real-time status of all required components.
  * **USB Device Check**: Verifies that your specific USB devices, Joysticks or HOTAS is connected and recognized by Windows.
  * **Application Check**: Monitors a configurable list of essential applications (e.g., SimHaptic, VoiceAttack, MOZA Pit House) to ensure they are running.
  * **One-Click Start**: Start any missing application directly from the monitor's GUI.
  * **Auto-Launch**: Once all systems are green, the script automatically launches your game or flight simulator (e.g., Falcon BMS, DCS, MSFS) and closes the monitor.
  * **Manual Launch**: Bypass the checks and launch your game or flight simulator (e.g., Falcon BMS, DCS, MSFS)
  * **Customizable**: Easily configure device names, application paths, and even the colors of the GUI.

-----

## Getting Started

### Prerequisites

  * Windows Operating System
  * PowerShell

### Installation & Configuration

1.  **Save the Script**: Save the code as `launcher.ps1` (or any name you prefer) in a convenient location.

2.  **Configure Your Devices & Apps**: Open the `.psd1` file in a text editor.

      * **Device**: Update `USB_DEVICES` with the name of your device.

          * **How to find your device name?** Run this command in PowerShell:
            ```powershell
            .\usb_detect
            ```
          * Optionally, for more reliability, you can also provide the `VID&PID`. Find this `DeviceID` from the command above.

      * **Required Applications**: Edit the `REQUIRED_PROCESSES` hashtable.

          * The **key** (e.g., `"SimHaptic"`) is the process name to check for.
          * The **value** (e.g., `"C:\Path\to\SimHaptic.lnk"`) is the command or path needed to start the application.

        **Formats:**

        ```powershell
        REQUIRED_PROCESSES = @{
            # For a standard .exe file or shortcut (.lnk)
            "MOZA Cockpit" = "C:\Program Files (x86)\MOZA Cockpit\MOZA Cockpit.exe"
        }
        ```
    
3.  **Install AudioDeviceCmdlets**  If you want to set the audio device on launch, update `DEFAULT_AUDIO_DEVICE` in the `.psd1` file.  Install AudioDeviceCmdlets in PowerShell: `Install-Module -Name AudioDeviceCmdlets -Force -Scope CurrentUser`

4.  **Add To Shortcut**: Right-click on the shortcut and add the full path to launcher.bat to the beginning of the target.

<p align="center">
<img width="304" height="402" alt="Image" src="https://github.com/user-attachments/assets/9f212ea6-e32b-4605-8eea-aece62463491" />
</p>

-----

## Usage
    
1.  **Shortcut**: click on the shortcut.  You can manually start processes and launch the simulator.  The simulator will launch automatically if everything is up and running.

2.  or **Manually Run the Script**: Navigate to the directory where you saved the script and run it.

    ```powershell
    # You might need to change the execution policy the first time
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

    # Run the script
    .\launcher.bat "C:\Falcon BMS 4.38\Launcher\FalconBMS_Alternative_Launcher.exe"
    ```

The System Monitor window will appear. It will automatically refresh every few seconds. Once all items are **GREEN**, it will launch your simulator and exit.