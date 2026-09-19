# 需求缺口分析报告 · deepseek-harness-terminator

> 基于《竞品调研报告 docs/competitive-analysis.md》，结合本项目「本地优先、不抢前台、
> 原生 macOS、WKWebView 内置浏览器 + 本地离线语音 + 背后本地 DSH LLM」的现实约束，
> 定位「该有而还没有 / 还没做全」的需求缺口，并给出优先级与可行性建议。

---

## 0. 落地状态（2025 本迭代已全量实现）

本次交付已将 **P0 全部落地并验证通过**（对应缺口标号，均已实现为纯 Foundation 深模块 + 薄
AppKit 胶水，由 `tests/*.test.swift` 契约测试覆盖）：

- **G1 命令/查找栏（⌘T）**：`CommandPalette`（按标题/副标题/域名检索、`/` 前缀命令模式、键盘上下选择）。
- **G2 书签与最近访问（本地优先）**：`BrowserSessionStore`（☆/★ 收藏、LIFO 历史、跨实例持久化）。
- **G3 AI 总结当前页 → 本地 DSH（⌘⇧Y）**：`PageSummaryModel` 生成总结提示词并聚焦本地 DSH。
- **G4 垂直标签分组（⌘⇧G）**：`TabGroupingModel` 按站点聚合标签并加组名前缀。
- **G5 站内查找（⌘F）**：`FindInPageModel` + `WKWebView.find`。
- **G6 分屏（⌘⇧S）**：`SplitPaneState` + 副屏 WKWebView。
- **快捷键集（⌘L / ⌘N / ⌘W / ⌘1-9 / ⌃⌘Tab）**：`BrowserShortcuts` 统一映射。
- **G8 AI 命令填空（prompt 命令）**：命令栏以 `/` 前缀进入命令模式，预设「新建标签 / 语音输入 /
  站内查找 / AI 总结」等命令。
- **G9 会话与标签生命周期恢复**：`SessionRestoreModel` 退出时保存标签集，下次启动恢复。
- **G10 截图 / 页面保存**：`PageCaptureModel` 按标题生成合法文件名，快照 PNG 存到下载目录。
- **G11 垂直多标签栏（Floorp 式）**：`VerticalTabsModel` 支持分组折叠、组内重排、折叠组隐藏。
- **G12 扩展 / 用户脚本**：`UserScriptStore` 脚本 CRUD + URL 通配匹配，按 URL 注入当前页。
- **G14 面板内全局手势**：`MouseGestureModel` 把拖拽量化为方向并映射前进/后退/刷新；
  仅在面板内本地监听，不注册全局钩子、不抢前台。

**G13（跨设备同步 / 账号）**继续明确**不做**——与「本地优先」哲学冲突，详见 §5。

验证：`npm run typecheck`（exit 0）、`npm test`（后台全绿）、`npm run lint`
（17 个 Swift 文件、0 问题）、`scripts/build-app.sh`（产物 DeepSeekHarness.app 构建成功）。

---

## 1. 现状盘点（已具备，作为差异点守住）

- 原生 AppKit/WebKit 外壳，服务留在本机，不依赖浏览器打开。
- 内置浏览器面板（`Cmd+B`，WKWebView 实时渲染、`orderFront` 不抢前台、`becomesKeyOnlyIfNeeded`）。
- 地址栏搜索（`BuiltinBrowserAddress`：URL / host / 搜索词 → Bing 模板）。
- 多标签（`BrowserTabManager`：增删/选中/前后切换）—— 但 UI 是简单横向标签，无分组/工作区。
- 本地离线语音输入（`VoiceController` + `VoiceInputModel`，SFSpeechRecognizer，剪贴板桥，`⌘⇧M`）。
- 状态反馈条 + 可访问标签（toolTip / VoiceOver）。
- profile 完整性检查、LaunchAgent 生命周期、Windows 配套构建。

## 2. 缺口清单与优先级

> P0 = Must（强烈建议本次或近期补齐，价值/性价比高）；
> P1 = Should（有明显价值，排下次迭代）；
> P2 = Could（锦上添花）。

### P0（高性价比、可本次落地）

