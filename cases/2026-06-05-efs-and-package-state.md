---
subject: Codex Windows 上 “Computer Use plugins unavailable” 的本机诊断与 EFS 处置
emerged_at: 2026-06-05 14:53:22 +08:00
updated_at: 2026-07-12 23:48:45 +08:00
form: 诊断手册
status: archived
source: 综合
retrieval_trigger:
  - "再次遇到 Codex desktop 在 Windows 上显示 Computer Use plugins unavailable 时"
  - "日志里出现 missing-helper-path / bundled_executable_relocation_failed / node-repl-missing 时"
  - "需要区分问题是账号或 rollout 层，还是本机 WindowsApps 受保护文件复制失败时"
loose_ends:
  - "另一台电脑只确认了 UI 同样 unavailable，没有做本地日志与复制链复盘"
  - "26.609 后 stable marketplace 已同步为备份；后续 Store 更新后仍需检查是否要再次同步"
  - "尚未确认 Windows 11、不同 workspace、或非商店包形态下是否还需要同样的 EFS 处置"
  - "26.609 后当前线程只发现 IAB backend，Chrome extension backend 需新线程或重启后再验收"
---

# 诊断记录

## 2026-07-12 后续入口

> 历史阶段记录：仅在命中本文件完整错误签名时用于理解 6 月现场，不再作为当前默认修复手册。

这份文件保留 6 月阶段真实发生的 EFS、Marketplace 与 plugin cache 诊断，不按后来结果倒写历史。7 月继续排查后，Chrome Native Messaging、任务工具装配与 `cua_node` runtime relocation 又分别暴露出独立阻断；最终恢复过程、严格官方链路验收以及本记录中哪些判断仍成立，见 [2026-07-12-runtime-recovery.md](2026-07-12-runtime-recovery.md)。

## 现象与判定

这次最有价值的副产物，不是“Computer Use 现在好了”这个结果本身，而是一条可以复用的判定链：当 Codex desktop 在 Windows 上显示 `Computer Use plugins unavailable` 时，不要先把问题归到账号、开关或缓存损坏。先看本机是否命中了 `WindowsApps` 受保护文件无法复制到 Codex 本地运行目录这条链。

这条链一旦命中，`Computer Use unavailable` 往往只是表层症状。更底层的故障点，是 Codex 没能把自己的 bundled runtime 和 Computer Use plugin 从商店包中搬到本地可运行位置，所以后面才会出现 `missing-helper-path`、`node-repl-missing` 和 plugin marketplace 解析失败。

后续验证又补了一层边界：EFS 处置打通的是“从 `WindowsApps` 到本地运行目录”的复制链，它足以让 bundled plugin 再次出现在 marketplace，并让 Settings 从 unavailable 状态里恢复出来；但这不自动保证 Chrome 扩展后端对应的本地插件缓存已经完整。实际复盘里，Chrome 插件缓存还额外缺过 `.codex-plugin`、`assets`、`docs` 三块，导致扩展引导仍失败，需要单独补齐。

再往后追了一步，又发现“重启后插件再次消失”并不意味着 EFS 结论失效，而是另一层入口仍指向会在启动时重建的 `.tmp` marketplace。也就是说，复制链修复和入口稳定化是两件事：前者解决“能不能复制下来”，后者解决“重启后还会不会重新指回半截内容”。

2026-06-13 复查 26.609 后，官方 `.tmp` marketplace 已能完整生成 `.agents/plugins/marketplace.json` 与 `browser / chrome / computer-use / latex` 的 plugin manifests。当前可把 active marketplace source 交还给 `.tmp`，把稳定副本降级为备份；但 `WindowsApps` 受保护文件复制到普通非加密目录仍会失败，所以 EFS 这层暂时不能撤。

这份记录的结论也有边界。它解释的是主机上的本地运行时问题，不自动解释“另一台电脑也 unavailable”这种更广的现象。那一层仍可能叠着账号、workspace、rollout 或产品侧因素。

## 命中的错误签名

主机上的关键日志签名是这一组，而不是其中某一条单独出现：

- `reason=missing-helper-path`
- `Windows Computer Use helper paths are unavailable`
- `bundled_plugins_marketplace_resolve_failed`
- `bundled_executable_relocation_failed`
- `browser_use_setup_failed ... reason=node-repl-missing`

