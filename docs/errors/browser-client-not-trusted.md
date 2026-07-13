---
title: "browser-client is not trusted in Codex"
---

# `browser-client is not trusted`

This error means the client file was found and imported from a context that did not receive the privileged browser bridge expected by the bundled plugin. A normal Node process, standalone Playwright session, or unrelated MCP is not equivalent to the trusted desktop-host path.

## What to verify

- Select the client from the current installed `openai-bundled` plugin version, not an older cache path.
- Import it through the execution tool named by the current bundled skill.
- Keep the first initialization error; do not hide it by switching to another browser backend.

Do not patch the client's trust check or launch it from ordinary PowerShell merely to make the error disappear. That would change the mechanism being tested.

Next step: follow the [client-selection rule and strict acceptance protocol](https://github.com/2agathon/codex-control-runtime/blob/main/protocol/capability-acceptance.md).
