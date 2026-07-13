---
subject: Codex Windows 上 Browser、Chrome 与 Computer Use 从多层假象到运行时迁移故障的事件重建
emerged_at: 2026-07-12 23:32:36 +08:00
updated_at: 2026-07-13 15:48:52 +08:00
form: 事故重建与诊断复盘
status: active
source: 综合
retrieval_trigger:
  - "再次遇到 Codex 中插件可见、Settings 已启用，但新任务仍拿不到 Chrome 或 Computer Use 时"
  - "官方 browser-client 或 computer-use-client 已能通过 node_repl 加载，却停在 native pipe、Sky runtime 或 helper path 时"
  - "Codex 更新后 WindowsApps 包、用户目录 runtime、Native Messaging 与任务工具面出现半新半旧状态时"
loose_ends:
  - "尚未证明 OpenAI 后续更新会自动修复 WindowsApps 受保护源文件的 runtime relocation；本次只是恢复了本机缺失的运行时目录"
  - "当前 26.707.8168.0 的 packaged cua_node 精确匹配 ecfc0d9aa02807e3；旧的 120c650ffb83 runtime 与两份仍指向 26.707.3748.0 的 chrome-native-hosts-v2.json 同时残留，说明升级生命周期仍可能留下陈旧登记"
  - "尚未在另一台机器复现从 copyfile 失败到 stream-copy 成功的完整证据链"
  - "尚未把本次处置做成自动检查或自愈机制；是否建设应另立 decision record，而不是写进本复盘"
---

# 这次不是一条故障

从 2026 年 6 月到 7 月，表面现象反复变成：

- Settings 显示 `Computer Use plugins unavailable`
- Browser、Chrome、Computer Use 插件在磁盘上，却没有可调用工具
- `mcp__node_repl__js` 有时缺失，有时出现后又缺少 privileged native pipe
- Chrome 扩展显示已连接，但普通 Codex 任务不能控制标签页
- Computer Use 能被 `@` 提及，却无法初始化 Sky runtime

这些现象不是同一个根因的不同文案。本机先后叠过至少五层真实问题：bundled 文件复制失败、plugin cache 或活动入口不完整、Chrome Native Messaging 登记失效、任务来源导致工具装配不同，以及最终仍未完成的 `cua_node` runtime relocation。每修复一层，系统都会前进一点，也因此很容易把新暴露的一层误认成唯一根因。

这份记录不是把所有历史压成一条“正确答案”，而是保留故障怎样一层层显露、哪些判断曾经成立、以及最后哪条证据把问题推到运行时迁移层。

## 最终恢复到了什么状态

2026-07-12 完整重启后的 task record 与本机观察给出的验收结果如下。随包可读的脱敏转录见 [`../evidence/2026-07-12-redacted-trace.md`](../evidence/2026-07-12-redacted-trace.md)；原始任务没有随目录打包，因此下表是有来源限制的历史记录，不是独立原始证据。

| 能力 | 验收链路 | 结果 |
| --- | --- | --- |
| 官方 Chrome | `mcp__node_repl__js` → bundled `browser-client.mjs` → `agent.browsers.get("extension")` → `openTabs/claimTab` | `REPORTED: pass-as-recorded` |
| 官方 Computer Use | `mcp__node_repl__js` → bundled `computer-use-client.mjs` → Sky Windows runtime → `list_apps` → Notepad 输入 | `REPORTED: pass-as-recorded` |
| Windows 原生后端 | `\\.\pipe\codex-computer-use-*` | 重启后仍存在 |

当前机器在 26.707.8168.0 上还能看到：

- `%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\ecfc0d9aa02807e3`：3558 个文件，287233735 字节，含 `codex-computer-use.exe`；文件数与总字节数精确匹配当前 `26.707.8168.0` 包内 `app\resources\cua_node`
- `%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\120c650ffb83`：3897 个文件，298937980 字节，含 `codex-computer-use.exe`；这是 6 月 29 日生成的旧 runtime，比当前包多 339 个文件，不是当前版本的 relocation 结果
- 正在工作的 `codex-computer-use-*` 与 `codex-browser-use-*` named pipes