如果只看到 UI unavailable，但看不到这组日志，就不要直接套用这次处置。

## 证据链

### 包里有文件，不是“没装进去”

商店包本体里能确认看到 Computer Use 相关内容：

- `...\\plugins\\computer-use\\.codex-plugin\\plugin.json`
- `...\\plugins\\computer-use\\node_modules\\@oai\\sky\\bin\\windows\\codex-computer-use.exe`

所以问题不是“插件文件根本不存在”，而是“运行时没有成功把它准备到可用路径”。

### 日志暴露的是复制失败，不是单纯开关未开

主机日志不止报 Computer Use helper path unavailable，还同时报：

- 从 `WindowsApps` 复制 `computer-use\\.codex-plugin\\plugin.json` 失败
- 从 `WindowsApps` 复制 `codex.exe` 失败
- 从 `WindowsApps` 复制 `node.exe` 失败
- 从 `WindowsApps` 复制 `node_repl.exe` 失败

这个组合说明故障已经下沉到 bundled runtime relocation，而不是停留在 UI 设置层。

### 手工复现出了同一条复制失败路径

把 `WindowsApps` 里的受保护文件复制到普通目录时，复现出和 Codex 日志同型的错误：

- Node `fs.copyFileSync`：`UNKNOWN`, `errno -4094`, `syscall copyfile`
- PowerShell `Copy-Item`：`The specified file could not be encrypted.`

这一步很关键，因为它把“Codex 自己内部出错”变成了“宿主机上可独立复现的文件语义问题”。

### 目标目录改成 EFS 后，同一路径复制成功

把真正的目标目录改成 EFS 加密目录后，之前失败的 `copyfile` 路径成功了。验证过的真实目录是：

- `%LOCALAPPDATA%\OpenAI\Codex\bin`
- `%USERPROFILE%\.codex\.tmp\bundled-marketplaces`

验证过的真实源文件包括：

- `...\\app\\resources\\node_repl.exe`
- `...\\plugins\\computer-use\\.codex-plugin\\plugin.json`

这一步说明处置命中的是根因所在层，而不是偶然绕开了某个 UI 状态。

### Chrome 扩展后端还可能卡在“不完整缓存”

后续再做 Chrome 扩展链路验证时，发现本地 Chrome 插件缓存目录最初只有：

- `extension-host`
- `scripts`
- `skills`

但商店包里的同版本 Chrome plugin 顶层实际上还有：

- `.codex-plugin`
- `assets`
- `docs`

当这三块缺失时，通过 `browser-client.mjs` 引导 Chrome 扩展后端会直接报：

- `Packaged browser documentation directory is missing.`

这说明即使 bundled runtime 主链已恢复，某个具体 plugin 的本地 cache 仍可能停在“部分落盘成功”的状态，不能因为 UI 恢复就默认扩展后端一定可用。

### 重启后还可能重新指回 `.tmp` 半截 marketplace

后续在“插件又消失”的现场继续复盘时，看到：

- `config.toml` 里的 `marketplaces.openai-bundled.source` 仍指向 `%USERPROFILE%\.codex\.tmp\bundled-marketplaces\openai-bundled`
- 这个 `.tmp` marketplace 顶层只有 `plugins`
- 里面进一步只有 `plugins\chrome\extension-host`
- 但商店包里的完整 marketplace 顶层本应至少有 `.agents` 与 `plugins`

同时，本地 `chrome` plugin cache 虽然已经有完整版本目录：

- `%USERPROFILE%\.codex\plugins\cache\openai-bundled\chrome\26.602.30954`

但它的活动入口：

- `%USERPROFILE%\.codex\plugins\cache\openai-bundled\chrome\latest`

最初仍是一个 junction，指向 `.tmp\bundled-marketplaces\openai-bundled\plugins\chrome`。
这解释了为什么“完整内容明明还在，本轮启动里插件却又像消失了一样”：稳定版本目录还在，但入口又回到了半截 staging 内容。

### 26.609 后 `.tmp` marketplace 已恢复完整

升级到 `OpenAI.Codex_26.609.4994.0_x64__2p2nqsd0c76g0` 后，包内 bundled plugin 版本变为：

