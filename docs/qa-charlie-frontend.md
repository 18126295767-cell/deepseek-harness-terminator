# Charlie 前端交付 · 评审 / QA 记录

> 范围：内置浏览器面板与 App 界面的前端/UI 体验（WebKit 交互、地址栏搜索接线、面板悬浮不抢焦点、
> UI 状态反馈、voice 交互的界面入口）。遵循 web-design-guidelines 的精神与可访问性（原生 AppKit 控件）。

## 交付内容

| 项 | 说明 |
|---|---|
| 语音输入入口 | 菜单项 `⌘⇧M`（DeepSeek Harness → 语音输入）+ 内置浏览器面板 🎤 按钮；`VoiceController`（SFSpeechRecognizer + AVAudioEngine 本地离线转写）+ `ClipboardVoiceBridge` 注入输入框 |
| 语音纯逻辑 | `VoiceInputModel.swift`：权限状态机、语言归一化（zh-CN/en-US）、转写归一化（修剪/折叠空行） |
| 浏览器 UI 状态反馈 | 底部状态条：`就绪/加载中…/失败原因`；`didFailProvisionalNavigation`/`didFail` 显示原因，不弹窗打断 |
| 可访问性 | 工具栏全部按钮补 `toolTip` + `setAccessibilityLabel`；地址栏 `setAccessibilityLabel`；状态条 `setAccessibilityLabel("页面状态")`；麦克风按钮 `setAccessibilityValue` 随状态变化 |
| 权限声明 | `Info.plist` 增 `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription`（源文件与预建 bundle 均已同步） |
| 可复现验证 | `npm run typecheck`、`npm run lint`、`build-app.sh` 本地化 clang 模块缓存 |

## 验证证据（本机真实输出）

### 1. 类型检查（全源编译校验）
```bash
$ npm run typecheck
> swiftc -typecheck ... main.swift BuiltinBrowserAddress.swift VoiceInputModel.swift VoiceController.swift
（exit 0，无输出）
```

### 2. Lint
```bash
$ npm run lint
lint ok — 4 Swift file(s), 0 problems
```

### 3. 全量测试（16/16 通过，含新增 voice 契约测试）
```bash
$ npm test
✔ voice input model passes its pure-logic contract test (TDD)  (614.425833ms)
ℹ tests 16
ℹ pass 16
ℹ fail 0
```

### 4. 可复现构建（干净 runtime fixture 产出 .app，orig update 预建 bundle）
```bash
$ zsh scripts/build-app.sh --dsh-runtime <fixture> --output <tmp>
Built: .../DeepSeekHarness.app
```
结果二进制（arm64 Mach-O）已把 `Speech` / `AVFoundation` / `WebKit` / `AppKit`
全部链接（`otool -L` 核实），并刷新到 `App/.../DeepSeekHarness.app`。

## 无法全自动验证项（如实报告）

- **真机麦克风/语音识别**：首次授权需用户在「系统设置 → 隐私与安全性」授予麦克风与
  语音识别；CI/无交互环境无法全自动验证 SFSpeechRecognizer 实际出字。纯逻辑（权限状态机/
  归一化）已由 `tests/voice-input.test.swift` 覆盖；真机端到端录一句出转写需人工闭环。
- **剪贴板桥注入 DSH 输入框**：依赖「目标输入框当前聚焦」。默认采用剪贴板桥（稳健、不依赖
  DSH DOM）；面板内点 🎤 但焦点仍在面板时会粘贴到面板内而非 DSH 输入框——这是默认桥的
  已知语义，主入口是主窗口内 `⌘⇧M`。若需在面板内直连 DSH 输入框，属 M3 后置的 JS 注入桥。

## 设计说明

- **不抢前台**保持既有语义：面板 `orderFront` + `becomesKeyOnlyIfNeeded`，新增状态条与
  麦克风按钮均不改变该行为，未引入 `NSApp.activate`。
- **voice 不套视觉规则**：vision-gateway 只做图→文、本机无 ASR 音频模型，语音链路走
  App 原生 SFSpeechRecognizer，符合 Alpha 架构 M3 决策（ADR 式）。
- **UI 状态反馈**遵循「可感知反馈」原则：加载/失败可见；辅助功能值随语音状态更新。

## 未完成 / 阻塞

- 真机语音端到端验证（需交互授权 + 真实 GUI 会话）。
- 面板内直连 DSH 输入框的 JS 注入桥（依赖 DSH 稳定 DOM hook，后置）。
- macOS CI（非本角色阻塞，见 Kilo / Golf 收尾）。