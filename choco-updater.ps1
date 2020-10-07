Add-Type -AssemblyName System.Windows.Forms

function getListOfUpdates(){
    $updateList = choco outdated -r
    try {
        $updateList = [System.Collections.ArrayList]$updateList | % { $_.split("|")[0] }
    }
    catch {
        $updateList = $updateList.split("|")[0]
    }
    return $updateList
}

function checkAvailableUpdates($allNotifications){
    if ($allNotifications -eq $true){
        $global:trayIcon.BalloonTipText = "Please wait"
        $global:trayIcon.BalloonTipTitle = "Checking for updates"
        $global:trayIcon.ShowBalloonTip(2000)
    }
    $outdatedList = getListOfUpdates
    if ($outdatedList.count -gt 0){
        [System.Collections.ArrayList]$listToDisplay = @{}
        if ($outdatedList.count -gt 3){
            for ($i=0;$i -lt 3; $i++){
                $listToDisplay.Add($outdatedList[$i])
            }
            $global:trayIcon.BalloonTipText = ($listToDisplay -join ", ") + " + "+ [String]($outdatedList.count - 3) + " more"
        } else {
            $global:trayIcon.BalloonTipText = ($outdatedList -join ", ")
        }

        # Load original icon as bitmap
        $bitmap = [System.Drawing.Icon]::ExtractAssociatedIcon($global:chocoExe).ToBitmap()

        # Draw red circle
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.DrawImage($bitmap, 0, 0)
        $color = [System.Drawing.Color]::FromArgb(255, 255, 0, 0)
        $brush = New-Object System.Drawing.SolidBrush($color)
        $graphics.FillEllipse($brush, 15, 0, 15, 15)

        # Set new icon
        $global:trayIcon.Icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())

        $global:trayIcon.BalloonTipTitle = "Some applications needs upgrade"
        $global:trayIcon.ShowBalloonTip(2000)

    } else {
        $global:trayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($global:chocoExe)
        if ($allNotifications -eq $true){
            $global:trayIcon.BalloonTipText = "Nothing to do"
            $global:trayIcon.BalloonTipTitle = "All your applications are up to date"
            $global:trayIcon.ShowBalloonTip(2000)
        }
    }
}

# Hide Powershell window
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

# Specify path to choco.exe
$global:chocoExe = 'C:\ProgramData\chocolatey\bin\choco.exe'

# Create NotifyIcon object
$global:trayIcon = New-Object -TypeName System.Windows.Forms.NotifyIcon
$global:trayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($global:chocoExe)
$global:trayIcon.Visible = $true

# Enable gabage collector
[System.GC]::Collect()

# Add menu Check Updates
$menuCheckUpdates = New-Object System.Windows.Forms.MenuItem
$menuCheckUpdates.Text = "Check updates"

# Add menu Upgrade all
$menuUpgradeAll = New-Object System.Windows.Forms.MenuItem
$menuUpgradeAll.Text = "Upgrade all"

# Add menu exit
$menuExit = New-Object System.Windows.Forms.MenuItem
$menuExit.Text = "Exit"

# Add all menus as context menus
$global:trayIcon.ContextMenu = New-Object System.Windows.Forms.ContextMenu
$global:trayIcon.contextMenu.MenuItems.AddRange($menuCheckUpdates)
$global:trayIcon.contextMenu.MenuItems.AddRange($menuUpgradeAll)
$global:trayIcon.contextMenu.MenuItems.AddRange($menuExit)

$menuExit.add_Click({
    $global:trayIcon.Visible = $false
    $window.Close()
    Stop-Process $pid
})

$menuCheckUpdates.add_Click({
    checkAvailableUpdates -allNotifications $true
})

$menuUpgradeAll.add_Click({
    $global:trayIcon.BalloonTipText = "Please wait"
    $global:trayIcon.BalloonTipTitle = "Going to upgrade all applications"
    $global:trayIcon.ShowBalloonTip(2000)
    $chocoProcess = start-process -FilePath powershell.exe -PassThru -ArgumentList '-Command "choco upgrade all"'
    $chocoProcess.WaitForExit()
    checkAvailableUpdates -allNotifications $false
})

# Execute checkAvailableUpdates once, at application start without notifications
checkAvailableUpdates -allNotifications $false

# Create application context - must be on the end of the file, nothing after this cannot be executed
$appContext = New-Object -TypeName System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)
