# 2026-07-12 redacted evidence excerpt

这份材料从当日 task execution record 与本机诊断结果转录而来，去掉了机器身份、私有任务标识与页面私密内容。原始 task 保存于原账号环境，没有随本目录打包；因此这里能支持链路形状和错误序列审计，但不是可独立校验的原始 JSON，也不是密码学证明。

## Chrome acceptance excerpt

```yaml
trace_visibility: reported-only
provenance: transcribed
server: node_repl
tool: js
client: openai-bundled/chrome/26.707.31428/scripts/browser-client.mjs
setup: setupBrowserRuntime
backend: extension
operations:
  - browser.user.openTabs
  - browser.user.claimTab
  - tab.goto https://example.com/
observed_title: Example Domain
fallback_used: false
result: REPORTED
evidence_verdict: pass-as-recorded
```

## Computer Use failure excerpt before runtime recovery

```yaml
trace_visibility: reported-only
provenance: transcribed
server: node_repl
tool: js
client: openai-bundled/computer-use/26.707.31428/scripts/computer-use-client.mjs
setup: setupComputerUseRuntime
first_raw_error: Windows Computer Use Sky runtime is unavailable
fallback_used: false
result: REPORTED
evidence_verdict: fail-as-recorded
```

## Computer Use cold-start excerpt after runtime recovery

```yaml
trace_visibility: reported-only
provenance: transcribed
server: node_repl
tool: js
client: openai-bundled/computer-use/26.707.31428/scripts/computer-use-client.mjs
backend: Sky Windows runtime
reported_operations:
  - list_apps
  - Notepad text input
native_pipe: codex-computer-use-* present after restart
fallback_used: false
result: REPORTED
evidence_verdict: pass-as-recorded
```

`list_apps` 是当日记录中的 operation label；本目录没有保存当时 Sky API documentation 的完整返回，不能保证它在未来版本仍是准确方法名。

## Local runtime correlation

- packaged runtime 与 relocated runtime 的文件数和总字节数在恢复后精确匹配；
- `node.exe`、`node_repl.exe`、Sky module 与 `codex-computer-use.exe` 均存在；
- 完整重启后 `codex-computer-use-*` pipe 出现；
- 同期历史任务记录把 Chrome 严格验收记为 `pass-as-recorded`，缩小了账号或整机完全无资格的解释范围；本摘录不把该转录升级为直接 `PASS`。

这组证据支持“runtime relocation failure 是本次 Sky/native-pipe failure 的上游原因”的强因果判断，但不证明 OpenAI 所有 Windows 设备上的同类症状都来自同一原因。
