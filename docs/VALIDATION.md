# 验证与实现说明

## 已验证的内容

- 八个官方社区版 x64 EXE：13.1.6、13.1.7、13.1.8、13.1.9、13.2.0、13.2.1、13.3.0、13.3.1。
- 每版均验证原版识别、精确补丁后哈希、原版备份、补丁版识别、重复应用、精确恢复及重复恢复。
- 另验证未知文件、额外修改、冲突备份、锁定文件、只读文件及正在运行的 SQLyog 会被拒绝；官方升级后可使用新版本的独立备份。
- 桌面界面的脚本调用、按钮状态，以及包含空格、中文和 `$` 的路径。
- 对 13.3.0、13.3.1 运行真实 SQLyog 界面：原版有推广弹窗，补丁后无弹窗退出且退出码为 0，恢复后弹窗重新出现。

实际退出使用独立程序副本和 `-dir` 隔离配置，未连接数据库。测试前后核对，本机安装的 EXE 和已有连接配置未改变。

官方文件来源、安装包与程序哈希、补丁后哈希、函数字节及位置见 [`verified-builds.json`](verified-builds.json)。测试与本机性能采样见 [`validation-report.json`](validation-report.json)。历史记录中的 v1、v2 指开发过程中的实现，不是 SQLyog 版本。

## 修改方式

每个版本只修改一个字节：将 `ConnectionCommunity::OnClose()` 的函数入口由 `48` 改为 `C3`，使该函数立即返回。恢复执行相反修改。

八个官方安装包从 [官方 Wiki 历史记录](https://github.com/webyog/sqlyog-community/wiki/Downloads/_history) 提供的官方 S3 链接下载并解包，未运行安装程序。核对了 x64 架构、唯一函数位置、函数边界、完整 67 字节指令及 `DialogBoxParamW` 导入调用。八个版本的目标函数逻辑一致，只有地址不同。

运行时以文件大小确定候选位置，将内存中的入口字节暂时归一化为原值，再计算完整 SHA-256。完整哈希必须匹配已验证的官方原版，因此只能接受原版或仅改变目标字节的补丁版。即使版本资源相同，存在其他改动也会被拒绝。

应用或恢复时独占文件，写一个字节并刷盘、回读确认。写入异常时尝试回退。没有运行时扫描、反汇编、版本资源解析或网络请求。主流程只使用一份约 7 MB 的文件缓冲和一次完整哈希，已有备份另行核对。

## 未保存查询与已连接会话

官方源码的退出调用顺序为：会话保存、关闭查询窗口及连接、推广弹窗、程序收尾。查询保存失败或选择取消、查询仍在执行等情况，会在广告函数之前中止退出。

- [`FrameWindow::OnWmClose()`](https://github.com/webyog/sqlyog-community/blob/master/src/FrameWindow.cpp)：先保存会话并关闭子窗口，允许退出后才调用广告函数。
- [`TabEditor::OnTabClosing()`](https://github.com/webyog/sqlyog-community/blob/master/src/TabEditor.cpp)：按原有设置处理保存提示，取消或保存失败会阻止关闭。
- [`MDIWindow::OnWmClose()`](https://github.com/webyog/sqlyog-community/blob/master/src/MDIWindow.cpp)：处理正在执行的查询和数据库连接关闭。
- [`ConnectionCommunity::OnClose()`](https://github.com/webyog/sqlyog-community/blob/master/src/ConnectionCommunity.cpp)：只设置广告标记并显示推广窗口。

因此，按源码分析，补丁不会绕过原有保存或连接清理流程；正常退出仍会去掉推广弹窗。这是静态分析结论，已连接会话和未保存查询未做交互测试。未注入磁盘写入故障验证自动回退分支。

性能数字包含启动全新 Windows PowerShell 进程的时间，使用五次采样的中位数，不能视为所有电脑的速度保证。
