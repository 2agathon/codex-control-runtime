# Codex Runtime Guard

This tool is maintained as part of the [Codex Control Runtime Lab](../../README.md). The implementation in this directory is the sole source of truth for executable behavior; the canonical diagnostic gates and evidence rules live in [the diagnostic model](../../protocol/diagnostic-model.md). `.ai/operations/codex-runtime-guard/` contains compatibility shims only.

The `.ai/operations` shims belong to the original workspace and are not included when this experiment directory is distributed alone. They are not required to run the canonical scripts below.

`codex-runtime-guard` distinguishes Windows-local breakage from account/workspace capability differences for Codex Browser, the official Chrome extension, and Computer Use. It diagnoses by default. It repairs only deterministic local drift after an explicit `-Apply`.

It does not grant account entitlements, change workspace policy, bypass website approval, or prove that a particular task received its tools. Those require new-task acceptance.

## Quick start

From the experiment directory root:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -SaveSnapshot
```

From the original workspace root, the equivalent command is:

Run from PowerShell 7:

```powershell
Set-Location "D:\path\to\workspace"
pwsh -NoProfile -File ".\lab\codex-control-runtime\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -SaveSnapshot
```

Exit codes:

- `0`: all locally decidable checks passed.
- `1`: a non-fatal local warning exists.
- `2`: at least one local check failed.

Account/workspace capability remains a separate `acceptanceRequired` result and does not make an otherwise healthy local diagnosis exit nonzero.

Use `-Deep` to compare packaged and relocated runtime file counts and byte totals. It is slower and is intended for app updates or Computer Use runtime failures.

Labels are optional and never discovered from login tokens:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Diagnose -SaveSnapshot `
  -AccountLabel "personal-pro" -WorkspaceLabel "personal"
```

They exist only to make two snapshots comparable after an account or workspace switch.

Compare two snapshots:

```powershell
$before = "D:\path\to\before-snapshot.json"
$after = "D:\path\to\after-snapshot.json"
pwsh -NoProfile -File ".\tools\runtime-guard\Compare-CodexRuntimeSnapshots.ps1" -Before $before -After $after
```

`ACCOUNT_CHANGED_LOCAL_STABLE` means the machine-level fingerprint did not move. If strict acceptance differs, investigate account/workspace policy or task routing before touching local files. `LOCAL_STATE_CHANGED` and `NEW_LOCAL_CONTEXT` keep local drift and device/Windows-user changes visible.

The comparison fingerprint excludes live named-pipe counts because they change when tasks start and stop. Pipe names remain in each snapshot as evidence, but they do not turn ordinary task activity into a false local-state change.

## Optional update monitor

Run the monitor once without installing anything:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuardMonitor.ps1" -PassThru
```

The first run records a baseline. Later runs stay quiet unless the Codex AppX version, bundled Browser/Chrome/Computer Use versions, packaged `cua_node` archive version, or local Doctor status changes. On a change it saves a full local snapshot under `%LOCALAPPDATA%\OpenAI\CodexControlRuntimeLab\monitor\` and displays a Windows notification. It never calls Repair. An unchanged failure is not repeatedly notified; inspect the latest saved state if you intentionally ignored an earlier alert.

Register the monitor for the current Windows user at logon and daily at noon:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Register-CodexRuntimeGuardMonitor.ps1"
```

Remove it without deleting saved state:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Register-CodexRuntimeGuardMonitor.ps1" -Unregister
```

Registration is opt-in. The repository does not install a scheduled task by itself. The registration script copies the monitor and guard module to `%LOCALAPPDATA%\OpenAI\CodexControlRuntimeLab\monitor-bin\`, so the scheduled task does not depend on the checkout remaining at the same path. Re-run registration after pulling a newer guard implementation to refresh that deployed copy. Trigger times use the current Windows user's local time. Unregistering removes the task but deliberately preserves deployed files, state, and snapshots for inspection.

## Optional unattended Auto-Heal

Run Auto-Heal once without installing a task:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuardAutoHeal.ps1" -NoNotification -PassThru
```

