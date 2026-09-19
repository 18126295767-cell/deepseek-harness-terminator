# 测试工程师质量复查报告

> 角色：测试/质量官（Foxtrot）交付。对象：`deepseek-harness-terminator` 本轮实现
> 的 G9–G14（及既有 P0 回归）。约束底线：本地优先、不抢前台、不上云。

## 一、验证证据（真实验证输出）

| 检查 | 命令 | 结果 |
|---|---|---|
| Swift 全量类型检查 | `npm run typecheck` | exit 0（17 个 Swift 文件） |
| 契约测试套件 | `npm test` | **29/29 通过，0 失败** |
| 完整构建 | `scripts/build-app.sh` | exit 0，产物 `DeepSeekHarness.app`（443 KB） |
| 仓库 lint | `npm run lint` | `17 Swift file(s), 0 problems` |
| 深模块回归 | 各 `tests/*-test` 二进制 | 全部 0 failures（含既有 voice/builtin/tab/session） |

覆盖的纯 Foundation 深模块与契约测试：
- G1 `CommandPalette`、G2 `BrowserSessionStore`、G3 `PageSummaryModel`、
  G4 `TabGroupingModel`、G5 `FindInPageModel`、G6 `SplitPaneState`、
  G7 `BrowserShortcuts`、G9 `SessionRestoreModel`、G10 `PageCaptureModel`、
  G11 `VerticalTabsModel`、G12 `UserScriptStore`、G14 `MouseGestureModel`。

## 二、对抗式自动审查（checkup 完整结果）

在系统负载回落后（load ~2），对抗审查代理引擎成功返回 **12 个发现**（1 严重 / 8 一般 /
3 建议），红队验证后全部成立：

## 三、发现与修复

| 严重度 | 问题 | 处置 |
|---|---|---|
| 严重 | G14 面板鼠标手势未真正接线：只注册 `.mouseMoved` tracking area，无 mouseDragged/mouseUp 处理，`MouseGestureModel.direction` 在 App 中从未调用；且反复开关累积 tracking area | **已修复**：改为 NSEvent 本地监听（限定面板窗口、放行其他事件），拖拽经 `MouseGestureModel.direction`+`.gesture` 派发 forward/back/refresh；关闭时 `removeMonitor` 干净清理 |
| 一般 | G9 恢复会话多余默认首页标签：buildPanel 先 `newTab` 再追加恢复标签 | **已修复**：buildPanel 不再建初始标签，改由 `restoreSessionIfNeeded` 决定（有会话恢复、无会话才补默认首页） |
| 一般 | G9 保存竞态：`saveSession` 把落盘放在 evaluateJavaScript 异步回调，`applicationWillTerminate` 不等待 → 退出丢会话 | **已修复**：`saveSession` 同步落盘（滚动位置折中记 0），保证退出必保存 |
| 一般 | G9 恢复的非选中标签从未 load → 空白页 | **已修复**：为每个恢复标签 `.load`，点击即有内容 |
| 一般 | G11 折叠未接 UI（无折叠入口） | **已修复**：分组标签栏渲染「可点击组头折叠按钮」（disclosure style），点击 toggle 组折叠 |
| 一般 | G11 分组标签显示字面三元表达式（`(` 未转义为 `\(`） | **已修复**：改为先算标题再插值 `\(title)` |
| 一般 | G12 用户脚本无管理入口（死代码） | **已修复**：新增「添加用户脚本…」菜单（NSAlert 收集名称/URL 通配/JS），写入 `UserScriptStore` |
| 一般 | G10 截图文件名未唯一化，重复保存静默覆盖 | **已修复**：`PageCaptureModel.uniqueFileName` 追加 `-1/-2/…`，新增契约测试（17 checks） |
| 一般 | AI 总结无条件清空剪贴板并写入整页正文（最多 4000 字） | **已修复**：改为先弹「复制并去 DSH」确认；正文截取缩至 1500 字符 |
| 建议 | G12 每次 didFinish 重复注入无去重 | **已修复**：按 webView+URL+脚本 id 去重，仅首次注入 |
| 建议 | 持久化写失败静默（SessionRestore/UserScript/BrowserSession `try?` 直接 return） | **记录为已知限制**：后续改为返回结果/日志供上层反馈 |
| 建议 | 语音投递 ClipBoardVoiceBridge 用 CGEvent 全局 Cmd+V，转写完成时焦点可能已切换 | **记录为既有行为**：属语音功能既有设计、风险在外层焦点，作为后续优化项 |

## 四、复核结论（修复后）

- 纯逻辑层与胶水层的 12 项发现已逐一处置：10 项已修复并复绿，2 项建议级记录为已知限制/后续优化。
- 验证证据（修复后真实输出）：
  - `npm run typecheck` → exit 0（0 error / 0 warning）
  - `npm test` → **29/29 通过，0 失败**
  - `npm run lint` → `17 Swift file(s), 0 problems`
  - `scripts/build-app.sh` → exit 0，产物 `DeepSeekHarness.app`（442 KB）

结论：**通过（1 严重 + 8 一般已修复，2 建议作为已知限制记录）。**
