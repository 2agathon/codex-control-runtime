---
title: "Codex native pipe or Computer Use Sky runtime unavailable"
---

# Native pipe or Sky runtime is unavailable

This failure occurs **after** the task has an execution tool and the bundled client begins initialization, but before the Windows control backend becomes reachable. It is therefore different from a missing plugin and from missing task injection.

## What to verify

- Confirm the current packaged Computer Use runtime has a matching healthy relocated runtime.
- Check the desktop relocation/helper logs for the first copy or helper-path error.
- Treat named-pipe absence as neutral when no control task is active; a live pipe is not expected at all times.

Do not manufacture a private helper protocol, guess a runtime hash directory, or use shell UI automation to claim Computer Use passed. A fallback action and an official runtime acceptance result are separate facts.

Next step: run the Doctor with `-Deep`, then consult the [July runtime recovery case](https://github.com/2agathon/codex-control-runtime/blob/main/cases/2026-07-12-runtime-recovery.md).
