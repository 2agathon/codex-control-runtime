---
title: Submit a sanitized runtime report
---

# Submit a sanitized runtime report

Reports improve the compatibility picture only when they identify the tested version, first broken gate, and whether a fallback occurred. A settings screenshot alone is useful context but not an acceptance result.

## Prepare the report

1. Run the read-only Doctor with `-SaveSnapshot`.
2. Run `Export-CodexRuntimeGuardSnapshot.ps1` on the saved JSON.
3. Open the generated `.public.json` and inspect it before upload.
4. Run only the strict read-only acceptance task relevant to the failed capability.
5. Record the first raw error and any fallback separately.

[Open the structured report form](https://github.com/2agathon/codex-control-runtime/issues/new?template=runtime-report.yml).

Never attach cookies, tokens, private tab content, full browser history, private organization names, or an unreviewed raw snapshot.
