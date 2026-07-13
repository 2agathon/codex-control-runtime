---
title: "mcp__node_repl__js missing in Codex"
---

# `mcp__node_repl__js` is missing

When a bundled Browser, Chrome, or Computer Use skill is visible but a fresh task cannot call the execution tool required by that skill, the failure is at the **task-injection gate**. Plugin files on disk do not prove that a task received their callable runtime surface.

## What to verify

- Use a fresh task after an app or plugin restart; older tasks may retain their original tool set.
- Record the host app, account/workspace, task source, and exact bundled plugin version.
- Compare two accounts or workspaces only after the local Doctor reports the same healthy machine state.

Reinstalling Chrome, rewriting Native Messaging manifests, or enabling an unrelated MCP cannot create a per-task tool assignment. A substitute tool may complete the visible action, but it does not pass official-chain acceptance.

Next step: run the [strict capability acceptance prompts](https://github.com/2agathon/codex-control-runtime/blob/main/protocol/capability-acceptance.md) and preserve the first raw error.
