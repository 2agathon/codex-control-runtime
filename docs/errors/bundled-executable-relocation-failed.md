---
title: "bundled_executable_relocation_failed in Codex for Windows"
---

# `bundled_executable_relocation_failed`

This log signal means Codex failed while copying or staging a bundled executable/runtime from its packaged WindowsApps source into the user-local runtime area. Higher-level messages such as missing helper paths, missing runtime files, or Computer Use unavailability may be downstream effects.

## What to verify

- Preserve the exact source, destination, operation, and Windows error from the desktop logs.
- Compare packaged and relocated runtime manifests, file counts, and required executables.
- Check whether the failure repeats on an ordinary packaged file, not only on the final executable.

Do not infer that EFS is the cause from the error name alone. Do not recursively decrypt, copy, or replace protected package contents without matching evidence and a rollback plan.

Next step: use the [June package-state case](https://github.com/2agathon/codex-control-runtime/blob/main/cases/2026-06-05-efs-and-package-state.md) as a comparison case, not a universal repair recipe.
