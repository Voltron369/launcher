# Flight Simulator System Monitor

A PowerShell script with a graphical user interface (GUI) that checks the status of your flight simulator setup before launch. It verifies that your USB device is connected and all required background applications are running, ensuring you're ready for flight\! ✈️

<img width="908" height="859" alt="Image" src="https://github.com/user-attachments/assets/f10c3fbc-a119-4e6e-bae5-5e2c28ee7edc" />

-----

## Features ✨

  * **GUI Status Panel**: A clean, "always on top" window shows the real-time status of all required components.
  * **USB Device Check**: Verifies that your specific device or HOTAS is connected and recognized by Windows.
  * **Application Check**: Monitors a configurable list of essential applications (e.g., SimHaptic, VoiceAttack, MOZA Pit House) to ensure they are running.
  * **One-Click Start**: Start any missing application directly from the monitor's GUI.
  * **Auto-Launch**: Once all systems are green, the script automatically launches your main flight simulator (e.g., Falcon BMS, DCS, MSFS) and closes the monitor.
  * **Customizable**: Easily configure device names, application paths, and even the colors of the GUI.

-----

## Getting Started

### Prerequisites

  * Windows Operating System
  * PowerShell

### Installation & Configuration

1.  **Save the Script**: Save the code as `FlightSim-Monitor.ps1` (or any name you prefer) in a convenient location.

2.  **Configure Your Devices & Apps**: Open the `.ps1` file in a text editor and modify the `CONFIGURATION` section at the top.

      * **Device**: Update `$USB_DEVICE` with the name of your device.

          * **How to find your device name?** Run this command in PowerShell:
            ```powershell
            .\usb_detect
            ```
          * Optionally, for more reliability, you can also provide the `VID&PID`. Find this `DeviceID` from the command above.

      * **Required Applications**: Edit the `$REQUIRED_PROCESSES` hashtable.

          * The **key** (e.g., `"SimHaptic"`) is the process name to check for.
          * The **value** (e.g., `"C:\Path\to\SimHaptic.lnk"`) is the command or path needed to start the application.

        **Formats:**

        ```powershell
        $REQUIRED_PROCESSES = @{
            # For a standard .exe file or shortcut (.lnk)
            "MOZA Cockpit" = "C:\Program Files (x86)\MOZA Cockpit\MOZA Cockpit.exe"
        }
        ```

      * **Flight Simulator Launcher**: $launchProcess to your main simulator's executable.

-----

## Usage

1.  **Open PowerShell**: Right-click your desktop or a folder and select "Open in Terminal" or "Open PowerShell window here".

2.  **Run the Script**: Navigate to the directory where you saved the script and run it.

    ```powershell
    # You might need to change the execution policy the first time
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

    # Run the script
    .\launcher
    ```

The System Monitor window will appear. It will automatically refresh every few seconds. Once all items are **GREEN**, it will launch your simulator and exit.

You can make a shortcut to the launcher.ps1 script