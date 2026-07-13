---
title: "Codex app-server manifest resourcesPath missing or stale"
---

# App-server manifest `resourcesPath` is missing or stale

A Chrome extension can be installed, enabled, and able to start its native host while the host still fails to launch the current Codex app-server. One observed cause is a v2 host entry whose `resourcesPath` points to an AppX version that Windows has already replaced.

## What to verify

- The Chrome Native Messaging registry entry resolves to a valid manifest.
- The manifest resolves to the bundled extension host.
- Both `chrome-native-hosts-v2.json` copies contain a matching entry and its paths exist.
- The `resourcesPath` belongs to the currently installed Codex AppX package.

Do not edit a single JSON field before checking the whole entry and retaining a backup. The Doctor's repair mode is dry-run by default and only applies the narrow resource-path repair when explicitly requested.

Next step: see the [runtime-guard repair boundary](https://github.com/2agathon/codex-control-runtime/blob/main/tools/runtime-guard/README.md) and the [July case](https://github.com/2agathon/codex-control-runtime/blob/main/cases/2026-07-12-runtime-recovery.md).
