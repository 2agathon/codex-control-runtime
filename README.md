# Codex Control Runtime Lab

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D4.svg)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE.svg)](https://github.com/PowerShell/PowerShell)

> **Installed is not callable. Connected is not verified.**
>
> This lab identifies the first broken gate in the official Codex Browser, Chrome, and Computer Use chains on Windows, without silently substituting Playwright, shell automation, or another browser MCP.

## 30-second orientation

| What you see | Start here |
| --- | --- |
| `Computer Use plugins unavailable` | [Exact-error guide](https://2agathon.github.io/codex-control-runtime/errors/computer-use-plugins-unavailable.html) |
| `mcp__node_repl__js` is missing | [Exact-error guide](https://2agathon.github.io/codex-control-runtime/errors/node-repl-tool-missing.html) |
| `browser-client is not trusted` | [Exact-error guide](https://2agathon.github.io/codex-control-runtime/errors/browser-client-not-trusted.html) |
| Native pipe or Sky runtime is unavailable | [Exact-error guide](https://2agathon.github.io/codex-control-runtime/errors/native-pipe-unavailable.html) |
| `resourcesPath` is missing or stale | [Exact-error guide](https://2agathon.github.io/codex-control-runtime/errors/chrome-resources-path-missing.html) |
| `bundled_executable_relocation_failed` | [Exact-error guide](https://2agathon.github.io/codex-control-runtime/errors/bundled-executable-relocation-failed.html) |

Run the read-only Doctor from a cloned checkout:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -Deep -SaveSnapshot
```

For unattended recovery from known local drift, register the allowlisted Auto-Heal service. It checks at logon and every ten minutes, backs up mutable manifests, repairs only recognized local gates, and never force-closes Codex. It prefers a limited scheduled task and falls back to a current-user startup daemon when Task Scheduler registration is denied:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Register-CodexRuntimeGuardAutoHeal.ps1"
```

The separate read-only Monitor remains available for machines where automatic mutation is not allowed.

The Doctor does not upload telemetry. Before attaching a result publicly, create a redacted copy:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Export-CodexRuntimeGuardSnapshot.ps1" -InputPath ".\path\to\snapshot.json"
```

Browse the zero-backend troubleshooting site at [2agathon.github.io/codex-control-runtime](https://2agathon.github.io/codex-control-runtime/), or [submit a sanitized runtime report](https://github.com/2agathon/codex-control-runtime/issues/new?template=runtime-report.yml). GitHub Pages hosts the site directly from this repository; there is no server, database, account system, or telemetry collector behind it.

## English

**Codex Control Runtime Lab** is a field-tested diagnostic and acceptance toolkit for OpenAI Codex Browser, Chrome, and Computer Use on Windows. It helps distinguish a plugin that merely appears installed from an end-to-end runtime that is actually callable.

The lab covers the failure boundaries that generic reinstall advice misses:

- task-level `mcp__node_repl__js` injection;
- bundled client selection and trust;
- Chrome Native Messaging and extension-host state;
- Windows Sky / Computer Use runtime relocation;
- read-only capability acceptance with explicit no-fallback evidence;
- app update, account, workspace, host app, Chrome profile, reinstall, and device-change scenarios.

Start with the read-only Doctor:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -Deep -SaveSnapshot
```

Then use [`protocol/capability-acceptance.md`](protocol/capability-acceptance.md) in three fresh Codex tasks. A green settings page or a connected extension is not treated as proof. The execution record must identify the expected server, tool, bundled client, backend, and whether any fallback occurred.

This is an independent community experiment, not an OpenAI product or official support procedure. Repair mode is dry-run by default. Historical case files contain commands that must not be replayed blindly; follow the current runtime-guard manual instead. Before sharing a snapshot or issue report, use [`evidence/record-template.md`](evidence/record-template.md) and remove machine names, SIDs, tokens, cookies, private tab data, and user-specific paths.

## 中文

这是一个研究 Codex 官方控制能力如何从桌面宿主抵达真实运行时的实验。对象不是某个网站，也不只是 Computer Use，而是三条可独立验收的官方链路：

```text
Codex / ChatGPT desktop host
  -> account, workspace, and task routing
    -> mcp__node_repl__js
      -> Browser / Chrome / Computer Use client
        -> in-app backend / Native Messaging / Windows Sky runtime
          -> observable control result
```

## 实验问题

1. Browser、Chrome 与 Computer Use 在什么条件下真正可用，而不只是“插件已安装”？
2. App 更新、账号或 workspace 切换、宿主切换、Chrome profile 切换、重装和换设备分别会改变哪一层？
3. 失败时能否保留第一处原始错误，并把本机漂移与服务端能力、任务路由分开？
4. 哪些本地状态可以确定性自愈，哪些未知 schema、账号资格或任务路由必须停止自动修改？

## 当前结论

- 设置页可见、插件启用、扩展显示 Connected，都不是端到端验收。
- `mcp__node_repl__js` 是三条官方链路共同的重要门，但它出现后仍可能在 Native Messaging、app-server manifest、Chrome profile 或 Windows Sky runtime 继续失败。
- “动作发生了”和“动作由官方 Computer Use 完成”必须分开取证。
- 外部 Playwright、Chrome DevTools MCP 与 `mcp_chrome` 是比较控制面，不能替代官方链路通过验收。
- 本地 Doctor 通过后，如果不同账号或 workspace 的严格验收结果不同，应停止修改本机文件，转查资格、策略、灰度或任务路由。

## 术语边界

本实验里的“官方链路”是一个**版本相关的操作性判据**：从当前安装的 `openai-bundled` 插件包读取其 skill 和 client，通过该包要求的 `mcp__node_repl__js` 入口初始化，并抵达它声明的 OpenAI Browser、Chrome extension 或 Windows Computer Use backend。它不表示这些内部文件名、MCP tool ID 或 backend ID 是 OpenAI 对外承诺的稳定 API；App 更新后必须重新读取当前 bundled skill 并复验。

## 权威来源

为避免同一规则在 README、手册和历史复盘里各自漂移，本仓库按对象指定唯一权威来源：

| 对象 | 唯一权威来源 |
| --- | --- |
| 分层顺序、证据字段、`PASS / ATTENTION / FAIL` 门槛与第一断点决策 | [`protocol/diagnostic-model.md`](protocol/diagnostic-model.md) |
| 三项 Level 1 验收词与通过条件 | [`protocol/capability-acceptance.md`](protocol/capability-acceptance.md) |
| Doctor、Repair、Monitor 与 Auto-Heal 的实际行为 | [`tools/runtime-guard/`](tools/runtime-guard/) 中的 PowerShell 实现 |
| 诊断快照的机器可读契约 | [`schemas/runtime-guard-report.schema.json`](schemas/runtime-guard-report.schema.json) |
| 事故经过、旧命令与当时判断 | `cases/`，仅作历史证据，不作当前操作说明 |

## 入口

| 路径 | 用途 |
| --- | --- |
| [`protocol/capability-acceptance.md`](protocol/capability-acceptance.md) | 三个新 task 的严格官方链路验收词 |
| [`protocol/diagnostic-model.md`](protocol/diagnostic-model.md) | 分层诊断模型与第一断点规则 |
| [`protocol/scenario-matrix.md`](protocol/scenario-matrix.md) | 更新、换号、换宿主、重装与换设备实验矩阵 |
| [`protocol/support-matrix.md`](protocol/support-matrix.md) | 已验证环境与未覆盖边界 |
| [`tools/runtime-guard/README.md`](tools/runtime-guard/README.md) | 只读诊断、快照比较与受控修复手册 |
| [`cases/2026-06-05-efs-and-package-state.md`](cases/2026-06-05-efs-and-package-state.md) | **HISTORY ONLY**：6 月 EFS、Marketplace 与 package/cache 现场 |
| [`cases/2026-07-12-runtime-recovery.md`](cases/2026-07-12-runtime-recovery.md) | **HISTORY ONLY**：7 月多层故障重建与恢复证据 |
| [`references/control-surfaces.md`](references/control-surfaces.md) | 官方控制面与替代控制面的边界 |
| [`references/official-sources.md`](references/official-sources.md) | 当前采用的官方资料入口 |
| [`evidence/record-template.md`](evidence/record-template.md) | 新 run 的脱敏执行记录模板 |
| [`evidence/2026-07-12-redacted-trace.md`](evidence/2026-07-12-redacted-trace.md) | 本次历史恢复随包携带的证据摘录及强度限制 |
| [`schemas/runtime-guard-report.schema.json`](schemas/runtime-guard-report.schema.json) | Doctor 诊断快照的 JSON Schema |
| [`docs/index.md`](docs/index.md) | 零后端精确报错索引与公开入口 |

## 快速基线

在本工作区根目录运行：

```powershell
pwsh -NoProfile -File ".\lab\codex-control-runtime\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -Deep -SaveSnapshot
```

如果只拿到本实验目录，可从目录根运行：

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -Deep -SaveSnapshot
```

脚本向上查找最近的 `.ai`：找到时写入其 `state/codex-runtime-guard/`；独立运行时写入 `%LOCALAPPDATA%\OpenAI\CodexControlRuntimeLab\state\codex-runtime-guard\`。也可用 `-OutputDirectory` 显式指定。快照包含机器名、Windows 用户 SID、安装路径和 Chrome profile 目录名，不应未经脱敏公开。

Doctor 为 `PASS` 后，仍必须按 [`capability-acceptance.md`](protocol/capability-acceptance.md) 在三个新 task 验收。`ATTENTION` 先逐项定界，`FAIL` 不进入能力验收；统一门槛见 [`diagnostic-model.md`](protocol/diagnostic-model.md)。文字声称成功不算证据，执行记录必须出现指定 server、tool、client path 与 backend。

## 边界

这里保存实验协议、诊断工具、脱敏样例、关键 case 与判断依据；不保存完整聊天转录、浏览器 cookies、登录令牌、真实 Chrome 内容或机器快照。当前工作区另有 `.ai` 容器，但它不随本目录交付，也不是运行本实验的前提；独立运行时机器状态写入上面的 `%LOCALAPPDATA%` 目录。

修复默认 Dry Run。可选 Auto-Heal 只处理报告中明确标为 repairable 的本地漂移：Chrome 活动入口、Native Messaging、v2 manifest `resourcesPath`，以及可由当前 App 源文件内容确定性计算 ID 的 Computer Use runtime。它不修改账号、workspace 或任务工具注入，也不会强制关闭正在工作的 Codex。只读 Monitor 仍保留用于审计环境。

## License

[MIT](LICENSE). This repository is an independent community project and is not affiliated with or endorsed by OpenAI.
