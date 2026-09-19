# 架构拆分与实现规划（Alpha 架构师交付）

> 输入：阶段一竞品/需求缺口报告的**缺口清单**。输出：模块边界、实现顺序、验收标准、voice 可行性结论。
>
> **交付状态（2026-08-27 重核）**：P0（lint/typecheck）、P1（voice 输入）、P2（voice 输出入口）已落地并通过验证；**阶段一《竞品调研报告》《需求缺口分析报告》尚未落盘（Hotel 待办）**，P3 浏览器缺口项与 P4 收尾仍以其为输入。本文所有「已核验」结论均来自本机真实命令输出，见文末证据附录。

## 1. 现状基线（已核验）

| 维度 | 现状 |
|---|---|
| 外壳 | `App/DeepSeekHarnessApp/main.swift`（780 行，AppKit+WebKit，单文件）+ `BuiltinBrowserAddress.swift`（纯 Foundation） |
| 主窗口 | WKWebView 加载 `127.0.0.1:3080`，启动/就绪轮询、LaunchAgent 拉起、启动失败/依赖冲突告警 |
| 内置浏览器 | `BrowserPaneController`（NSPanel，`orderFront`+`becomesKeyOnlyIfNeeded` 不抢前台，Cmd+B），地址栏搜索已接 `BuiltinBrowserAddress.resolve` |
| 构建 | `scripts/build-app.sh`（zsh + swiftc + LaunchAgent 模板 + profile-doctor 守卫），编译 4 个 Swift 源并链接 Speech/AVFoundation |
| 测试 | `npm test` = `node --test`，**16 条全绿**（package 集成断言 + profile-doctor 单测 + Swift 地址解析契约测试 + voice 纯逻辑契约测试） |
| 本阶段已补齐 | voice 输入（`VoiceInputModel` 纯逻辑 + `VoiceController` 适配 + `ClipboardVoiceBridge`）、`npm run lint` / `npm run typecheck`、`Info.plist` 两个权限 key、CHANGELOG、README/TUTORIAL 的 voice 段落 |
| 仍缺失（下游待办） | `CONTEXT.md`、macOS CI、命令面板/标签页/书签（P3，待缺口报告定优先级）、阶段一《竞品调研报告》《需求缺口分析报告》（Hotel 尚未落盘） |

**深度评估**：`BuiltinBrowserAddress.resolve` 与 `VoiceInputModel` 是全仓库两个深模块样板——纯 Foundation、无 AppKit 依赖、可独立 `swiftc` 单测；`VoiceController`/`BrowserPaneController` 是薄 AppKit 胶水。这一「纯逻辑 + 胶水」分层已被 voice 落地验证，后续新模块继续沿用该形态。

## 2. 本机能力盘点（已核验）

| 能力 | 地址/包 | 状态 | 对 voice 的意义 |
|---|---|---|---|
| DSH 服务 | `127.0.0.1:3080` | `200` 在线 | App 的宿主 UI |
| vision-gateway | `127.0.0.1:8000/health` | ok，reasoning=DeepSeek-V4-Flash，vision=qwable-fable5:9b，protocols=chat/anthropic/responses | **仅图→文，无音频协议** |
| Ollama 模型 | `api/tags` | qwable-fable5(completion+vision)/qwen2.5:3b 等 | **无任何 ASR/audio 模型** |
| `@dsh-voice/bundle` | `~/.dsh/profiles/web/node_modules/@dsh-voice` v0.1.0 | 已装 | `transcribe`(STT) + `speak`(TTS) 工具 |
| `dsh-mac-control` | v0.1.5 | 已装 | `mac_browser`/`mac_desktop`（UI 自动化、截图），无语音 |
| @dsh-voice STT 后端 | `whisper-local`(whisper.cpp) / `macos`(SFSpeechRecognizer) / `openai` / `selection` | 已装 | 本机离线转写可用 |
| @dsh-voice TTS 后端 | `say`(macOS) / `edge-tts` / `piper` / `openai` | 已装 | 本机 `say` 可朗读 |

## 3. 术语表（可原样提升为 `CONTEXT.md`）

- **App 外壳（App Shell）**：仓库产出的 AppKit/WebKit 原生壳；只呈现本地 DSH UI，不实现任何 agent 能力。
- **DSH 运行时（DSH Runtime）**：用户自管的 DeepSeek Harness 服务（`127.0.0.1:3080`），独立安装、独立更新。
- **内置浏览器面板（Builtin Browser Panel）**：App 内 Cmd+B 唤出的独立 NSPanel + WKWebView，实时渲染、不抢前台。
- **接缝（Seam）**：模块接口所在位置，可在此替换行为而不改调用方。
- **桥（Bridge）**：App 与 DSH Web UI 之间搬运文本/动作的适配器。
- **语音输入（Voice Input）**：麦克风→转写文本→注入 DSH 输入框。
- **语音输出（Voice Output）**：agent 回复的朗读。

