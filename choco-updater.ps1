Param
 (
 [String]$Restart
 )
 
If ($Restart -ne "") 
 {
  Start-Sleep 3
 } 

Add-Type -AssemblyName System.Windows.Forms 

function getListOfUpdates(){
    [System.Collections.ArrayList]$updateList = choco outdated -r | ForEach-Object { $_.split("|")[0] }
    return $updateList
}

$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

$trayIcon = New-Object -TypeName System.Windows.Forms.NotifyIcon
$trayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\ProgramData\chocolatey\bin\choco.exe") 
$trayIcon.Visible = $true

# Enable gabage collector
[System.GC]::Collect()

# Add menu Check Updaets
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

#Action after clicking on "Exit"
$menuExit.add_Click({
    $trayIcon.Visible = $false
    $window.Close()
    Stop-Process $pid
})

$menuCheckUpdates.add_Click({
    $trayIcon.BalloonTipText = "Please wait"
    $trayIcon.BalloonTipTitle = "Checking for updates"
    $trayIcon.ShowBalloonTip(2000)
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
        $trayIcon.BalloonTipTitle = "Some applications needs upgrade"
        $trayIcon.ShowBalloonTip(2000)

    } else {
        $trayIcon.BalloonTipText = "Nothing to do"
        $trayIcon.BalloonTipTitle = "All your applications are up to date"
        $trayIcon.ShowBalloonTip(2000)
    }
})

$menuUpgradeAll.add_Click({
    $trayIcon.BalloonTipText = "Please wait"
    $trayIcon.BalloonTipTitle = "Going to upgrade all applications"
    $trayIcon.ShowBalloonTip(2000)
    start-process -FilePath powershell.exe -ArgumentList '-Command "choco upgrade all"' 
})

# Create application context
$appContext = New-Object -TypeName System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)