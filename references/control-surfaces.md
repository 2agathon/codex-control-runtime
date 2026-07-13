# Control surfaces

这些控制面解决的问题相邻，但不能互相冒充。

| Surface | 主要用途 | 是否使用现有登录态 | 本实验中的角色 |
| --- | --- | --- | --- |
| Official in-app Browser | Codex 内置隔离浏览器 | 独立浏览器状态 | 官方验收主线 |
| Official Chrome plugin | 控制用户真实 Chrome、标签页与登录态 | 是 | 官方验收主线 |
| Official Computer Use | 控制 Windows App | 不适用 | 官方验收主线 |
| Playwright / Playwright MCP | 自动化测试、浏览器行为复现 | 取决于启动/extension/CDP 模式 | 比较组，不作为官方 fallback |
| Chrome DevTools MCP | 调试页面、网络、性能、DOM 和截图 | 可连接调试目标 | 比较组，不作为官方 fallback |
| `mcp_chrome` | 第三方扩展式 Chrome 控制 | 通常是 | 比较组，不作为官方 fallback |
| Shell / PowerShell UI automation | 启动程序或系统自动化 | 取决于脚本 | 只证明动作发生，不证明官方能力 |

严格官方验收中一旦指定链路失败，应停止并报告第一处原始错误。替代控制面可以另开实验比较任务覆盖率、稳定性和用户干扰，但不能把“目标完成”写成“官方插件已恢复”。