## 4. 阶段一缺口 → 实现映射（下游消费契约）

Hotel 的缺口清单按此表落位；`模块` 列即下文 M1–M5，`接缝` 列定义新代码插在哪。优先级由缺口报告定，本文只承诺 P0/P1 落地。

| 常见缺口（示例） | 落位模块 | 接缝 | 说明 |
|---|---|---|---|
| voice 语音输入 | M3 | `VoiceController` / `VoiceBridge` | **用户点名，最高优先，已落地** |
| voice 语音输出 | M3 | 复用 `@dsh-voice speak`，不重写 | 已存在，App 只做文档入口 |
| 内置浏览器标签/会话管理 | M2 | `BrowserPaneController` 内新增 tab 状态 | 仅当缺口报告评 P0/P1 |
| 书签/同步 | M2 | 新增 `BrowserBookmarks`（纯 Foundation） | 深模块，先纯逻辑后 UI |
| 命令面板 | M1 | `configureMenus` 旁新增 `CommandPalette` | 依赖缺口优先级 |
| 多账号/隐私沙箱 | M1 | WKWebView `WKWebsiteDataStore` 隔离 | 涉及 DSH profile 语义，谨慎 |
| 外部链接处理 | M1/M2 | `decidePolicyFor` 已部分实现 | 已有，缺口报告若无新增则不动 |
| 搜索增强 | M2 | `BuiltinBrowserAddress.resolve` 已实现 | 已有 |

> 纪律：缺口项先问「是否已有接缝」（如外部链接、搜索已实现），避免重复造轮子；没有接缝的按 P0→P1 顺序新开模块，且一律先纯逻辑（可 `swiftc` 单测）后 AppKit 胶水。

## 5. 模块边界（深模块设计）

### M1 — App 外壳（生命周期 + 菜单 + 服务守护）

- **接口**：`ensureHarnessIsRunning(forceReload:)`、`configureMenus()`、窗口生命周期。
- **实现**：LaunchAgent 控制（`runLaunchctl`）、就绪轮询（`checkServer`）、启动失败/依赖冲突告警。
- **接缝**：`checkServer` 就绪探针已独立；`runLaunchctl` 已隔离。新能力（命令面板、隐私沙箱）挂在 `configureMenus`/`createWindow` 旁。
- **深度**：中。就绪探测与 LaunchAgent 语义复杂但接口窄，已有。**不动核心逻辑**，除非缺口报告点名。

### M2 — 内置浏览器面板

- **接口**：`toggleBrowser()`、`BuiltinBrowserAddress.resolve(_:) -> URL?`。
- **实现**：NSPanel 构建、WKWebView 导航、`decidePolicyFor` 白名单、新窗口在面板内打开。
- **接缝**：地址解析已是纯 Foundation 深模块（样板）。标签/书签若落地，纯逻辑放 `BuiltinBrowserTabs`/`BuiltinBrowserBookmarks`，UI 挂在 `BrowserPaneController`。
- **深度**：地址解析=深；面板控制器=中（UI 胶水为主，可接受）。

### M3 — Voice 集成（已落地）

分层（复制 `BuiltinBrowserAddress` 的成功形态，已实现）：

```
VoiceController（AppKit/Speech 适配器，薄）
   │  produce transcript / speak
   ▼
VoiceInputModel（纯 Foundation，深）：权限状态机、语言选择、转写结果归一化
   │
   ▼
VoiceBridge（接缝）：deliver(text) → DSH 输入框
   ├─ ClipboardBridge（默认，稳健，已落地）
   └─ JSInjectionBridge（evaluateJavaScript，需 DSH 稳定 hook 后启用）
```

- **接口**：`VoiceController.requestTranscription() -> Transcription`、`VoiceController.speak(_:)`、`VoiceBridge.deliver(_:)`。
- **接缝**：`VoiceBridge` 两个适配器共享同一接口 = **真实接缝**（可替换策略）。纯逻辑 `VoiceInputModel` 无 AppKit 依赖、可 `swiftc` 单测。
- **深度**：`VoiceInputModel` 为深模块（权限+归一化+语言回退藏在小接口后）；`VoiceController` 薄胶水。

### M4 — 测试

- **接口**：`npm test`（唯一入口，`node --test` 驱动一切，含 Swift 契约测试）。
- **现状**：`lint`/`typecheck` 脚本与 voice 契约测试已补；仍缺 macOS CI。
- **接缝**：新增脚本挂 `package.json` `scripts`；Swift 契约测试沿用 `tests/builtin-address.test.swift` 的 `swiftc` 编译运行模式。

### M5 — 文档

