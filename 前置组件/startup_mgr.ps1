# ============================================================
#  开机自启动管理工具 —— 核心逻辑（v2.0）
#  全新版本：默认只管理"当前用户"的启动项（HKCU\Run + 启动文件夹）
#           完全不需要管理员权限，无 UAC 弹窗
#  系统级项（HKLM\Run 等）只读展示，标注"系统级·需管理员"，不可操作
#  安全：操作全部可逆（禁用时自动备份），有操作日志
# ============================================================
param([switch]$SelfTest)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(936) } catch {}

# ---------- 路径与常量 ----------
$userRunKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$sysRunKeys     = @(
    @{ Label = 'HKLM\Run';     Key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
    @{ Label = 'HKLM\Run(64)'; Key = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
)
$startupFolder  = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$backupRegKey   = 'HKCU:\Software\DoubaoStartupMgr\Backup'
$backupDir      = "$env:APPDATA\DoubaoStartupMgr\Backup"
$disabledFolder = "$backupDir\StartupDisabled"
$logFile        = "$backupDir\startup_manager.log"

New-Item -ItemType Directory -Force -Path $backupDir     | Out-Null
New-Item -ItemType Directory -Force -Path $disabledFolder | Out-Null
if (-not (Test-Path $backupRegKey)) { New-Item -Path $backupRegKey -Force | Out-Null }

# 系统保护名单（键名命中即保护，即使它出现在用户启动项里）
$protectNames = @(
    'SecurityHealth', 'SecurityHealthSystray', 'RtkAudUService', 'RtkAudUService64',
    'AMDNoiseSuppression', 'ctfmon', 'ShellExperienceHost', 'explorer',
    'MsMpEng', 'WinDefend', 'WindowsDefender'
)

function Write-Log {
    param([string]$Msg)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Test-Protected {
    param([string]$Name, [string]$Command)
    if ($protectNames -contains $Name) { return $true }
    if ($Command -match '(?i)\\system32\\') { return $true }
    return $false
}

# ---------- 读取全部启动项 ----------
function Get-StartupItems {
    $items = @()
    $seq = 0

    # 用户级：HKCU\Run（可操作）
    if (Test-Path $userRunKey) {
        $key = Get-Item -LiteralPath $userRunKey
        foreach ($prop in $key.Property) {
            $val = (Get-ItemProperty -LiteralPath $userRunKey).$prop
            if ([string]::IsNullOrEmpty($val)) { continue }
            $seq++
            $items += [pscustomobject]@{
                Seq = $seq; Name = $prop; Command = [string]$val
                Source = 'HKCU\Run'; Kind = '注册表'
                State = 'enabled'; Disabled = $false
                Protected = (Test-Protected $prop $val)
                SysLevel = $false
                BackKey = $userRunKey
            }
        }
    }

    # 系统级：HKLM\Run（只读展示，不可操作）
    foreach ($s in $sysRunKeys) {
        if (-not (Test-Path $s.Key)) { continue }
        $key = Get-Item -LiteralPath $s.Key
        foreach ($prop in $key.Property) {
            $val = (Get-ItemProperty -LiteralPath $s.Key).$prop
            if ([string]::IsNullOrEmpty($val)) { continue }
            $seq++
            $items += [pscustomobject]@{
                Seq = $seq; Name = $prop; Command = [string]$val
                Source = $s.Label; Kind = '注册表'
                State = 'enabled'; Disabled = $false
                Protected = $true; SysLevel = $true
                BackKey = $s.Key
            }
        }
    }

    # 用户级：启动文件夹（可操作）
    if (Test-Path -LiteralPath $startupFolder) {
        Get-ChildItem -LiteralPath $startupFolder -Force -File |
            Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $seq++
            $items += [pscustomobject]@{
                Seq = $seq; Name = $_.Name; Command = $_.FullName
                Source = '启动文件夹'; Kind = '快捷方式'
                State = 'enabled'; Disabled = $false
                Protected = $false; SysLevel = $false
                BackKey = $startupFolder
            }
        }
    }

    # 已禁用的：注册表备份
    if (Test-Path $backupRegKey) {
        $bk = Get-Item -LiteralPath $backupRegKey
        foreach ($prop in $bk.Property) {
            $data = ((Get-ItemProperty -LiteralPath $backupRegKey).$prop | ConvertFrom-Json)
            $seq++
            $items += [pscustomobject]@{
                Seq = $seq; Name = $data.Name; Command = $data.Command
                Source = $data.Source; Kind = '注册表'
                State = 'disabled'; Disabled = $true
                Protected = $false; SysLevel = $false
                BackKey = $data.BackKey; BackupValueName = $prop
            }
        }
    }

    # 已禁用的：启动文件夹备份
    if (Test-Path -LiteralPath $disabledFolder) {
        Get-ChildItem -LiteralPath $disabledFolder -Force -File |
            Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $seq++
            $items += [pscustomobject]@{
                Seq = $seq; Name = $_.Name; Command = $_.FullName
                Source = '启动文件夹'; Kind = '快捷方式'
                State = 'disabled'; Disabled = $true
                Protected = $false; SysLevel = $false
                BackKey = $startupFolder; BackupFileName = $_.Name
            }
        }
    }

    return $items
}

# ---------- 禁用 ----------
function Disable-Item {
    param($Item)
    if ($Item.Kind -eq '注册表') {
        $key = Get-Item -LiteralPath $Item.BackKey
        $valKind = 'String'
        try { $valKind = $key.GetValueKind($Item.Name) } catch {}
        $data = @{
            Name = $Item.Name; Command = $Item.Command
            Source = $Item.Source; Kind = '注册表'
            BackKey = $Item.BackKey; ValueKind = $valKind
        }
        $backupName = ('{0}__{1}' -f ($Item.Source -replace '[\\:()]', '_'), $Item.Name) -replace '[^a-zA-Z0-9_\-]', '_'
        New-ItemProperty -Path $backupRegKey -Name $backupName -Value ($data | ConvertTo-Json -Compress) -PropertyType String -Force | Out-Null
        Remove-ItemProperty -Path $Item.BackKey -Name $Item.Name -Force
        Write-Log "禁用: $($Item.Source)\$($Item.Name)"
        return "已禁用：$($Item.Name)"
    }
    else {
        Move-Item -LiteralPath $Item.Command -Destination (Join-Path $disabledFolder $Item.Name) -Force
        Write-Log "禁用: 启动文件夹\$($Item.Name)"
        return "已禁用：$($Item.Name)"
    }
}

# ---------- 启用 ----------
function Enable-Item {
    param($Item)
    if ($Item.Kind -eq '注册表') {
        $data = $null
        $bk = Get-Item -LiteralPath $backupRegKey
        foreach ($prop in $bk.Property) {
            $d = ((Get-ItemProperty -LiteralPath $backupRegKey).$prop | ConvertFrom-Json)
            if ($d.Name -eq $Item.Name -and $d.Source -eq $Item.Source) { $data = $d; $Item.BackupValueName = $prop; break }
        }
        if ($null -eq $data) { return "失败：找不到 $($Item.Name) 的备份数据" }
        $kind = if ($data.ValueKind -eq 'ExpandString') { 'ExpandString' } else { 'String' }
        New-ItemProperty -Path $data.BackKey -Name $data.Name -Value $data.Command -PropertyType $kind -Force
        Remove-ItemProperty -Path $backupRegKey -Name $Item.BackupValueName -Force -ErrorAction SilentlyContinue
        Write-Log "启用: $($data.Source)\$($data.Name)"
        return "已启用：$($Item.Name)"
    }
    else {
        $src = Join-Path $disabledFolder $Item.Name
        if (Test-Path -LiteralPath $src) {
            Move-Item -LiteralPath $src -Destination (Join-Path $startupFolder $Item.Name) -Force
            Write-Log "启用: 启动文件夹\$($Item.Name)"
            return "已启用：$($Item.Name)"
        }
        return "失败：找不到备份文件 $($Item.Name)"
    }
}

# ---------- 显示菜单 ----------
function Show-Menu {
    param($Items)
    Clear-Host
    Write-Host ''
    Write-Host '  ============================================================'
    Write-Host '   开机自启动管理工具（v2.0 · 无需管理员权限）'
    Write-Host '  ============================================================' -ForegroundColor Cyan
    Write-Host ''
    $en = 0; $dis = 0
    foreach ($it in $Items) { if ($it.Disabled) { $dis++ } else { $en++ } }
    Write-Host ("  共 {0} 项：启用 {1} / 已禁用 {2}（灰色=已禁用，黄色=系统级只读）" -f $Items.Count, $en, $dis)
    Write-Host '  ------------------------------------------------------------------'
    foreach ($it in $Items) {
        if ($it.SysLevel) {
            Write-Host ("  [{0,2}]  {1}  [系统级 · 需管理员修改]" -f $it.Seq, $it.Name) -ForegroundColor DarkYellow
            Write-Host ("         {0}" -f $it.Command) -ForegroundColor DarkGray
            continue
        }
        if ($it.Protected) {
            Write-Host ("  [{0,2}]  {1}  [系统关键项 · 已保护]" -f $it.Seq, $it.Name) -ForegroundColor Yellow
            Write-Host ("         {0}" -f $it.Command) -ForegroundColor DarkGray
            continue
        }
        $state = if ($it.Disabled) { '已禁用' } else { '启用中' }
        $color = if ($it.Disabled) { 'DarkGray' } else { 'White' }
        Write-Host ("  [{0,2}]  {1}  —  {2}  [{3}]" -f $it.Seq, $it.Name, $state, $it.Source) -ForegroundColor $color
        Write-Host ("         {0}" -f $it.Command) -ForegroundColor DarkGray
    }
    Write-Host '  ------------------------------------------------------------------'
    Write-Host '  输入编号 = 切换 启用/禁用（仅限白色可操作项）；输入 0 = 退出'
    Write-Host '  禁用时自动备份，可随时恢复；操作日志见 %APPDATA%\DoubaoStartupMgr\Backup'
    Write-Host ''
}

# ---------- 主循环 ----------
if (-not $SelfTest) {
    Write-Log '工具启动'
    while ($true) {
        $items = Get-StartupItems
        Show-Menu $items
        $choice = Read-Host '  请输入编号'
        if ($choice -eq '0') { Write-Log '工具退出'; break }
        $sel = $items | Where-Object { $_.Seq -eq [int]$choice } | Select-Object -First 1
        if ($null -eq $sel) {
            Write-Host '  无效编号，请重新输入。' -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            continue
        }
        if ($sel.Protected -or $sel.SysLevel) {
            Write-Host "  $($sel.Name) 为系统级/系统关键项，本工具不操作。" -ForegroundColor Red
            Start-Sleep -Milliseconds 1200
            continue
        }
        if ($sel.Disabled) { $msg = Enable-Item $sel } else { $msg = Disable-Item $sel }
        Write-Host "  $msg" -ForegroundColor Green
        Start-Sleep -Milliseconds 1200
    }
}
