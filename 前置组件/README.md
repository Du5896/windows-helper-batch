# 🪟 windows-helper-batch（完整可运行版）

Windows 辅助批处理工具集，已包含启动器 `.bat` 与对应的实际程序 `.ps1`，下载即可用。
Windows helper batch toolkit — includes the `.bat` launchers and their `.ps1` programs. Ready to use after download.

## 📁 文件 / Files

| 启动器 Launcher | 实际程序 Program | 功能 Function |
|----------------|------------------|---------------|
| `电脑内存清理.bat` | `clean.ps1` | 电脑内存轻量清理 / Light PC memory cleanup |
| `使用时长限制.bat` | `countdown.ps1` | 到时提醒休息 / Break reminder after N minutes |
| `开机自启动管理.bat` | `startup_mgr.ps1` | 查看开机启动项 / View startup items |

## ⚙️ 使用方法 / How to use

1. 把三个 `.ps1` 文件复制到 `%LOCALAPPDATA%\DoubaoTools\` 目录（没有就新建）。
   Copy the three `.ps1` files into `%LOCALAPPDATA%\DoubaoTools\` (create it if missing).
2. 双击对应的 `.bat` 即可运行。
   Double-click the matching `.bat` to run.
   （也可直接右键 `.ps1` → 用 PowerShell 运行 / Or right-click a `.ps1` → Run with PowerShell）

## ⚠️ 安全提示 / Safety

- 仅支持 Windows / Windows only
- 运行前建议用记事本查看源码 / Review source in Notepad first
- 部分功能可能需管理员权限 / Some features may need admin rights
- 仅供个人学习测试 / For personal study only

## 📜 版权 / License

仅供个人查看、学习。未经作者允许，禁止二次修改、重新打包分发。
For personal study only; no redistribution without permission.