- **现状**：CHANGELOG、README/TUTORIAL voice 段落、`docs/architecture.md`（本文）、`docs/qa-charlie-frontend.md` 已落盘。
- **待办**：`CONTEXT.md`（本文第 3 节可原样提升）、ADR 提取（第 6 节）、最终交付报告（Lima）。

## 6. Voice 可行性结论 + 决策记录（ADR 式）

### 结论（已核验，且已落地）

1. **语音输入 = App 原生 `SFSpeechRecognizer`（本机离线转写）+ `VoiceBridge` 注入 DSH 输入框**。zh-CN/en-US 本机离线支持，零网络、零 key、零新依赖。（已落地：`VoiceInputModel` + `VoiceController` + `ClipboardVoiceBridge`）
2. **语音输出 = 复用 `@dsh-voice` 的 `speak`（本机 `say`）**，App 不重写 TTS（删除测试：DSH 已能朗读，App 重写只会把复杂度搬回两处）。已落地为文档指向，无新代码。
3. **vision-gateway 不进语音链路**：它只做图→文，本机无音频模型，扩展它属于新增活动件。视觉规则不受影响。

### 触发键 / 转写 / 命令执行链路（已落地，已核验）

```
触发键（trigger）
├─ Cmd+Shift+M —— App 菜单「语音输入」（keyEquivalent "m" + [.shift, .command]）
└─ 浏览器面板工具栏 🎤 按钮 —— 与菜单共享同一 `VoiceController` 实例，状态反馈一致

转写（transcription，本机离线）
└─ `VoiceController.startRecording()`
   ├─ 权限门：`SFSpeechRecognizerAuthorizationStatus` → `VoiceInputModel.Permission`
   │   ├─ denied/restricted → `.unavailable(reason)`，UI 禁用
   │   └─ undetermined → `requestAuthorization` 授权后重入；authorized → 继续
   ├─ `AVAudioApplication.requestRecordPermission`（麦克风授权）
   └─ `SFSpeechRecognizer(locale: zh-CN)` + `AVAudioEngine` installTap 采集
       `shouldReportPartialResults = true` 实时出字 → `onStateChange(.listening)`

命令执行链路（deliver）
└─ 结束/停止 → `VoiceInputModel.normalizedTranscript(_:)`（修剪/折叠空行/CRLF 归一化；空→nil 不提交）
   → `VoiceBridge.deliver(text)`
      └─ 默认 `ClipboardVoiceBridge`：写 `NSPasteboard.general` + `CGEvent` 合成 Cmd+V 粘贴到当前聚焦输入框
   → `onStateChange` 驱动 UI：`idle → listening → processing → idle`（投递失败 → `.unavailable`）
```

### 决策记录（建议 Kilo 提升为 `docs/adr/0001-voice-input-app-native.md`）

- **决策**：语音输入走 App 原生 SFSpeechRecognizer + 剪贴板桥（默认）/JS 注入桥（可选）；语音输出复用 @dsh-voice `say`。
- **备选（已否决）**：A. 经 vision-gateway 加音频端点——本机无 ASR 模型，纯增复杂度；B. 经 @dsh-voice `transcribe` 作为 App 的语音入口——transcribe 是 DSH agent 内工具，App 无法从壳外触发，且语义是「变成用户消息」而非「填输入框」。
- **满足 ADR 三条件**：① 难逆转（一旦依赖 DSH DOM hook 就绑死上游）；② 无上下文会疑惑（「为何不用 vision-gateway」）；③ 真实取舍（离线 Apple 转写 vs 复用 DSH 工具 vs 扩展网关）。

### 落地状态（已核验，与规划一致）

- `Info.plist` 已声明 `NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription`（源 `App/DeepSeekHarnessApp/Info.plist` 与 `DeepSeekHarness.app` 产物均已 grep 命中）；`lint.mjs` 守护这两个 key 不丢失。
- 剪贴板桥已按规划落地为默认实现（`ClipboardVoiceBridge`）；`VoiceBridge` 协议保留为接缝，JS 注入桥（`JSInjectionBridge`）仅待 DSH 稳定 DOM hook 后新增，不改调用方。
- voice 输出的 `speak` 未在 App 内重复实现——README/TUTORIAL 明示复用 DSH `@dsh-voice`（`say`），符合删除测试。

## 7. 实现顺序（依赖排序 + TDD，含当前状态）

