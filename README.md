# windows-helper-batch
Windows辅助批处理启动脚本集合

## 文件列表
- pc_cleaner.bat 电脑内存清理启动器
- time_limit.bat 使用时长限制启动器
- startup_manager.bat 开机自启动管理启动器

## ⚠️重要说明
> 本仓库内的bat仅仅是启动器，依赖 `%LOCALAPPDATA%\DoubaoTools\` 目录下的ps1脚本。
需要把 `clean.ps1`、`countdown.ps1`、`startup_mgr.ps1` 放到这个文件夹，bat才可以正常工作。
只下载bat直接双击运行，会提示找不到脚本文件，无法执行功能。

## ⚠️安全警告
1. 仅支持 Windows系统。
2. 运行脚本前建议用记事本查看bat源码。
3. 脚本会调用PowerShell，部分功能可能需要管理员权限。
4. 仅供个人学习测试使用。

## 版权声明
本仓库脚本仅供个人查看、学习。未经作者允许，禁止二次修改、重新打包分发。
