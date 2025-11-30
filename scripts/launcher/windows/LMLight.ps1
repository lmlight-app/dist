# LM Light Launcher for Windows
# Toggle start/stop

$installDir = "$env:LOCALAPPDATA\lmlight"
$pidFile = "$installDir\logs\api.pid"

Add-Type -AssemblyName System.Windows.Forms

function Show-Notification($title, $message) {
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $notify.ShowBalloonTip(3000, $title, $message, [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 1
    $notify.Dispose()
}

if (Test-Path $pidFile) {
    # Stop
    Show-Notification "LM Light" "Stopping..."
    & "$installDir\stop.bat" 2>$null
    Show-Notification "LM Light" "Stopped"
} else {
    # Start
    Show-Notification "LM Light" "Starting..."
    & "$installDir\start.bat" 2>$null
    Start-Sleep -Seconds 3
    Show-Notification "LM Light" "Started: http://localhost:3000"
    Start-Process "http://localhost:3000"
}
