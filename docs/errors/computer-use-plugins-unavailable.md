---
title: "Computer Use plugins unavailable on Windows"
---

# `Computer Use plugins unavailable` on Windows

This settings message is a **surface symptom**, not a root-cause label. It can appear when the bundled plugin is absent or incomplete, when protected AppX files were not relocated into a runnable user directory, or when product availability is not granted to the current account, workspace, or host app.

## Establish the first broken gate

1. Run the [read-only Doctor](https://github.com/2agathon/codex-control-runtime#30-second-orientation).
2. If the Doctor reports a local `FAIL`, inspect that check before changing account or browser settings.
3. If the Doctor passes but a fresh strict task lacks the required execution tool, stop repairing local files and investigate account, workspace, rollout, or task routing.

Do not assume that another machine showing the same UI text has the same root cause. Do not copy a historical repair command until the current version produces the same underlying evidence.

Evidence boundary: the lab's June case linked this symptom to protected-package copy failures on one machine; it does not claim that all instances share that cause. See the [June case](https://github.com/2agathon/codex-control-runtime/blob/main/cases/2026-06-05-efs-and-package-state.md) and [diagnostic model](https://github.com/2agathon/codex-control-runtime/blob/main/protocol/diagnostic-model.md).
