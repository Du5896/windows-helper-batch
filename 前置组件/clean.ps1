# ============================================================
#  电脑内存清理工具 —— 清理核心（v2.0）
#  全新版本：全程不需要管理员权限，无 UAC 弹窗
#  清理范围（全部为可再生的缓存 / 临时文件 / 回收站）：
#    1. 用户临时文件      %TEMP%
#    2. Windows 临时目录  %WINDIR%\Temp（能删多少删多少）
#    3. Chrome / Edge 浏览器缓存
#    4. 资源管理器缩略图缓存
#    5. 回收站（当前用户的回收站，无需管理员）
#    6. Windows 锁屏壁纸缓存（系统会自动重新下载）
#    7. DNS 缓存
#    8. 内存工作集释放（真实释放空闲内存，不结束任何程序）
#  安全边界：只动缓存/临时文件，绝不碰系统关键文件；
#            权限不足或正在使用的文件自动跳过，不影响其他清理
# ============================================================
param([switch]$SkipTemp)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(936) } catch {}

function Get-DirSize {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $size = 0
    Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $_.PSIsContainer) { $size += $_.Length }
    }
    return $size
}

function Clear-FolderContents {
    param([string]$Name, [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ 项目 = $Name; 状态 = '跳过（目录不存在）'; 释放 = '0 MB' }
    }
    $before = Get-DirSize $Path
    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.PSIsContainer) {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    $after = Get-DirSize $Path
    $freed = $before - $after
    if ($before -eq 0)      { $status = '已是空的' }
    elseif ($freed -gt 0)   { $status = '已清理' }
    else                    { $status = '部分文件被占用，已跳过' }
    [pscustomobject]@{ 项目 = $Name; 状态 = $status; 释放 = ('{0:N1} MB' -f ($freed / 1MB)) }
}

function Clear-BrowserCaches {
    param([string]$BasePath, [string]$Name)
    $profiles = @()
    if (Test-Path -LiteralPath $BasePath) {
        $profiles = Get-ChildItem -LiteralPath $BasePath -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @('Crashpad') -and $_.Name -notlike 'Guest*' }
    }
    if ($profiles.Count -eq 0) {
        return [pscustomobject]@{ 项目 = $Name; 状态 = '跳过（浏览器未安装）'; 释放 = '0 MB' }
    }
    $before = 0; $after = 0
    $targets = @('Cache', 'Cache_Data', 'Code Cache', 'GPUCache', 'DawnCache', 'GrShaderCache', 'ShaderCache')
    foreach ($profile in $profiles) {
        foreach ($t in $targets) {
            $dir = Join-Path $profile.FullName $t
            if (Test-Path -LiteralPath $dir) {
                $before += Get-DirSize $dir
                Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.PSIsContainer) { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
                    else { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
                }
                $after += Get-DirSize $dir
            }
        }
    }
    $freed = $before - $after
    if ($before -eq 0)      { $status = '已是空的' }
    elseif ($freed -gt 0)   { $status = '已清理' }
    else                    { $status = '浏览器正在运行，缓存被占用已跳过' }
    [pscustomobject]@{ 项目 = $Name; 状态 = $status; 释放 = ('{0:N1} MB' -f ($freed / 1MB)) }
}

# ---------- 开始清理 ----------
Write-Host ''
Write-Host '  ============================================================'
Write-Host '   电脑内存清理工具 —— 正在清理，请稍候...'
Write-Host '  ============================================================' -ForegroundColor Cyan
Write-Host ''

$results = @()
$totalFreedMB = 0

if (-not $SkipTemp) {
    $r = Clear-FolderContents '用户临时文件' $env:TEMP
    $totalFreedMB += [double]($r.释放 -replace ' MB', ''); $results += $r
}

$r = Clear-FolderContents 'Windows 临时目录' "$env:WINDIR\Temp"
$totalFreedMB += [double]($r.释放 -replace ' MB', ''); $results += $r