当日任务记录报告：本次恢复不是 Settings UI 偶然变绿，也不是用 PowerShell、截图或第三方 MCP 完成了一次相似动作，而是官方客户端所要求的原生链路已经建立。由于原始 task record 未随目录打包，这一结论在本实验中保持为 `REPORTED`，不能升级为独立直接证据。

## 证据入口与强度

这份重建以原账号中的主恢复任务为主线，关键对照与验收来自以下任务角色。私有任务标识不随公开仓库发布；读取上面的随包证据摘录即可理解关键链路和来源限制。

- **路由对照任务**：区分 Chrome 侧边栏来源与普通 Codex 客户端来源
- **严格 Chrome 验收**：只允许官方 `node_repl → browser-client → extension` 链路
- **严格 Computer Use 初次复验**：在已有 Node REPL 时得到 Sky runtime unavailable
- **无副作用 nativePipe 诊断**：检查 native pipe 与 import 条件，不执行替代控制
- **重启后 Chrome 冷启动验收**：验证官方 Chrome 链在重启后仍成立
- **重启后 Computer Use 冷启动验收**：验证官方 Windows runtime 能列应用并操作 Notepad

本机证据入口包括：

- `%LOCALAPPDATA%\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs`：当前 MSIX 安装下真实存在的桌面端 relocation 与 helper setup 日志目录
- 当前 MSIX 包内 `app\resources\app.asar`：resolver 与 runtime path 选择逻辑
- 当前 MSIX 包内 `app\resources\cua_node`：packaged runtime 的文件集合
- `%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\ecfc0d9aa02807e3`：恢复后的当前 runtime

证据强度需要分开读：

- **直接观察**：日志里的 `copyfile` 失败、目录与文件计数、pipe 是否存在、任务实际调用的 server/tool 与返回值。
- **源码追踪**：从 `app.asar` 追到 helper path resolver 如何选择 relocation 后的 `cua_node` 目录。
- **修复后相关性**：补齐当前 hash 目录并重启后，Computer Use pipe 出现；历史任务记录把官方冷启动验收记为 `pass-as-recorded`。
- **因果判断**：`cua_node` relocation 失败是本轮 Sky/native pipe failure 的上游原因。这是由前三类证据共同支持的强因果判断，不是某一行日志直接写出的产品结论。

## 事故怎样展开

### 第一阶段：`plugins unavailable` 指向了真实的 WindowsApps 复制问题

最早的本机日志同时出现：

- `missing-helper-path`
- `bundled_executable_relocation_failed`
- `node-repl-missing`
- `browser_use_setup_failed`

手工复制又复现了两种同型错误：Node `fs.copyFileSync` 返回 `UNKNOWN / errno -4094 / syscall copyfile`，PowerShell `Copy-Item` 返回 `The specified file could not be encrypted.`。把当时的目标目录改为 EFS 后，同一路径能复制成功，插件 Marketplace 与 Settings 也确实恢复过。

这部分诊断保留在 [2026-06-05-efs-and-package-state.md](2026-06-05-efs-and-package-state.md)。它不是后来被证明“全错”，而是覆盖了当时确实存在的第一层故障。

### 第二阶段：插件出现了，但每次启动后的活动入口不稳定

随后又出现 Chrome plugin cache 只落下 `extension-host / scripts / skills`、缺少 `.codex-plugin / assets / docs` 的情况，以及 `chrome\latest` 指回会在启动时重建的半截 `.tmp` marketplace。补齐 cache、固定活动入口后，Chrome extension backend 曾经成功打开 `example.com`。

这里修复的是“插件内容与入口是否完整”，不是“每个任务是否获得官方控制工具”。当 UI 恢复后仍无法控制浏览器时，我们才被迫分开这两个问题。

### 第三阶段：替代方案证明了需求，却没有替代官方能力