- `browser`: `26.609.41114`
- `chrome`: `26.609.41114`
- `computer-use`: `26.609.41114`
- `sites`: `0.1.15`

本机 `.tmp` marketplace 也重新生成完整结构：

- `.agents\plugins\marketplace.json`
- `plugins\browser\.codex-plugin\plugin.json`
- `plugins\chrome\.codex-plugin\plugin.json`
- `plugins\computer-use\.codex-plugin\plugin.json`
- `plugins\latex\.codex-plugin\plugin.json`

因此 26.609 后，原先“必须钉住 stable marketplace 才不丢 plugin manifest”的判断可以放松。更合适的状态是：active source 指向官方 `.tmp`，stable marketplace 保留为备份。

## 处置动作

> 本节全部命令都是 2026-06 本机历史动作，包含固定用户名、旧版本目录、EFS 修改、`robocopy /MIR`、`Remove-Item` 和配置改写。它们用于重建事故，不是当前操作手册，不应直接执行。当前处置入口是 [`../tools/runtime-guard/README.md`](../tools/runtime-guard/README.md)。

本次采用的是保守版处置，只改目录属性，不删缓存，不重建目录结构。

对两个目标目录执行 EFS：

```powershell
cipher /e /a "$env:LOCALAPPDATA\OpenAI\Codex\bin"
cipher /e /a "$env:USERPROFILE\.codex\.tmp\bundled-marketplaces"
```

这一步之后，再用同样的 `copyfile` 方式复测：

- `WindowsApps -> %LOCALAPPDATA%\OpenAI\Codex\bin`
- `WindowsApps -> %USERPROFILE%\.codex\.tmp\bundled-marketplaces`

如果复测成功，说明本机复制链已打通。

### 针对 Chrome 扩展后端的补全动作

在确认 Chrome plugin cache 缺顶层目录后，没有清空整包，而是把商店包里同版本 `chrome` plugin 直接补拷到本地 cache：

```powershell
$pkg = Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
$src = Join-Path $pkg.InstallLocation 'app\resources\plugins\openai-bundled\plugins\chrome'
$dst = "$env:USERPROFILE\.codex\plugins\cache\openai-bundled\chrome\26.602.30954"
robocopy $src $dst /E /XJ /R:2 /W:1
```

补拷后，本地 cache 顶层与商店包对齐为：

- `.codex-plugin`
- `assets`
- `docs`
- `extension-host`
- `scripts`
- `skills`

### 针对“重启后又指回 `.tmp`”的固定动作

为了不再依赖会在启动时重建的 `.tmp` marketplace，本次又加了一层稳定化处置：

1. 把商店包里的完整 `openai-bundled` marketplace 固化到用户目录：

```powershell
$pkg = Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
$src = Join-Path $pkg.InstallLocation 'app\resources\plugins\openai-bundled'
$dst = "$env:USERPROFILE\.codex\bundled-marketplaces\openai-bundled"
robocopy $src $dst /MIR /XJ /R:2 /W:1
```

2. 把 `config.toml` 里的 marketplace source 从 `.tmp` 改到稳定副本：

```toml
[marketplaces.openai-bundled]
source = '\\?\%USERPROFILE%\.codex\bundled-marketplaces\openai-bundled'
```

3. 把 `chrome\latest` 从 `.tmp` 改指到稳定副本里的 `plugins\chrome`：

```powershell
$latest = "$env:USERPROFILE\.codex\plugins\cache\openai-bundled\chrome\latest"
$target = "$env:USERPROFILE\.codex\bundled-marketplaces\openai-bundled\plugins\chrome"
Remove-Item -LiteralPath $latest -Force
New-Item -ItemType Junction -Path $latest -Target $target
```

这层动作解决的不是“能不能复制下来”，而是“重启后配置和活动入口会不会再次指回半截 staging 内容”。

### 26.609 后的收敛动作

26.609 复查后执行了两步收敛：

1. 先把 stable marketplace 备份同步到 26.609 包内版本：

```powershell
$pkg = Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
$src = Join-Path $pkg.InstallLocation 'app\resources\plugins\openai-bundled'
$dst = "$env:USERPROFILE\.codex\bundled-marketplaces\openai-bundled"
robocopy $src $dst /MIR /XJ /R:2 /W:1
```

