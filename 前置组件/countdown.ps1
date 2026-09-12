# ============================================================
#  使用时长限制工具 —— 倒计时核心（v2.1）
#  全新交互：图形界面输入分钟数 → 屏幕中央倒计时 → 时间到提示
#           20 秒内可一键取消关机 → 20 秒后保存并关机
#  不需要管理员权限；全程只有窗口界面，无命令行中文
# ============================================================
param([int]$Minutes = 0)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:state = 'running'      # running / timeup / cancelled
$script:cancelSec = 20

# ---------- 输入窗体 ----------
function Show-InputForm {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = '使用时长限制'
    $f.Size = New-Object System.Drawing.Size(480, 260)
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedSingle'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.TopMost = $true
    $f.BackColor = [System.Drawing.Color]::FromArgb(22, 30, 50)

    $tip = New-Object System.Windows.Forms.Label
    $tip.Text = "请输入允许使用电脑的分钟数`n（时间到后将自动保存并关机，到点前 20 秒可取消）"
    $tip.Font = New-Object System.Drawing.Font('Microsoft YaHei', 11)
    $tip.ForeColor = [System.Drawing.Color]::LightGray
    $tip.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $tip.AutoSize = $false
    $tip.Size = New-Object System.Drawing.Size(440, 70)
    $tip.Location = New-Object System.Drawing.Point(20, 15)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Size = New-Object System.Drawing.Size(200, 30)
    $box.Location = New-Object System.Drawing.Point(140, 105)
    $box.Font = New-Object System.Drawing.Font('Microsoft YaHei', 14)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = '开始倒计时'
    $btn.Size = New-Object System.Drawing.Size(140, 42)
    $btn.Location = New-Object System.Drawing.Point(170, 155)
    $btn.Font = New-Object System.Drawing.Font('Microsoft YaHei', 11)
    $btn.BackColor = [System.Drawing.Color]::FromArgb(50, 90, 150)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = 'Flat'

    $f.Controls.Add($tip); $f.Controls.Add($box); $f.Controls.Add($btn)
    $f.AcceptButton = $btn

    $script:inputResult = -1
    $btn.Add_Click({
        $txt = $box.Text.Trim()
        if ($txt -match '^\d+$' -and [int]$txt -ge 1) {
            $script:inputResult = [int]$txt
            $f.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show('请输入大于 0 的数字分钟数', '提示', 'OK', 'Warning') | Out-Null
        }
    })
    $f.Add_FormClosing({
        if ($script:inputResult -lt 0) { $script:inputResult = 0 }  # 直接关闭=取消
    })
    [System.Windows.Forms.Application]::Run($f)
}

# ---------- 主流程 ----------
if ($Minutes -le 0) {
    Show-InputForm
    if ($script:inputResult -le 0) { exit 0 }   # 用户取消
    $Minutes = $script:inputResult
}

$totalSec = $Minutes * 60

$form = New-Object System.Windows.Forms.Form
$form.Text = '使用时长限制'
$form.Size = New-Object System.Drawing.Size(780, 520)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(20, 28, 46)

$mainLabel = New-Object System.Windows.Forms.Label
$mainLabel.Text = '{0:00}:{1:00}' -f [math]::Floor($totalSec / 60), ($totalSec % 60)
$mainLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei', 52, [System.Drawing.FontStyle]::Bold)
$mainLabel.ForeColor = [System.Drawing.Color]::LimeGreen
$mainLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$mainLabel.Dock = [System.Windows.Forms.DockStyle]::Fill

$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Text = "本次使用时间：$Minutes 分钟`n时间到后将自动保存并关机`n窗口请勿关闭（可随时点下方按钮取消）"
$infoLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei', 12)
$infoLabel.ForeColor = [System.Drawing.Color]::LightGray
$infoLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$infoLabel.AutoSize = $false
$infoLabel.Height = 110
$infoLabel.Dock = [System.Windows.Forms.DockStyle]::Bottom

$cancelBtn = New-Object System.Windows.Forms.Button
$cancelBtn.Text = '取消本次使用限制'
$cancelBtn.Font = New-Object System.Drawing.Font('Microsoft YaHei', 11)
$cancelBtn.Size = New-Object System.Drawing.Size(200, 44)
$cancelBtn.Location = New-Object System.Drawing.Point(290, 430)
$cancelBtn.BackColor = [System.Drawing.Color]::FromArgb(60, 70, 95)
$cancelBtn.ForeColor = [System.Drawing.Color]::White
$cancelBtn.FlatStyle = 'Flat'

$form.Controls.Add($mainLabel)
$form.Controls.Add($infoLabel)
$form.Controls.Add($cancelBtn)

$form.Add_FormClosing({
    if ($script:state -ne 'cancelled') {
        $_.Cancel = $true
    }
})

$cancelBtn.Add_Click({
    if ($script:state -eq 'running') {
        $r = [System.Windows.Forms.MessageBox]::Show('确定取消本次使用限制？取消后将不会关机。', '确认取消', 'YesNo', 'Question')
        if ($r -eq 'Yes') { $script:state = 'cancelled'; $form.Close() }
    } elseif ($script:state -eq 'timeup') {
        $r = [System.Windows.Forms.MessageBox]::Show('确定取消关机？', '确认取消', 'YesNo', 'Question')
        if ($r -eq 'Yes') { $script:state = 'cancelled'; $form.Close() }
    }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $script:totalSec--
    if ($script:totalSec -gt 0) {
        $h = [math]::Floor($script:totalSec / 3600)
        $m = [math]::Floor(($script:totalSec % 3600) / 60)
        $s = $script:totalSec % 60
        if ($h -gt 0) { $mainLabel.Text = '{0}:{1:00}:{2:00}' -f $h, $m, $s }
        else { $mainLabel.Text = '{0:00}:{1:00}' -f $m, $s }
    } else {
        $timer.Stop()
        $script:state = 'timeup'
        $mainLabel.Text = '时间到了，不能应用了！'
        $mainLabel.ForeColor = [System.Drawing.Color]::OrangeRed
        $mainLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei', 40, [System.Drawing.FontStyle]::Bold)
        $infoLabel.Text = "系统将在 $($script:cancelSec) 秒后保存并关机，可点下方[取消关机]取消"
        $cancelBtn.Text = '取消关机'
        $script:cancelRemain = $script:cancelSec
        $cancelTimer.Start()
    }
})
$timer.Start()

$cancelTimer = New-Object System.Windows.Forms.Timer
$cancelTimer.Interval = 1000
$cancelTimer.Add_Tick({
    $script:cancelRemain--
    if ($script:cancelRemain -gt 0) {
        $infoLabel.Text = "系统将在 $($script:cancelRemain) 秒后保存并关机，可点下方[取消关机]取消"
    } else {
        $cancelTimer.Stop()
        $infoLabel.Text = '正在保存并关机...'
        $cancelBtn.Enabled = $false
        try {
            Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList @('/s', '/t', '0') -ErrorAction Stop
        } catch {
            & "$env:SystemRoot\System32\shutdown.exe" /s /t 0
        }
    }
})

[System.Windows.Forms.Application]::Run($form)