为获得类似 Claude in Chrome 的体验，先后试过 Browser MCP、Playwright MCP Extension、Chrome DevTools MCP、mcp-chrome 与 CDP。它们各自能完成部分动作，却没有同时满足以下条件：

- 控制用户正在使用且保留登录态的真实 Chrome
- 不抢前台焦点
- 稳定读取复杂站点 DOM
- 新任务无需重复人工接管或重建上下文
- 能明确证明走的是所指定的官方插件链路

Playwright Extension 在 Boss、知乎、B 站等复杂页面上还出现过“tab 元数据已经是目标 URL，但执行上下文仍是 `about:blank`”以及 `native pipe is closed`。这些尝试说明需求本身没有被第三方方案消解，也提醒后续验收必须检查实际工具和后端身份，不能只看页面是否似乎被打开。

### 第四阶段：Chrome 扩展和任务工具面被拆成两层

2026-07-12 的排查发现 Chrome 本地升级留下了多处半新半旧状态：

- `chrome\latest` 曾指向已删除的旧版本
- Native Messaging 注册表项和 manifest 曾缺失
- `chrome-native-hosts-v2.json` 的 `resourcesPath` 指向已卸载的 WindowsApps 版本
- Chrome host 使用的 Codex CLI 版本过旧，无法启动当时选定的模型

通过插件自带 `installManifest.mjs` 恢复 Native Messaging、修正 v2 manifest 后，Chrome 侧边栏能够通过官方 extension host 工作。与此同时，普通 Codex 任务仍可能没有 `mcp__node_repl__js`。这给出一个重要但仍不完整的认识：

```text
插件 installed / enabled
不等于 Chrome Native Messaging 已工作
不等于 extension host 已连接
不等于当前任务获得 node_repl
不等于官方 browser/client runtime 已初始化
```

### 第五阶段：严格任务把 Chrome 与 Computer Use 分开

用户要求新任务只能走指定官方链路，禁止 mcp-chrome、DevTools、Playwright、Computer Use、shell 或截图兜底，并要求失败时报告第一处原始错误。

严格 Chrome 验收的历史任务记录报告成功完成：

```text
mcp__node_repl__js
→ browser-client.mjs trust check
→ setupBrowserRuntime
→ agent.browsers.get("extension")
→ https://example.com/
→ Example Domain
```

这个结果推翻了“本账号或本机完全没有官方控制资格”的宽泛解释。至少 Chrome 所需的任务工具面、trust 与 extension backend 能同时成立。

严格 Computer Use 初次复验却在同样已有 `mcp__node_repl__js` 的前提下返回：

```text
Windows Computer Use Sky runtime is unavailable
```

随后，无副作用 nativePipe 诊断进一步把问题压缩到 native pipe/helper runtime，而不是继续留在“工具有没有注入”这一层。

### 第六阶段：从错误类别转向追踪返回值来源

真正的转折不是再试一个开关，而是追问：`Computer Use native pipe path is unavailable` 里的 path 到底由哪个 resolver 产生，为什么 resolver 会返回空。

读取当前桌面包实现和真实日志后，链路变成：

```text
Computer Use client 初始化
→ 读取 native pipe / helper path
→ desktop resolver 寻找搬运后的 cua_node runtime
→ 期望的 hash 目录不存在或内容不完整
→ WindowsApps → 用户目录 relocation 未完成
→ helper 不启动
→ codex-computer-use-* pipe 不出现
→ 上层只看到 Sky runtime / native pipe unavailable
```

日志中的直接失败发生在把 packaged `cua_node` 从 WindowsApps 搬到用户目录时。Node `copyfile` 在受保护源中的普通文件上失败，其中一个可复现点是 `bin\CHANGELOG.md`，错误仍是 `UNKNOWN / -4094 / copyfile`。因此前面看到的 helper path、native pipe、Sky runtime 都是同一条 relocation 失败后的下游返回值，不是新的权限类别。

## 最终处置为什么与 EFS 不同