2. 再把 active marketplace source 从 stable 副本切回官方 `.tmp`：

```toml
[marketplaces.openai-bundled]
source = '\\?\%USERPROFILE%\.codex\.tmp\bundled-marketplaces\openai-bundled'
```

同时观察到 `notify` 已由 Codex 自己改为新的 runtime 路径：

```text
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\789504f803e82e2b\bin\node_modules\@oai\sky\bin\windows\codex-computer-use.exe
```

这说明 Computer Use runtime staging 也不再完全沿用 26.602 时代的 cache 路径。

## 验证标准

这次有三个层次的验证，不要混为一谈。

### 第一层：本机复制链是否恢复

只看一件事：之前失败的 `copyfile` 路径是否在真实目标目录上成功。
如果这层不成功，不必谈 UI。

### 第二层：desktop 重启后的产品表现

在复制链恢复之后，再看：

- plugin marketplace 是否能正常解析相关 plugin
- Settings > Computer Use 是否仍显示 `Computer Use plugins unavailable`
- 新日志里是否还出现上述错误签名

如果第一层成功、第二层仍失败，说明本地运行时问题已经处理，但还有更上层的产品或账号因素。

这次后续验收里，第二层已经过了一次：bundled plugins 重新出现在 Plugin Marketplace，安装后 Settings 不再显示 `Computer Use plugins unavailable`。

### 第三层：扩展后端是否真的能起页

第二层通过后，还要再看具体 plugin 的后端能不能真连起来。
这次针对 Chrome 扩展后端的最终验收是：

- 先补齐本地 `chrome` plugin cache 缺失的 `.codex-plugin / assets / docs`
- 再把 marketplace source 与 `chrome\latest` 固定到用户目录里的稳定副本
- 重新引导扩展后端
- 新开 Chrome tab
- 打开 `https://example.com/`
- 成功读到 URL `https://example.com/` 与标题 `Example Domain`

如果第二层通过、第三层失败，说明 UI 与 marketplace 已恢复，但某个 plugin 的本地 cache 或后端引导仍未完全恢复。

26.609 后新增一条检查：如果当前旧线程里 `agent.browsers.list()` 只看到 `iab`，没有 `extension`，不要立刻判定 Chrome plugin 坏了。这个可能是线程启动时的 backend 暴露状态，需在新线程或完整重启 desktop 后复验。

## 不要误判的边界

### 不要把这次处置扩展成通用答案

这次命中的，是 `WindowsApps` 受保护文件复制到普通目标目录失败。
如果未来机器上没有 `copyfile` 失败、没有 `missing-helper-path`、没有 `node-repl-missing`，就不应机械套用 EFS 方案。

### 不要把“另一台机器也 unavailable”直接读成同一根因

第二台机器没有做同样深度的本地复盘。
它可以说明“问题不一定只在这台主机”，但不能单独证明“另一台机器也是同样的文件复制链问题”。

### 不要把 UI 恢复、扩展后端恢复、官方根因闭环混成一句话

这次能实锤的，是本机复制链恢复了，desktop UI 也恢复了，而且 Chrome 扩展后端完成了一次真实起页。
但这仍然只说明本机修复路径成立，不等于产品侧已从根上消除了 `WindowsApps` 受保护文件复制与局部 plugin cache 不完整这类问题。

26.609 后，局部 plugin cache 不完整问题看起来已改善，但 `WindowsApps` 受保护文件复制到普通非加密目录仍失败。不要因为 `.tmp` marketplace 这次完整了，就把 EFS 处置一起撤掉。

## 外部对照

公开 issue 里有高相似案例：[openai/codex#25220](https://github.com/openai/codex/issues/25220)。
如果未来再遇到类似现象，值得先对照那条 issue 的错误签名，而不是从零开始猜。后续也已在该 issue 里补过一条 follow-up：把真实目标目录改成 EFS 后，本机 bundled plugin availability 可以恢复。

当前分诊和受控修复不再从这份历史记录执行，统一从 [`../tools/runtime-guard/README.md`](../tools/runtime-guard/README.md) 进入。