| 阶段 | 类型 | 内容 | 状态 | 验收证据 |
|---|---|---|---|---|
| P0 | chore | `lint`/`typecheck` 脚本、`CHANGELOG.md` | ✅ 已交付 | `npm run typecheck` exit 0；`npm run lint` "0 problems" |
| P1 | feat | Voice 输入：`VoiceInputModel`（纯逻辑红绿）→ `VoiceController`（SFSpeechRecognizer 适配）→ `VoiceBridge`（剪贴板桥） | ✅ 已交付 | `voice-input.test.swift` 契约测试（权限/语言回退/空转写）随 `npm test` 通过；plist 两 key 已补 |
| P2 | feat/docs | Voice 输出入口 + 文档指向 @dsh-voice `say` | ✅ 已交付 | README/TUTORIAL 明示复用，App 不重复 TTS |
| P3 | feat | 内置浏览器缺口项（标签/书签，仅缺口报告 P0/P1 项） | ⏳ 待缺口报告 | 纯逻辑 `swiftc` 单测 0 failures |
| P4 | docs | `CONTEXT.md`、ADR 提取、QA/交付记录 | ⏳ 部分待办 | `npm test` 文档断言通过 |

> 依赖约束（现状）：P0/P1/P2 已闭环；P3 依赖 Hotel 的缺口报告给优先级；P4 剩余 `CONTEXT.md` 与 ADR 提取（Kilo），最终交付报告由 Lima 汇总。

## 8. 验收标准汇总

- `npm test` 全绿：**16/16 pass, 0 fail**（已核验，含 voice 与 builtin-address 两条 TDD 契约测试）。
- `npm run typecheck` 退出 0（4 个 Swift 源，含 Speech/AVFoundation 框架）。
- `npm run lint` 退出 0（4 Swift 文件 0 problems，守护 plist 权限 key 与测试接线）。
- `scripts/build-app.sh` 在干净 runtime fixture 上可复现产出 `.app`（`tests/package.test.mjs` 已断言，保持）。
- voice 纯逻辑契约测试（权限拒绝 / 语言回退 / 空转写 / 语言归一等）可独立 `swiftc` 编译运行，0 failures。
- 每处变更 commit 满足 Conventional Commits，且能对应到「红→绿→重构」证据（`chore: add reproducible typecheck and lint scripts`、`feat: add offline voice input and browser panel UI feedback`、`docs: add architecture breakdown and implementation plan`）。
- 无法验证项（如真机麦克风需交互授权）如实标注，不谎称通过。

## 9. 风险与阻塞

| 风险 | 等级 | 缓解 |
|---|---|---|
| 麦克风/语音权限需用户授权，CI 无法全自动 | 中 | 权限状态机单测 + 真机手工闭环，CI 只跑纯逻辑 |
| DSH Web UI 输入框 DOM 不控 | 中 | 默认剪贴板桥（已落地），JS 注入桥后置 |
| vision-gateway 视觉规则被误套到语音 | 低 | 本文第 6 节明示不套用，视觉链路保持不变 |
| Windows 配套与 macOS 新增模块漂移 | 低 | voice 仅 macOS 原生；`package.test.mjs` 已断言 Windows 产物，保持 |
| 阶段一缺口报告缺失 → P3/P4 无法定优先级 | 中 | Hotel 补齐《竞品调研报告》《需求缺口分析报告》后，按第 4 节映射表落位 |

## 附录：验证证据（本机真实输出，2026-08-27）

```
$ npm test
  → ℹ tests 16 / pass 16 / fail 0（含 "voice input model passes its pure-logic contract test (TDD)"
    与 "built-in browser address bar turns search terms into an in-panel search (TDD)"）
$ npm run typecheck
  → exit 0（main/BuiltinBrowserAddress/VoiceInputModel/VoiceController，含 -framework Speech/AVFoundation）
$ npm run lint
  → "lint ok — 4 Swift file(s), 0 problems"，exit 0
$ grep -E 'NSMicrophoneUsageDescription|NSSpeechRecognitionUsageDescription' App/DeepSeekHarnessApp/Info.plist
  → 两个 key 均命中（源与 DeepSeekHarness.app/Contents/Info.plist 产物一致）
$ curl -s http://127.0.0.1:8000/health
  {"status":"ok","reasoning_model":"DeepSeek-V4-Flash","vision_model":"qwable-fable5:9b-q4_k_m","protocols":{...}}   ← 无音频协议
$ curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3080/  → 200
$ curl -s http://127.0.0.1:11434/api/tags
  → qwable-fable5(capabilities: completion,vision)、qwen2.5:3b … 均无 ASR/audio
$ ls ~/.dsh/profiles/web/node_modules/@dsh-voice/bundle/lib/backends
  → whisper-local / macos / openai / selection（STT），edge-tts / piper / say / openai（TTS）
$ grep -E '"name"|"version"' ~/.dsh/profiles/web/node_modules/dsh-mac-control/package.json  → dsh-mac-control 0.1.5
```

（本文件是 Alpha 架构师的交付物；阶段二实现按第 7 节顺序由 Bravo/Charlie 执行，Foxtrot 复核，Kilo 补文档，Lima 汇总交付报告。）
