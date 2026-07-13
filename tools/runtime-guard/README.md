# Codex Runtime Guard

This tool is maintained as part of the [Codex Control Runtime Lab](../../README.md). The implementation in this directory is the sole source of truth; `.ai/operations/codex-runtime-guard/` contains compatibility shims only.

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
```

The repairer can:

- update stale `resourcesPath` values in the two v2 manifests to the currently installed Codex AppX resources directory;
- recreate a missing/broken Chrome `latest` Junction only when one complete newest version directory is unambiguous;
- invoke the bundled Chrome `installManifest.mjs` when Native Messaging registration is missing or broken.

Before modifying a v2 manifest, it writes a backup in a timestamped subdirectory under `%LOCALAPPDATA%\OpenAI\Codex\runtime-guard-backups`. A rewritten JSON file is parsed immediately; failed validation restores the backup.

The repairer intentionally does not automate `cua_node` relocation. The destination ID is selected by private desktop runtime logic and cannot be inferred safely from a folder name alone. If the Doctor finds no relocated runtime matching the packaged manifest, preserve the report and inspect current desktop logs before any stream-copy. The historical recovery and evidence standard are recorded in [the incident reconstruction](../../cases/2026-07-12-runtime-recovery.md).

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

```text
Doctor FAIL
  -> repair only the failed local layer, then rerun Doctor

Doctor has no local FAIL, acceptance task lacks tools
  -> stop local repair; compare account/workspace/task routing

One Chrome profile fails, another passes
  -> inspect that Chrome profile, not AppX/runtime

Two accounts fail at the same local path on one Windows user
  -> shared local state is the leading suspect

Only one account/workspace fails on the same healthy local state
  -> service-side entitlement or policy is the leading suspect
```

The guard should be run after an event or failure, not installed as a silent auto-repair service. Automatic mutation could overwrite a valid future schema. Detection may be scheduled later, but repair remains explicit.

The Chrome sidebar and the desktop app can also be signed into different ChatGPT accounts. The Doctor cannot read or reconcile those identities. When switching accounts, verify both surfaces manually, restart the intended desktop host, and run acceptance from a new task.

## Maintainer self-test

```powershell
pwsh -NoProfile -File ".\tests\Test-CodexRuntimeGuard.ps1"
```

The self-test runs live diagnosis and repair dry-run checks, then tests `resourcesPath` mutation, backup behavior, and public-snapshot redaction only inside temporary fixtures. It does not alter live Codex manifests.

## Sources

Product-boundary sources are maintained once in [the experiment source list](../../references/official-sources.md).