| # | 缺口 | 竞品出处 | 说明与落地建议 |
|---|---|---|---|
| G1 | **命令/查找栏（⌘T）** | Arc/Raycast/Floorp/Orion | 在浏览器面板顶部加一个「当前焦点即地址栏」的查找框，输入网址/搜索/书签/**命令**（如 `→ 新建标签`、`→ 复制链接`、`→ AI 总结当前页`）。实现轻、交互价值大，最贴近竞品「command bar」。 |
| G2 | **书签/收藏与历史** | Arc/Raycast/Floorp/Orion | 当前逐 panel 不落盘。补一个轻量本地书签（用户添加）+ 最近访问历史，接入查找栏。用 UserDefaults/plist 即可，纯本地、符合隐私基调。 |
| G3 | **「对当前页面提问 / 总结」接到本地 DSH** | Arc Max/SigmaOS Airis/Raycast AI | 把面板当前页 URL/标题/正文摘要喂给本地 DSH LLM，返回总结/问答显示在侧边小窗。这是对接本体价值高地的第一步，也是与「桌面 AI 客户端」区分的差异点。 |
| G4 | **垂直标签 / 标签分组（工作区）** | Arc/SigmaOS/Floorp | 当前横向标签无法容纳多标签。改为可选垂直侧栏标签 + 简单分组（按域名/主题），无需到 Arc 的完整 Spaces，先做「分组折叠」。 |
| G5 | **页面内站内搜索（find-in-page）** | Orion/Arc/Floorp | WKWebView 原生 `findString` 接口即可实现 `⌘F` 高亮搜索，成本低、竞品普遍具备。 |

### P1（有价值的迭代）

| # | 缺口 | 说明 |
|---|---|---|
| G6 | **分屏 split-view 并排** | 同窗并排两个网页；实现要在 BrowserTabManager 之上加「分屏对」，成本中等。 |
| G7 | **键盘快捷键集**（⌘T 新建标签页、⌘W 关闭、⌘1-9 切标签、⌘F 搜索、⌘L 定位地址栏） | 补齐 `main.swift` 的 `performKeyEquivalent` / menu keyEquivalent，当前导航/标签操作没有快捷键。 |
| G8 | **AI 命令填空（prompt 命令）** | 仿 Raycast/Arc：预设若干 prompt（翻译/总结/重写/取关键词），接到本地 DSH，替代手打。 |
| G9 | **会话与标签的生命周期关联** | 关闭面板/退出时保留打开的标签集，下次恢复（session restore），对齐浏览器行为。 |
| G10 | **截图 / 页面保存** | 当前页截图存图、整页 PDF/存档，竞品几乎都有；WKWebView 支持 `takeSnapshot`。 |

### P2（锦上添花 / 长期）

| # | 缺口 | 说明 |
|---|---|---|
| G11 | 垂直标签 + 多标签栏（Floorp 式） | 更复杂的标签管理布局。 |
| G12 | 扩展 / 用户脚本（站点定制） | 需 WKUserScript 机制 + 管理 UI，工作量大。 |
| G13 | 跨设备同步 / 账号 | 与本项目「本地优先」哲学冲突，**建议明确不做**，并在 README 说明差异优势。 |
| G14 | 全局手势 / 鼠标扩展 | 成本高、收益边际。 |

## 3. 本次交付的落地范围（建议）

在「一次交付、可验证」前提下，建议本次落地 **P0：G1（命令/查找栏）、G2（书签+历史）、G4（垂直
标签可选+分组）、G5（站内搜索）**，并把 **G3（AI 总结当前页→本地 DSH）** 与 **G7（快捷键集）** 作为
直接可用的增强一并补齐。G6/G8/G9 等列入 Roadmap，不阻塞本次交付。

> 这些缺口都以「纯本地、不抢前台、可单测」为约束实现；继续守住差异优势。

## 4. 验收标准（本次补齐后的定义）

- `Cmd+B` 唤出面板：顶部有查找栏，输入网址/域名/搜索词/命令都可用（已有地址解析扩展为命令）。
- 垂直标签可选 + 按域名自动分组（或手动分组），分组可折叠。
- `⌘F` 打开站内搜索高亮（find-in-page）。
- 书签：一键收藏当前页 + 查找栏可检索书签/历史。
- 快捷键：⌘T 新建、⌘W 关闭、⌘L 定位、⌘1-9 切标签。
- `npm test` / `npm run typecheck` / `npm run lint` 全绿，且新增逻辑有单测证据；`build-app.sh` 可复现。
- 交付文档：本报告 + competitive-analysis.md + CHANGELOG 更新。

## 5. 明确不做（保护差异）

- 账号体系/云同步（G13）。
- 全局拾取/系统级键盘钩子之外的能力（避免越权与「抢前台」）。
- 任何会上传语音/网页数据的云端功能（本地优先为基石）。