Register it for the current Windows user at logon and every ten minutes:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Register-CodexRuntimeGuardAutoHeal.ps1"
```

Remove its startup registration without deleting its history:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Register-CodexRuntimeGuardAutoHeal.ps1" -Unregister
```

The registrar prefers a limited current-user scheduled task. If Windows denies task registration, it automatically installs an `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` entry and a `wscript.exe`-launched hidden single-instance daemon instead; this avoids Windows Terminal opening a visible PowerShell tab and needs no administrator approval. The deployed copy lives under `%LOCALAPPDATA%\OpenAI\CodexControlRuntimeLab\auto-heal-bin\`; state and append-only action history live under the adjacent `auto-heal\` directory. Auto-Heal and its daemon use per-user mutexes, so overlapping invocations do not race.

Auto-Heal applies only checks already marked `repairable` by the Doctor:

- stale or missing v2 manifest `resourcesPath` values;
- a missing/broken Chrome `latest` Junction with one unambiguous complete version;
- missing/broken Native Messaging registration through the bundled installer;
- a missing packaged-version `cua_node` relocation whose destination ID can be reproduced from the desktop app's content-hash algorithm.

WindowsApps can mark packaged runtime files as `Application Protected` EFS content. The CUA repair streams file contents into a staging directory instead of preserving source metadata, verifies required paths, key hashes, total file count, and total bytes, then atomically enables the content-addressed runtime. Existing runtime directories are never overwritten or deleted.

When Chrome state changes, Auto-Heal restarts only the matching `extension-host.exe`. When a CUA runtime is added while Codex is already running, it records `codexRestartRequired=true` and displays one notification; it never force-closes an active Codex task. Unknown schemas and non-repairable failures remain untouched and are recorded as `UNREPAIRED_FAILURE` or `REPAIR_INCOMPLETE`.

## What the Doctor checks

The report separates these layers:

1. Current `OpenAI.Codex` AppX version and `app\resources` path.
2. Installed `OpenAI.Codex` and `OpenAI.ChatGPT-Desktop` packages, so a host-app switch is not mistaken for an account-only switch.
3. Browser, Chrome, and Computer Use bundled plugin content.
4. Chrome `latest` Junction, Native Messaging registry, manifest, and extension host.
5. Both `chrome-native-hosts-v2.json` copies and every registered executable/path.
6. Packaged `cua_node` manifest and relocated runtimes with the same archive version.
7. Chrome profiles that contain the official extension ID.
8. Live Browser/Computer Use named pipes, treated as runtime evidence rather than a startup requirement.
9. Account/workspace capability, deliberately reported as unknown until official new-task acceptance runs.

The Doctor reads Chrome profile directory names and extension versions. It does not read Chrome history, cookies, page contents, login tokens, or email addresses.

Snapshots are local diagnostic artifacts. They contain the computer name, Windows account/SID, installed package paths, plugin paths, and Chrome profile directory names. Do not attach them to a public issue without redacting those fields.

Create a separate public copy without modifying the raw snapshot:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Export-CodexRuntimeGuardSnapshot.ps1" `
  -InputPath ".\path\to\snapshot.json"
```

The default output is `<snapshot-name>.public.json` beside the input. The exporter replaces the known identity fields, user-local path prefixes, Windows SID values, Chrome profile directory names, and secret-like properties while retaining versions, check IDs, statuses, and diagnostic messages. It refuses to overwrite either the raw input or an existing public copy unless `-Force` is explicit.

Redaction is a guardrail, not permission to upload blindly. Open the generated JSON and check it before attaching it to the [structured runtime report](https://github.com/2agathon/codex-control-runtime/issues/new?template=runtime-report.yml).

## Controlled repair

Always start with a dry run:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Repair
```

