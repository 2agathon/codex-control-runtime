# Diagnostic model

This file is the repository's sole normative source for diagnostic layer order, required evidence, local Doctor gates, and first-broken-gate decisions. Other documents may link to these rules but must not redefine them.

## Layers

按下面顺序查第一处断点，不从最终症状倒推单一原因：

1. **Host context**：消息来自 Codex、ChatGPT、ChatGPT Classic 还是 Chrome sidebar；宿主不同可能意味着不同任务路由和 app-server。
2. **Account and workspace**：套餐、rollout、workspace policy、角色和插件权限；本地文件无法证明这一层。
3. **Task tool injection**：新 task 是否实际获得 `mcp__node_repl__js`，而不只是读到了 skill 文档。
4. **Bundled client trust**：绝对路径 import 的 `browser-client.mjs` 或 `computer-use-client.mjs` 是否通过宿主信任校验。
5. **Local bridge**：Chrome Native Messaging、app-server v2 manifest、`resourcesPath`、CLI/Node 路径或 Windows native pipe 是否健康。
6. **Backend initialization**：`agent.browsers.get("iab")`、`agent.browsers.get("extension")` 或 Computer Use Sky runtime 是否成功初始化。
7. **Target behavior**：网站导航、DOM、权限、反自动化或目标 App 行为；只有前六层已通过才进入这一层。

## Evidence rule

一次验收至少保留：

- 发起消息的宿主与账号/workspace 标签；
- 实际 server/tool 名；
- import 的 client 绝对路径和插件版本；
- backend/runtime 名；
- 第一处原始错误；
- 是否使用过 fallback；
- 用户可观察到的结果。

用户亲眼观察到动作发生时，应承认动作发生；但没有官方调用记录时，不得据此声称动作由官方 Computer Use 或 Chrome plugin 完成。

## Decision rule

Doctor 状态门槛统一为：

- `PASS`：允许进入全部三项 Level 1 验收。
- `ATTENTION`：先逐项解释 `WARN/UNKNOWN`；只允许验收明确不受该项影响的 capability，并在记录中写明理由，不能称“整体通过”。
- `FAIL`：停止能力验收，先处理失败的本地层。

```text
Doctor FAIL
  -> 只修失败的本地层，再跑 Doctor

Doctor PASS, new task lacks mcp__node_repl__js
  -> 停止本地修复，检查宿主、账号/workspace 与任务路由

node_repl exists, bundled client init fails
  -> 保留第一处 raw error，检查 trust/native pipe/backend，不使用替代工具覆盖失败

official backend initialized, one target fails
  -> 进入目标网站或 App 层，不回头重装插件
```
