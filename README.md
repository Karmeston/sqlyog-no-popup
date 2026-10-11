# SQLyog No Popup

去掉 **SQLyog 社区版退出时的推广弹窗**，支持恢复原样。

一个独立的 PowerShell 脚本，无需安装依赖，也无需常驻运行。自动寻找安装位置，修改前核对完整文件并创建原版备份。另提供可选桌面界面。

## 快速开始

需要 **64 位 Windows、Windows PowerShell 5.1** 和下表中的 SQLyog 社区版。先关闭 SQLyog，再在 PowerShell 中运行：

```powershell
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Karmeston/sqlyog-no-popup/v0.1.0/sqlyog-no-popup.ps1' -OutFile sqlyog-no-popup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 apply
```

第一行下载脚本，第二行去掉退出推广弹窗。已有脚本时直接运行第二行。下载地址固定到 `v0.1.0`，便于核对版本。

## 恢复和查看状态

恢复原样：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 restore
```

只查看状态，不修改文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 status
```

没有安装信息或安装了多份 SQLyog 时，指定程序路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 apply -Path 'D:\SQLyog\SQLyogCommunity.exe'
```

`apply`、`restore` 可重复执行。省略操作时默认为 `status`。`ExecutionPolicy Bypass` 仅对这次 PowerShell 进程生效，不修改系统执行策略。

## 支持版本

支持以下 **官方社区版的 64 位 EXE**，共八个发布版本：

| 系列 | 已验证版本 |
| --- | --- |
| 13.1 | 13.1.6、13.1.7、13.1.8、13.1.9 |
| 13.2 | 13.2.0、13.2.1 |
| 13.3 | 13.3.0、13.3.1 |

不支持 32 位、商业版、13.1.5 及更早版本、自行编译版或其他存在额外改动的文件。版本号相同也必须通过完整文件校验；不匹配时停止操作。

## 备份与更新

首次应用前，在 SQLyog 程序旁创建 `SQLyogCommunity.exe.exit-popup-backup-版本号`，例如 `SQLyogCommunity.exe.exit-popup-backup-13.3.1`。

已有备份不会被覆盖，内容不匹配时会停止。升级 SQLyog 后需重新应用；新版本使用单独的备份，旧版备份保留。恢复会核对当前程序并还原一个字节，不依赖备份文件，建议仍保留备份。

## 桌面版

从 [Releases](https://github.com/Karmeston/sqlyog-no-popup/releases) 下载 `SQLyogExitPopupTool.zip`，解压后运行 `SQLyogExitPopupTool.exe`，点击“去掉弹窗”或“恢复原样”。请保持 EXE 和 `sqlyog-no-popup.ps1` 在同一目录。

桌面版需要 .NET Framework 4.5 或更新版本，调用同一份脚本。命令行用户只需下载脚本。

## 常见问题

**提示关闭 SQLyog？** 关闭所有 SQLyog 社区版窗口后重试。

**提示没有权限？** 程序目录可能受保护，以管理员身份打开 PowerShell 后重试。

**提示文件不支持？** 请核对版本和位数。工具只接受已验证的官方文件，以及仅应用了本工具补丁的文件。

**保存查询、连接关闭会受影响吗？** 修改目标是退出推广弹窗函数。按官方源码的调用顺序，查询保存、取消退出、连接关闭和会话保存仍执行原有逻辑。已实测 13.3.0、13.3.1 未连接数据库时的退出；已连接会话和未保存查询的判断来自源码分析，未做交互测试。

## 开发与验证

补丁逻辑只在 [`sqlyog-no-popup.ps1`](sqlyog-no-popup.ps1) 中；桌面源码在 [`desktop/`](desktop/SQLyogExitPopupTool.cs)。不读取数据库配置或密码，补丁运行时不联网。

在项目目录运行以下命令，编译桌面版并生成发布文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

产物位于 `dist/`：独立脚本、桌面 ZIP 和 `SHA256SUMS.txt`。使用 Windows .NET Framework 自带的编译器，无需安装 .NET SDK。

八个版本已验证补丁、备份、恢复和重复操作；13.3.0、13.3.1 另完成真实界面的“原版有弹窗 → 补丁后无弹窗正常退出 → 恢复后重新出现”对照。来源、完整哈希、测试范围和原理见 [验证说明](docs/VALIDATION.md)。

## 许可证

工具采用 [MIT](LICENSE) 许可证。项目不包含 SQLyog 本体，不解锁商业版功能，与 Webyog 无隶属关系。
