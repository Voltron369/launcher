# Simple and robust launcher for launcher.bat
param()

# Get the directory of the current executable/script
$exeDir = $null

# Method 1: Try PSScriptRoot first (most reliable for .ps1 files)
if ($PSScriptRoot) {
    $exeDir = $PSScriptRoot
}

# Method 2: Try MyInvocation for .ps1 files
if (-not $exeDir -and $MyInvocation.MyCommand.Path) {
    $exeDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Method 3: For compiled EXE files
if (-not $exeDir) {
    try {
        $exeDir = [System.AppDomain]::CurrentDomain.BaseDirectory
        # Clean up trailing backslash if present
        $exeDir = $exeDir.TrimEnd('\')
    } catch { }
}

# Method 4: Fall back to current working directory
if (-not $exeDir) {
    $exeDir = $PWD.Path
}

Write-Host "Looking for launcher.bat in: $exeDir"

# Path to the batch file - change this to match your actual batch file name
$batchPath = Join-Path $exeDir "launcher.bat"  # Change to "launcher.bat" if that's your file name

# Check if batch file exists
if (Test-Path $batchPath) {
    Write-Host "Found launcher.bat - executing..." -ForegroundColor Green

    # Execute the batch file - properly handle spaces in paths
    try {
        # Method 1: Use Start-Process (most reliable for paths with spaces)
        Start-Process -FilePath $batchPath -WorkingDirectory $exeDir -Wait -WindowStyle Normal
        Write-Host "launcher.bat completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Error running launcher.bat: $($_.Exception.Message)" -ForegroundColor Red

        # Method 2: Fallback using cmd with proper quoting
        try {
            Write-Host "Trying fallback method..." -ForegroundColor Yellow
            $quotedPath = "`"$batchPath`""
            cmd.exe /c $quotedPath
            Write-Host "launcher.bat completed (fallback method)." -ForegroundColor Green
        }
        catch {
            Write-Host "Fallback method also failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "launcher.bat not found at: $batchPath" -ForegroundColor Red
    Write-Host "Please ensure launcher.bat is in the same directory as this executable." -ForegroundColor Yellow
}
