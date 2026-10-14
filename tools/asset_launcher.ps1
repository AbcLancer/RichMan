param([ValidateSet('', 'original', 'enhanced', 'remade', 'compare')][string]$Mode = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$candidates = @(
    'D:\Godot\Godot_v4.7.2-stable_win64.exe',
    (Join-Path $projectRoot 'Godot\Godot_v4.7.2-stable_win64.exe'),
    (Join-Path $projectRoot '.tools\Godot_v4.7.2-stable_win64.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe')
)
$engine = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
function Start-Profile([string]$Profile) {
    if (-not $engine) { throw 'Godot executable not found. See PLAY.bat.' }
    $gameDirectory = Join-Path $projectRoot 'game'
    # Import freshly unpacked PNGs before starting the game directly.
    & $engine --headless --editor --import --path $gameDirectory | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Godot could not import the game assets.' }
    $launchArgs = @('--path', ('"' + $gameDirectory + '"'), '--resolution', '1440x900')
    switch ($Profile) {
        'original' { $launchArgs += @('--', '--original-graphics') }
        'remade' { $launchArgs += @('--', '--remade-assets') }
        'compare' { $launchArgs += 'res://scenes/asset_comparison.tscn' }
    }
    Start-Process -FilePath $engine -ArgumentList $launchArgs -WorkingDirectory $projectRoot -WindowStyle Normal
}
if ($Mode) { Start-Profile $Mode; exit }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = '大富翁 6 · 素材版本对照'
$form.ClientSize = New-Object System.Drawing.Size(500, 355)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$title = New-Object System.Windows.Forms.Label
$title.Text = '选择素材版本'
$title.Location = New-Object System.Drawing.Point(24, 18)
$title.Size = New-Object System.Drawing.Size(450, 32)
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 16, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)
$choices = @(
    @('compare', '同屏对照：原素材 / 高清修复 / 新版重绘'),
    @('remade', '启动新版重绘资产'),
    @('enhanced', '启动上一轮高清修复版'),
    @('original', '启动原素材版')
)
$row = 0
foreach ($choice in $choices) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $choice[1]
    $button.Tag = $choice[0]
    $button.Location = New-Object System.Drawing.Point(24, (66 + $row * 54))
    $button.Size = New-Object System.Drawing.Size(452, 44)
    $button.Add_Click({
        try { Start-Profile ([string]$this.Tag) }
        catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '无法启动') | Out-Null }
    })
    $form.Controls.Add($button)
    $row++
}
$note = New-Object System.Windows.Forms.Label
$note.Text = '三个版本使用相同玩法。对照场景可切换角色、标志物和地图。'
$note.Location = New-Object System.Drawing.Point(24, 290)
$note.Size = New-Object System.Drawing.Size(452, 48)
$form.Controls.Add($note)
[void]$form.ShowDialog()
