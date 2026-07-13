# Support matrix

## Verified baseline

本实验当前只在以下组合完成过 Doctor、自测与官方链路验收：

| Dimension | Verified value |
| --- | --- |
| OS | Windows 11 Pro x64, build 26200 |
| Shell | PowerShell 7.5.8 |
| Desktop install | Microsoft Store/MSIX `OpenAI.Codex` x64 |
| Verified desktop version | `26.707.8168.0`，仅为本次基线，不是代码常量 |
| Chrome | Google Chrome stable，安装于 `C:\Program Files\Google\Chrome` |
| Chrome profile root | `%LOCALAPPDATA%\Google\Chrome\User Data` |
| Permissions | 普通用户上下文；读取 AppX/注册表/用户目录，修复必须显式 `-Apply` |

随本目录携带的历史 task evidence 范围：

| Capability | Bundled evidence status |
| --- | --- |
| Browser | 未随包提供独立 task trace；只能重新运行当前 Level 1 验收 |
| Chrome | 有 2026-07-12 人工转录的 Level 2 task record 摘录，证据级别为 `REPORTED` |
| Computer Use | 有失败前与恢复后的人工转录 task record 摘录，证据级别为 `REPORTED` |

三项当前状态都应以目标机器上的新 task Level 1 验收为准，不能由历史摘录继承。

Doctor 会动态发现 AppX 与 bundled plugin 版本，因此新版本不应因版本号不同直接失败。但“动态发现”不等于新版本已验证：schema、目录或 private client API 改变时应报告未覆盖并停止修复。

## Not yet covered

- 非 Store/MSIX 的 Codex 安装形态；
- Windows 10、ARM64、Server、受组织策略管理的设备；
- Chrome Beta/Dev/Canary、Chromium、Edge；
- 另一台物理设备上的确定性修复安全性；
- 无 `%LOCALAPPDATA%` 或受限 PowerShell 环境。

这些环境出现失败时，不应直接归类成现有机器故障。先记录安装渠道、包名、架构、浏览器 channel、profile root 和权限上下文，再决定是否扩展 Doctor。
