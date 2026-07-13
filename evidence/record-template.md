# Capability run record template

这个模板用于保存一次新 task 的脱敏验收记录。它不要求某个固定 UI 导出功能，因为不同桌面版本的 trace 可见性可能不同。

## Capture procedure

1. 保存实际发送的验收 prompt、宿主 App、账号标签、workspace 标签和 Chrome profile 标签。
2. 若 task UI 显示 tool-call 卡片或 execution details，展开并逐字记录 server/tool、client path、backend、operation 与第一处 raw error。
3. 若 UI 不暴露 raw tool call，只能依赖 task 自报字段，把 `trace_visibility` 标成 `reported-only`；不能把它归为直接观察。
4. 标记是否出现 fallback。只要用了禁止的替代控制面，该项官方验收即失败，即使目标动作发生。
5. 删除机器名、Windows 用户名、SID、cookie、token、页面私密内容和无关标签页信息后再公开。

## Record

```yaml
run_id: RUN-ID
host_app: Codex | ChatGPT | ChatGPT Classic | Chrome sidebar
account_label: ACCOUNT-LABEL
workspace_label: WORKSPACE-LABEL
chrome_profile_label: PROFILE-LABEL | not-applicable
capability: Browser | Chrome | Computer Use
prompt_file: protocol/capability-acceptance.md
desktop_version: VERSION
plugin_version: VERSION
trace_visibility: direct-tool-card | exported-task-record | reported-only
provenance: direct | exported | transcribed | self-reported
server: SERVER
tool: TOOL
client_path: ABSOLUTE-PATH-WITH-IDENTITY-REDACTED
backend_or_runtime: BACKEND
operation: OPERATION
result: PASS | FAIL | NOT-COVERED | REPORTED
first_raw_error: null | RAW-ERROR
fallback_used: true | false
user_observed_result: OBSERVATION
notes: NOTES
```

结果判定按以下优先级执行：

1. `fallback_used: true` 时一律填写 `result: FAIL`，包括 `trace_visibility: reported-only`；仍应在 `user_observed_result` 记录目标动作是否发生。
2. 没有禁止的 fallback 且 `trace_visibility: reported-only` 时，只能填写 `result: REPORTED`，不能填写 evidentiary `PASS`。
3. 只有直接可见 tool card、导出的 task record，或按相同条件完成且记录可见的独立复验才能填写 `PASS`。

`client_path` 只脱敏机器身份、盘符或 Windows 用户目录，不得抹掉用于判断官方链路的结构。公开记录至少保留 `openai-bundled`、capability、version 与 client suffix，例如 `IDENTITY-REDACTED\.codex\plugins\cache\openai-bundled\chrome\26.707.31428\scripts\browser-client.mjs`。
