# Scenario matrix

每次实验只改变一个主要变量。先保存 before snapshot，事件发生后保存 after snapshot，再运行三个新 task 的严格验收。

| Scenario | 主要变量 | 本地状态预期 | 必须重验 |
| --- | --- | --- | --- |
| App update | AppX、resources、bundled plugin/runtime | 可能改变 | Doctor + 三项能力 |
| Same Windows user, switch account | account entitlement/rollout | 应稳定 | 账号标签 + 三项能力 |
| Switch Personal/Business workspace | workspace policy/role | 应稳定 | workspace 标签 + 三项能力 |
| Switch Codex/ChatGPT/Classic host | host routing/app-server | 可能改变 | 记录宿主 + 三项能力 |
| Switch Chrome profile | extension/profile permission | 共享 runtime，profile 不同 | Chrome 验收 |
| Reinstall same Windows user | AppX 与遗留 `.codex` 混合状态 | 不可预设 | Doctor + 三项能力 |
| New Windows user | HKCU、LocalAppData、profile 全新 | 新本地上下文 | 下述 bootstrap |
| New device | 只有服务端账号状态继承 | 新本地上下文 | 下述 bootstrap |

## Bootstrap for a new local context

1. 运行 `pwsh --version`，记录实际版本；没有 `pwsh` 或环境不在 [`support-matrix.md`](support-matrix.md) 时标记 `NOT-COVERED`，不要假定脚本兼容。
2. 安装受支持的 Store/MSIX Codex 桌面 App，并记录宿主与版本。
3. 登录目标 ChatGPT 账号和 workspace；若使用 Chrome，同时确认 Chrome sidebar 登录身份。
4. 在目标 Chrome profile 安装并授权 ChatGPT Chrome extension。当前基线扩展 ID 是 `hehggadaopoacecdllhhajmbjkdcmajg`，但它不是永久常量；在 `chrome://extensions` 的扩展详情以及 `%LOCALAPPDATA%\OpenAI\extension\com.openai.codexextension.json` 的 `allowed_origins` 中交叉确认当前 ID。
5. 从实验目录根运行 `pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -Deep -SaveSnapshot`。
6. Doctor 为 `PASS` 后，在三个新 task 运行 [`capability-acceptance.md`](capability-acceptance.md)。`ATTENTION` 必须先按 [`diagnostic-model.md`](diagnostic-model.md) 逐项定界，`FAIL` 不进入验收。
7. 按 [`../evidence/record-template.md`](../evidence/record-template.md) 保存脱敏基线。

## Snapshot labels

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -SaveSnapshot `
  -AccountLabel "ACCOUNT-A" -WorkspaceLabel "WORKSPACE-A"
```

标签只用于比较，不证明真实登录身份。Chrome sidebar 和桌面 App 可能登录不同账号，切换时必须分别人工确认。

## Interpretation

- `NEW_LOCAL_CONTEXT`：按新设备或新 Windows 用户初始化，不归因于账号。
- `LOCAL_STATE_CHANGED`：先检查 changed checks，不先讨论 entitlement。
- `ACCOUNT_CHANGED_LOCAL_STABLE`：若严格验收不同，优先调查账号/workspace/任务路由。
- `NO_RELEVANT_CHANGE`：若结果仍不同，检查消息宿主、Chrome profile 和 task execution record。
