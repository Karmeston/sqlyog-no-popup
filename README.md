# SQLyog No Popup

去掉 **SQLyog 社区版退出时的推广弹窗**。

一个 PowerShell 脚本，无需安装、无需编译、无需常驻运行，支持恢复原样。

## 使用

先关闭 SQLyog，在 **Windows PowerShell 5.1** 中运行：

```powershell
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Karmeston/sqlyog-no-popup/v0.1.1/sqlyog-no-popup.ps1' -OutFile sqlyog-no-popup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 apply
```

第一行下载，第二行应用。也可以从 [Releases](https://github.com/Karmeston/sqlyog-no-popup/releases) 下载脚本。

工具自动寻找安装位置。找不到或安装了多份时，用 `-Path` 指定程序：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 apply -Path 'D:\SQLyog\SQLyogCommunity.exe'
```

## 恢复

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 restore
```

查看状态，将 `restore` 换成 `status`。手动指定安装位置时，恢复也加上相同的 `-Path`。

## 支持版本

支持官方 **64 位社区版**：

- 13.1.6、13.1.7、13.1.8、13.1.9
- 13.2.0、13.2.1
- 13.3.0、13.3.1

其他版本或存在额外改动的程序会停止操作。

## 说明

- 首次应用会在程序旁保留原版备份，不覆盖已有备份。
- 应用和恢复可重复执行；升级 SQLyog 后需重新应用。
- 提示没有权限时，以管理员身份打开 PowerShell 后重试。

## 许可证

[MIT](LICENSE)。非官方工具，不包含 SQLyog 本体，不解锁商业版功能。