Apply only after every proposed action is understood:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Repair -Apply
```

Repair targets can be narrowed:

```powershell
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Repair -Target ResourcePaths
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Repair -Target ChromeLatest
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Repair -Target NativeHost
pwsh -NoProfile -File ".\tools\runtime-guard\Invoke-CodexRuntimeGuard.ps1" -Mode Repair -Target CuaRuntime
```

The repairer can:

- add missing or update stale `resourcesPath` values in the two v2 manifests when the matching entry still has a recognizable `paths` object;
- recreate a missing/broken Chrome `latest` Junction only when one complete newest version directory is unambiguous;
- invoke the bundled Chrome `installManifest.mjs` when Native Messaging registration is missing or broken.
- relocate the current packaged `cua_node` runtime using the desktop app's content-derived ID, metadata-free stream copy, staging, and post-copy verification.

Before modifying a v2 manifest, it writes a backup in a timestamped subdirectory under `%LOCALAPPDATA%\OpenAI\Codex\runtime-guard-backups`. A rewritten JSON file is parsed immediately; failed validation restores the backup.

The CUA destination ID is never guessed from an archive name or an old folder. It is recomputed from the same three source fingerprints used by the current desktop implementation: `manifest.json`, `bin/node.exe`, and `bin/node_repl.exe`. If those inputs, the packaged manifest, the Sky helper, or the expected destination state are ambiguous, repair refuses to proceed. The historical recovery and evidence standard are recorded in [the incident reconstruction](../../cases/2026-07-12-runtime-recovery.md).

## Required acceptance

A green local report does not prove service-side capability or per-task tool injection. After an update, account/workspace switch, reinstall, repair, or device move:

1. Completely exit Codex/ChatGPT and Chrome when the event changed local binaries or Native Messaging.
2. Start Codex/ChatGPT, then Chrome.
3. Create three new tasks using [the strict acceptance prompts](../../protocol/capability-acceptance.md).
4. Keep the task execution record. Do not accept a text-only success claim.

## Event playbook

| Event | What carries over | What must be revalidated |
| --- | --- | --- |
| App update, same Windows user/account | Account entitlement and Chrome profile usually remain | AppX paths, v2 manifests, plugin/runtime relocation, then all three tasks |
| Switch ChatGPT account in the same Windows user | Local AppX, plugin cache, registry, runtime, and Chrome profile are shared | Plan/rollout/workspace policy and fresh task injection |
| Switch Personal/Business workspace | Local state is unchanged | Workspace role, plugin/app policy, and fresh task injection |
| Switch between Codex, ChatGPT, or ChatGPT Classic desktop hosts | Account may be the same, but task routing and runtime registration may differ | Record the host used for each acceptance task; do not call it an account-only difference |
| Switch Chrome profile | Native host and local runtime are shared | Extension installation, connection, site permission, and Chrome acceptance in that profile |
| Reinstall on the same Windows user | Service entitlement remains; some `.codex` files may survive | Treat local state as mixed until Doctor and acceptance both pass |
| Use another Windows user | Almost no local state carries because HKCU, LocalAppData, `.codex`, and Chrome profiles are per-user | Bootstrap and validate as a new local installation |
| Move to another device | Only service-side account/workspace state carries | Install, Doctor, Chrome profile setup, and all acceptance tasks |

## Decision rule

Use the canonical [`PASS / ATTENTION / FAIL` and first-broken-gate rule](../../protocol/diagnostic-model.md#decision-rule). This manual does not redefine it.

The guard can be run manually after an event or failure. The optional Monitor remains read-only. Auto-Heal is a separate opt-in task and mutates only allowlisted, schema-recognized local drift; unknown future shapes stop rather than being rewritten.

The Chrome sidebar and the desktop app can also be signed into different ChatGPT accounts. The Doctor cannot read or reconcile those identities. When switching accounts, verify both surfaces manually, restart the intended desktop host, and run acceptance from a new task.

## Maintainer self-test

```powershell
pwsh -NoProfile -File ".\tests\Test-CodexRuntimeGuard.ps1"
```

The self-test runs live diagnosis and repair dry-run checks, validates reports against the JSON Schema, then tests stale and missing `resourcesPath` mutation, content-addressed CUA relocation, backup behavior, monitor state transitions, healthy Auto-Heal no-op behavior, and public-snapshot redaction inside temporary fixtures. It does not alter live Codex manifests or register a scheduled task.

## Sources

Product-boundary sources are maintained once in [the experiment source list](../../references/official-sources.md).
