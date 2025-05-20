Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Rclone Multi-Remote Transfer Monitor"
$form.Size = New-Object System.Drawing.Size(900, 500)
$form.MinimumSize = New-Object System.Drawing.Size(700, 400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true

$iconPath = "C:\rclone\icon\rclone.ico"
if (Test-Path $iconPath) {
    $form.Icon = New-Object System.Drawing.Icon($iconPath)
}

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = 'Fill'
[void]$form.Controls.Add($tabControl)

$remotes = @(
    @{ Name = "OneDrive"; Port = 5574 },
    @{ Name = "backblazeBackup"; Port = 5573 },
    @{ Name = "backblazeArya"; Port = 5575 }
)

$tabControls = @{}

function Format-Bytes {
    param([long]$bytes)
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    else { return "$bytes B" }
}

foreach ($remote in $remotes) {
    $tabPage = New-Object System.Windows.Forms.TabPage $remote.Name
    [void]$tabControl.TabPages.Add($tabPage)

    $tableLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $tableLayout.Dock = 'Fill'
    $tableLayout.ColumnCount = 1
    $tableLayout.RowCount = 3
    $tableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40))) | Out-Null
    $tableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40))) | Out-Null
    $tableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    [void]$tabPage.Controls.Add($tableLayout)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Dock = 'Fill'
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    [void]$tableLayout.Controls.Add($progressBar, 0, 0)

    $summaryLabel = New-Object System.Windows.Forms.Label
    $summaryLabel.Dock = 'Fill'
    $summaryLabel.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $summaryLabel.TextAlign = 'MiddleLeft'
    $summaryLabel.Text = "Waiting for data..."
    [void]$tableLayout.Controls.Add($summaryLabel, 0, 1)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Dock = 'Fill'
    $listBox.Font = New-Object System.Drawing.Font("Consolas",9)
    [void]$tableLayout.Controls.Add($listBox, 0, 2)

    $tabControls[$remote.Name] = @{
        ProgressBar = $progressBar
        SummaryLabel = $summaryLabel
        ListBox = $listBox
        Port = $remote.Port
    }
}

$form.Add_FormClosing({
    param($sender, $e)
    $e.Cancel = $true
    $form.Hide()
})

$form.Add_Load({
    $form.Hide()
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000

$timer.Add_Tick({
    try {
        foreach ($remoteName in $tabControls.Keys) {
            $controls = $tabControls[$remoteName]
            $rcAddr = "localhost:$($controls.Port)"

            $json = rclone rc core/stats --rc-addr $rcAddr 2>$null | Out-String
            if (-not [string]::IsNullOrWhiteSpace($json)) {
                $stats = $json | ConvertFrom-Json

                $bytesTransferred = Format-Bytes $stats.bytes
                $speedMB = [math]::Round($stats.speed / 1MB, 2)
                $transfersCount = $stats.transfers
                $controls.SummaryLabel.Text = "Total transferred: $bytesTransferred | Speed: $speedMB MB/s | Active transfers: $transfersCount"

                if ($stats.transferring.Count -gt 0) {
                    $firstFile = $stats.transferring[0]
                    $percent = [math]::Round($firstFile.percentage)
                    $controls.ProgressBar.Value = [math]::Min($percent, 100)
                }
                else {
                    $controls.ProgressBar.Value = 0
                }

                $controls.ListBox.Items.Clear()
                if ($stats.transferring.Count -gt 0) {
                    foreach ($file in $stats.transferring) {
                        $name = $file.name
                        $filePercent = [math]::Round($file.percentage)
                        $fileSpeedMB = [math]::Round($file.speed / 1MB, 2)
                        $fileBytes = Format-Bytes $file.bytes
                        $fileSize = Format-Bytes $file.size
                        $etaSec = [math]::Round($file.eta)
                        $etaText = if ($etaSec -gt 0) { "$etaSec sec left" } else { "Almost done" }
                        $line = "{0,-40} {1,3}% {2,7} MB/s {3,10}/{4,-10} ETA: {5}" -f $name, $filePercent, $fileSpeedMB, $fileBytes, $fileSize, $etaText
                        [void]$controls.ListBox.Items.Add($line)
                    }
                }
                else {
                    [void]$controls.ListBox.Items.Add("No active transfers")
                }
            }
            else {
                $controls.SummaryLabel.Text = "No data received from rclone."
                $controls.ProgressBar.Value = 0
                $controls.ListBox.Items.Clear()
                [void]$controls.ListBox.Items.Add("No active transfers")
            }
        }
    }
    catch {
        foreach ($remoteName in $tabControls.Keys) {
            $controls = $tabControls[$remoteName]
            $controls.SummaryLabel.Text = "Error fetching stats: $_"
            $controls.ProgressBar.Value = 0
            $controls.ListBox.Items.Clear()
            [void]$controls.ListBox.Items.Add("Error fetching data")
        }
    }
})

$appContext = New-Object System.Windows.Forms.ApplicationContext

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = if (Test-Path $iconPath) {
    New-Object System.Drawing.Icon($iconPath)
} else {
    [System.Drawing.SystemIcons]::Application
}
$notifyIcon.Text = "Rclone Multi-Remote Transfer Monitor"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenu

$showMenuItem = New-Object System.Windows.Forms.MenuItem "Show Window"
$showMenuItem.Add_Click({
    if (-not $form.Visible) {
        $form.Show()
        $form.WindowState = 'Normal'
        $form.Activate()
    }
})
[void]$contextMenu.MenuItems.Add($showMenuItem)

$hideMenuItem = New-Object System.Windows.Forms.MenuItem "Hide Window"
$hideMenuItem.Add_Click({
    if ($form.Visible) {
        $form.Hide()
    }
})
[void]$contextMenu.MenuItems.Add($hideMenuItem)

[void]$contextMenu.MenuItems.Add("-")

$exitMenuItem = New-Object System.Windows.Forms.MenuItem "Exit"
$exitMenuItem.Add_Click({
    $notifyIcon.Visible = $false
    $form.Hide()
    $appContext.ExitThread()
})
[void]$contextMenu.MenuItems.Add($exitMenuItem)

$notifyIcon.ContextMenu = $contextMenu

$notifyIcon.Add_MouseDoubleClick({
    if ($form.Visible) {
        $form.Hide()
    }
    else {
        $form.Show()
        $form.WindowState = 'Normal'
        $form.Activate()
    }
})

$timer.Start()
[System.Windows.Forms.Application]::Run($appContext)
