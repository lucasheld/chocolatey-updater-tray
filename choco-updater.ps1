Add-Type -AssemblyName System.Windows.Forms 

function getListOfUpdates(){
    [System.Collections.ArrayList]$updateList = choco outdated -r | % { $_.split("|")[0] }
    return $updateList
}

function checkAvailableUpdates($trayIcon, $allNotifications){
    if ($allNotifications -eq $true){
        $trayIcon.BalloonTipText = "Please wait"
        $trayIcon.BalloonTipTitle = "Checking for updates"
        $trayIcon.ShowBalloonTip(2000)
    }
    $outdatedList = getListOfUpdates
    if ($outdatedList.count -gt 0){
        [System.Collections.ArrayList]$listToDisplay = @{}
        if ($outdatedList.count -gt 3){
            for ($i=0;$i -lt 3; $i++){
                $listToDisplay.Add($outdatedList[$i])
            }
            $trayIcon.BalloonTipText = ($listToDisplay -join ", ") + " + "+ [String]($outdatedList.count - 3) + " more"
        } else {
            $trayIcon.BalloonTipText = ($outdatedList -join ", ")
        }

        # Load original icon as bitmap
        $bitmap = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\ProgramData\chocolatey\bin\choco.exe").ToBitmap()

        # Draw red circle
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.DrawImage($bitmap, 0, 0)
        $color = [System.Drawing.Color]::FromArgb(255, 255, 0, 0)
        $brush = New-Object System.Drawing.SolidBrush($color)
        $graphics.FillEllipse($brush, 15, 0, 15, 15)

        # Set new icon
        $trayIcon.Icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())

        $trayIcon.BalloonTipTitle = "Some applications needs upgrade"
        $trayIcon.ShowBalloonTip(2000)

    } else {
        if ($allNotifications -eq $true){
            $trayIcon.BalloonTipText = "Nothing to do"
            $trayIcon.BalloonTipTitle = "All your applications are up to date"
            $trayIcon.ShowBalloonTip(2000)
        }
    }
}

# Hide Powershell window
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

# Create NotifyIcon object 
$trayIcon = New-Object -TypeName System.Windows.Forms.NotifyIcon
$trayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\ProgramData\chocolatey\bin\choco.exe")
$trayIcon.Visible = $true

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
$trayIcon.ContextMenu = New-Object System.Windows.Forms.ContextMenu
$trayIcon.contextMenu.MenuItems.AddRange($menuCheckUpdates)
$trayIcon.contextMenu.MenuItems.AddRange($menuUpgradeAll)
$trayIcon.contextMenu.MenuItems.AddRange($menuExit)

$menuExit.add_Click({
    $trayIcon.Visible = $false
    $window.Close()
    Stop-Process $pid
})

$menuCheckUpdates.add_Click({
    checkAvailableUpdates -trayIcon $trayIcon -allNotifications $true
})

$menuUpgradeAll.add_Click({
    $trayIcon.BalloonTipText = "Please wait"
    $trayIcon.BalloonTipTitle = "Going to upgrade all applications"
    $trayIcon.ShowBalloonTip(2000)
    start-process -FilePath powershell.exe -ArgumentList '-Command "choco upgrade all"' 
})

# Execute checkAvailableUpdates once, at application start without notifications
checkAvailableUpdates -trayIcon $trayIcon -allNotifications $false

# Create application context - must be on the end of the file, nothing after this cannot be executed
$appContext = New-Object -TypeName System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)