这次没有继续修改插件缓存、任务配置或功能开关，而是恢复 resolver 真正期待的 runtime 目录。

关键不对称是：受保护源文件可以被打开、读取并计算哈希，但 Node `copyfile` 这个复制原语失败。于是处置改为逐文件 stream-copy：

1. 按桌面实现选择的 runtime hash 创建目标目录。
2. 枚举 packaged `cua_node` 下的每个目录与文件。
3. 用读写流搬运字节，而不是再次调用已失败的 `copyfile` / `Copy-Item`。
4. 核对目标文件总数、总字节数、`node.exe`、`node_repl.exe`、Sky module 与 `codex-computer-use.exe`。
5. 完整重启后只用官方链路验收。

`ecfc0d9aa02807e3` 这一轮最终得到 3558 个文件、287233735 字节。之后 `codex-computer-use-*` pipe 出现，官方 Computer Use client 才能继续初始化。

这不是一个与产品机制无关的“把文件硬拷过去”旁路。它恢复的正是桌面 resolver 原本要生成、后续代码也真实查找的对象；偏离官方流程的部分只有复制原语，而不是目标目录、运行时内容或调用链。

## 哪些中间判断该保留，哪些已经降级

| 判断 | 今天的地位 |
| --- | --- |
| WindowsApps 受保护文件复制语义会破坏 Codex staging | 仍成立，并最终再次命中 `cua_node` relocation |
| EFS 能恢复当时部分复制链 | 当时成立，但不能概括后来所有 runtime 迁移，也不是本轮最终动作 |
| 插件 cache、`latest` 与 Native Messaging 可能半更新 | 仍成立，Chrome 恢复确实需要处理这些层 |
| 插件可见但任务未获得工具 | 仍成立，是独立的路由/装配判断，但不能解释已有 node_repl 后的 Sky failure |
| 账号 rollout 是主要根因 | 严格 Chrome 成功后不再足以解释本机问题 |
| Boss 直聘反自动化是根因 | 不能解释多个复杂站点和 `about:blank/native pipe`，已降为站点层次的次要变量 |
| 第三方 MCP 可以等价替代官方 Chrome/Computer Use | 不成立；它们适合部分任务，不满足本次目标的完整能力边界 |

## 本次验收为什么可信

本次采用的不是“看到窗口动了就算成功”，而是链路验收：

- 新任务，而不是沿用修复前冻结工具面的旧任务
- 指定唯一官方入口
- 禁止相似能力兜底
- 记录实际 tool/server 名称
- 记录 client import、trust、backend/runtime 建立状态
- Computer Use 还要求真实枚举应用并在 Notepad 中输入
- 完整重启电脑后再次验证 pipe 与任务行为

其中一次 Chrome 导航由验收任务报告为企业网络策略阻止；本记录没有独立审计该策略来源。它至多说明目标 URL 在那次任务中受策略限制；在 `openTabs / claimTab` 已通过时，不能据此把失败重新归为插件或 runtime。

## 当前仍不能写成“永久修复”

2026-07-12 23:48 +08:00 再检查时，应用已经是 `26.707.8168.0`；其 packaged `cua_node` 与 `ecfc0d9aa02807e3` 的 3558 个文件、287233735 字节精确一致，Computer Use pipe 仍在。这是当前版本冷启动后仍工作的积极证据。`120c650ffb83` 是更早生成且内容不同的 runtime，不应归到当前版本。

但两份 `chrome-native-hosts-v2.json` 的 `resourcesPath` 仍指向 `26.707.3748.0`。这说明“能力现在可用”和“更新生命周期已经自洽”不是同一句话。当前不应预防性修改它，因为 Chrome 正在工作；它应作为下一次升级后的重点验收点，而不是被成功结果抹掉。

未来若要做自动检查或自愈，应该单独决定它监测哪些对象、何时修、如何回滚。把这类承诺塞进本事故复盘，会让一份历史证词变成未经设计的维护脚本。
