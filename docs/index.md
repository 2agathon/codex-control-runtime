---
title: Codex Control Runtime Observatory
---

# Codex Control Runtime Observatory

**A green toggle is not end-to-end proof.** This independent Windows lab separates visible plugin state from a runtime that is actually callable through the bundled OpenAI control chain.

[Run the read-only Doctor](https://github.com/2agathon/codex-control-runtime#30-second-orientation) · [Submit a sanitized report](https://github.com/2agathon/codex-control-runtime/issues/new?template=runtime-report.yml) · [Read the acceptance protocol](https://github.com/2agathon/codex-control-runtime/blob/main/protocol/capability-acceptance.md)

## Find the first error you actually observed

| Exact symptom | What this page helps distinguish |
| --- | --- |
| [`Computer Use plugins unavailable`](errors/computer-use-plugins-unavailable.html) | UI availability versus bundled runtime relocation |
| [`mcp__node_repl__js` is missing](errors/node-repl-tool-missing.html) | Plugin visibility versus per-task tool injection |
| [`browser-client is not trusted`](errors/browser-client-not-trusted.html) | A readable plugin file versus a privileged host import |
| [`native pipe` or Sky runtime unavailable](errors/native-pipe-unavailable.html) | Tool injection versus the Windows control backend |
| [`resourcesPath` missing or stale](errors/chrome-resources-path-missing.html) | A connected extension versus an outdated app-server manifest |
| [`bundled_executable_relocation_failed`](errors/bundled-executable-relocation-failed.html) | A surface error versus protected-package copy failure |

## The five gates

1. **Product availability:** account, workspace, host app, and rollout permit the capability.
2. **Task injection:** the fresh task receives the execution tool required by the current bundled skill.
3. **Client trust:** the selected bundled client initializes through the privileged host.
4. **Local bridge:** Native Messaging, app-server manifests, or Windows runtime relocation are healthy.
5. **Strict acceptance:** the expected backend performs one harmless read-only operation with no fallback.

The Doctor covers locally inspectable state. It cannot prove account eligibility, workspace policy, rollout, or per-task injection; those require the [strict three-task acceptance protocol](https://github.com/2agathon/codex-control-runtime/blob/main/protocol/capability-acceptance.md).

## Privacy model

There is no backend service and no automatic upload. Runtime snapshots stay on the machine until the user chooses to share them. Use the repository's redaction script, inspect the output, and attach only the public copy to an issue.

This project is not affiliated with or endorsed by OpenAI. Internal filenames and tool IDs are version-specific observations, not promises of a stable public API.