$r = Clear-BrowserCaches "$env:LOCALAPPDATA\Google\Chrome\User Data" 'Chrome 浏览器缓存'
$totalFreedMB += [double]($r.释放 -replace ' MB', ''); $results += $r

$r = Clear-BrowserCaches "$env:LOCALAPPDATA\Microsoft\Edge\User Data" 'Edge 浏览器缓存'
$totalFreedMB += [double]($r.释放 -replace ' MB', ''); $results += $r

# 缩略图缓存
$thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$thumbBefore = Get-DirSize $thumbDir
Get-ChildItem -LiteralPath $thumbDir -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(thumbcache_|iconcache_).*\.db$' } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
$thumbFreed = $thumbBefore - (Get-DirSize $thumbDir)
$totalFreedMB += $thumbFreed / 1MB
if ($thumbFreed -gt 0) { $tStatus = '已清理' } elseif ($thumbBefore -eq 0) { $tStatus = '已是空的' } else { $tStatus = '被资源管理器占用，已跳过' }
$results += [pscustomobject]@{ 项目 = '缩略图缓存'; 状态 = $tStatus; 释放 = ('{0:N1} MB' -f ($thumbFreed / 1MB)) }

# 回收站（当前用户，无需管理员）
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
$results += [pscustomobject]@{ 项目 = '回收站'; 状态 = '已清空'; 释放 = '已清空' }

# 锁屏壁纸缓存
$lockAssets = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets"
$lockBefore = Get-DirSize $lockAssets
if (Test-Path -LiteralPath $lockAssets) {
    Get-ChildItem -LiteralPath $lockAssets -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
}
$lockFreed = $lockBefore - (Get-DirSize $lockAssets)
$totalFreedMB += $lockFreed / 1MB
if ($lockFreed -gt 0) { $lStatus = '已清理（下次自动重新下载锁屏壁纸）' } elseif ($lockBefore -eq 0) { $lStatus = '已是空的' } else { $lStatus = '部分被占用，已跳过' }
$results += [pscustomobject]@{ 项目 = '锁屏壁纸缓存'; 状态 = $lStatus; 释放 = ('{0:N1} MB' -f ($lockFreed / 1MB)) }

# DNS 缓存
& ipconfig /flushdns | Out-Null
$results += [pscustomobject]@{ 项目 = 'DNS 缓存'; 状态 = '已刷新'; 释放 = '已刷新' }

# 内存工作集释放（真实释放空闲物理内存，不结束任何进程）
$memCode = @'
using System;
using System.Runtime.InteropServices;
public static class MemUtil {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
'@
$memOk = $false
try {
    Add-Type -TypeDefinition $memCode -ErrorAction Stop
    $freedCount = 0
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if ([MemUtil]::EmptyWorkingSet($_.Handle)) { $freedCount++ }
        } catch {}
    }
    $memOk = $true
    $results += [pscustomobject]@{ 项目 = '内存工作集释放'; 状态 = "已释放 $freedCount 个进程的空闲内存"; 释放 = 'RAM 已释放' }
} catch {
    $results += [pscustomobject]@{ 项目 = '内存工作集释放'; 状态 = '跳过（无权限的部分进程除外）'; 释放 = '0 MB' }
}

# ---------- 报告 ----------
Write-Host ''
Write-Host '  ============================================================'
Write-Host '   清理完成，结果如下：'
Write-Host '  ============================================================' -ForegroundColor Cyan
Write-Host ''
$results | Format-Table 项目, 状态, 释放 -AutoSize | Out-String -Width 120 | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host "  本次共释放磁盘空间约：$([math]::Round($totalFreedMB,1)) MB" -ForegroundColor Green
if ($memOk) { Write-Host '  内存空闲工作集已释放（未结束任何程序）' -ForegroundColor Green }
Write-Host '  说明：清理的都是缓存/临时文件，系统会自动重建；未使用管理员权限，系统文件不受影响。' -ForegroundColor Yellow
Write-Host ''
