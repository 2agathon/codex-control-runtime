# Official capability acceptance prompts

Run these in three new Codex tasks after an app update, account/workspace switch, reinstall, or repair. Here, “official” uses the operational definition in the root README: current `openai-bundled` skill/client plus its required backend. It is not a stable public API guarantee.

These prompts are **Level 1 read-only acceptance**. They prove tool injection, client trust, backend initialization, and one harmless observation. They deliberately perform no write action. Level 1 `PASS` does not prove that every write action or target website works.

## Shared client selection rule

For capability `NAME`, search only `%USERPROFILE%\.codex\plugins\cache\openai-bundled\NAME`. Resolve a healthy `latest` link first when present. Otherwise keep only directories whose names parse as versions, then choose the highest complete candidate. A complete candidate must contain `.codex-plugin/plugin.json` whose `name` and `version` match the requested capability and directory, the required client, and the bundled skill below:

- Browser: `scripts/browser-client.mjs` and `skills/control-in-app-browser/SKILL.md`
- Chrome: `scripts/browser-client.mjs` and `skills/control-chrome/SKILL.md`
- Computer Use: `scripts/computer-use-client.mjs` and `skills/computer-use/SKILL.md`

Record the manifest, skill, and client paths. If no complete candidate exists, versions disagree, or selection is ambiguous, return `NOT-COVERED` and report candidate paths; do not import a similarly named global package. “Complete current documentation” in the prompts means the runtime documentation returned after setup (`browser.documentation()` or `sky.documentation(...)`), not a guessed disk file.

A task passes only when its execution record contains the requested server/tool, selected absolute client path, backend/runtime, operation, result, first raw error, and `fallback_used=false`. Capture it with [`../evidence/record-template.md`](../evidence/record-template.md). A sentence claiming success is not direct evidence.

## Browser

```text
Only run Level 1 acceptance for the bundled in-app Browser plugin. Follow the shared client selection rule for browser, use mcp__node_repl__js, import the selected absolute scripts/browser-client.mjs, run setupBrowserRuntime, obtain agent.browsers.get("iab"), and read the complete current browser documentation before operating. Do not use Chrome, Computer Use, Playwright MCP, Chrome DevTools MCP, mcp_chrome, shell UI automation, or screenshots as substitutes. Call only the currently documented operation that lists existing Browser tabs and report the observed tab count. Do not create, close, navigate, or modify a tab. If no read-only tab-list operation is documented, stop and report NOT-COVERED. Report the exact server/tool, selected client path, backend name, actual operation name, result, first raw error, and fallback_used.
```

## Chrome

Before running this test, open a harmless page such as `https://example.com/` in the Chrome profile you intend to use.

```text
Only run Level 1 acceptance for the bundled OpenAI Chrome plugin. Follow the shared client selection rule for chrome, use mcp__node_repl__js, import the selected absolute scripts/browser-client.mjs, run setupBrowserRuntime, obtain agent.browsers.get("extension"), and read the complete current browser documentation before operating. Do not use the in-app Browser, Computer Use, Playwright MCP, Chrome DevTools MCP, mcp_chrome, shell UI automation, or screenshots as substitutes. Call the currently documented open-tabs operation, read titles and URLs, and make no page changes. Report the exact server/tool, selected client path, backend name, actual operation name, observed tab count, result, first raw error, and fallback_used.
```

## Computer Use

```text
Only run Level 1 acceptance for the bundled OpenAI Computer Use plugin. Follow the shared client selection rule for computer-use, use mcp__node_repl__js, import the selected absolute scripts/computer-use-client.mjs, and run setupComputerUseRuntime. Read the complete current guidance and API documentation, then call the documented read-only operation that lists Windows apps. Do not assume its method name from an older run. If current documentation exposes no read-only app listing, stop and report NOT-COVERED. Do not launch, focus, click, type, or close any app. Do not use PowerShell UI automation, shell app launching, Chrome, Browser, Playwright, or screenshots as substitutes. Report the exact server/tool, selected client path, runtime/backend, actual operation name, app count, result, first raw error, and fallback_used.
```

## Result interpretation

- All three Level 1 checks pass: the three runtimes and task injection are healthy enough for read-only observation in the current account/workspace; write actions and arbitrary targets remain unproven.
- Local Doctor passes but one new task lacks `mcp__node_repl__js`: stop repairing files; investigate account/workspace policy, rollout, or task routing.
- Chrome works in one Chrome profile but not another: inspect extension installation and authorization in the failing profile.
- The same local failure occurs under two accounts in the same Windows user: treat the shared local layer as the leading suspect.
- Only one account/workspace fails while the same machine and Chrome profile pass under another: treat the service-side account/workspace layer as the leading suspect.
