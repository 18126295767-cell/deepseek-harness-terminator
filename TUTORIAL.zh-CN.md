# DeepSeek Harness Terminator：可复现构建教程

语言 / Language: 简体中文 · [English](TUTORIAL.md)

本教程从源码构建原生 macOS 外壳，并将它连接到本地 DeepSeek Harness 运行时。
它不会获取或嵌入 API 密钥、插件、用户会话或日志。

## 1. 环境要求

- Apple Silicon Mac，macOS 12 或更高版本
- Xcode Command Line Tools（可执行 `xcode-select --install`）
- Node.js 22 或更高版本
- 一个包含 `@deepseek-ai/dsh/lib/bin.js` 的本地 DSH 运行时

检查工具：

```bash
swiftc --version
node --version
```

## 2. 准备运行时

请单独安装 DeepSeek Harness，并记录运行时目录的绝对路径。已有本地运行时可执行：

```bash
cd /绝对路径/dsh-runtime
test -f node_modules/@deepseek-ai/dsh/lib/bin.js
```

在没有加入工作区、账号或凭据之前，隔离的新 runtime 应显示为：

![配置前的 DeepSeek 官方 DSH Web runtime](docs/images/macos-dsh-home.png)

下面的高清截图展示安全的首次配置流程。公开素材中的 API 密钥输入框是空的；真正的密钥
只应填写在你本机 runtime 的设置中，绝不要复制到仓库文件、提交记录或 issue。

![内测说明](assets/screenshots/macos-01-developer-preview.jpg)
![API Key 首次配置，输入框为空](assets/screenshots/macos-02-api-key-onboarding.jpg)
![配置后的空白工作区](assets/screenshots/macos-03-empty-workspace.jpg)

请在运行时自己的设置中配置模型供应商和 API 密钥。不要把凭据放进本仓库、提交记录、
截图或 issue。

## 3. 构建

本公开仓库采用标准嵌套源码目录。在仓库根目录执行：

```bash
zsh ./scripts/build-app.sh \
  --dsh-runtime /绝对路径/dsh-runtime \
  --output ./build
```

输出为 `build/DeepSeekHarness.app`。脚本会编译 `main.swift`、复制 plist 和图标，不会
修改 DSH 运行时。

通过 `zsh` 调用脚本，不依赖源码归档可能未保留的可执行位。同一脚本仍会
自动识别旧的扁平导出布局，以保持向后兼容。

## 4. 安装和启动

```bash
zsh ./scripts/build-app.sh \
  --dsh-runtime /绝对路径/dsh-runtime \
  --install
open "$HOME/Applications/DeepSeek Harness Terminator.app"
```

原生外壳应当在 macOS 窗口中显示同一个本地 DSH 工作区：

![DeepSeek Harness Terminator 原生 macOS 外壳](docs/images/macos-app-home.png)

打开设置后，模型页面只能显示提供商是否已配置，不应显示已保存的密钥原文。下面的模型和
插件示例同样经过脱敏：

![模型设置，API 密钥输入框为空](assets/screenshots/macos-04-model-settings.jpg)
![插件列表](assets/screenshots/macos-05-plugin-inventory.jpg)

LaunchAgent 会生成到
`~/Library/LaunchAgents/com.houxinran.deepseek-harness.plist`，日志位于
`~/Library/Logs/DeepSeekHarness.log`。

生成的 LaunchAgent 会在 DSH 启动前运行随 App 打包的 profile 检查器。也可以单独执行：

```bash
node scripts/profile-doctor.mjs \
  --runtime /绝对路径/dsh-runtime \
  --profile-dir "$HOME/.dsh/profiles/web"
```

不要通过删除检查器来掩盖冲突。应升级或移除报告中的插件，或者把该插件对 DSH 宿主
核心包的声明从 `dependencies` 改为 `peerDependencies`。

### 使用内置浏览器

应用自带一个**内置浏览器面板**，按 `Cmd+B` 打开/收起。它是基于 `WKWebView` 的
**实时渲染**视图（不是截图），页面按原方向、原角度显示；面板是 `.utilityWindow` 辅助
窗口，打开时用 `orderFront` 且不调用 `NSApp.activate(ignoringOtherApps:)`，并设置
`becomesKeyOnlyIfNeeded = true`，因此**不会抢占其他应用的前台焦点**——只有你主动点击
地址栏或面板内容时才成为 key 窗口。

- 在地址栏输入网址后回车即可访问；`http`/`https`/`view-source` 在面板内打开，其余协议
  交给系统默认应用。
- 在地址栏输入其它内容（如 `苹果`）即可直接在面板内搜索——无需外部浏览器。
- 后台/新窗口请求会留在面板内加载，不会弹出额外窗口抢前台。
- 面板底部有一根状态条（`就绪`/`加载中…`/失败原因）；工具栏每个按钮都有提示与可访问标签。
- **向当前输入框语音输入**：*DeepSeek Harness → 语音输入*（`⌘⇧M`）或浏览器面板的 🎤 按钮。
  转写在本机完成（zh-CN / en-US）并粘贴到当前聚焦的输入框；首次使用请在
  「系统设置 → 隐私与安全性」授予麦克风与语音识别权限。
- 渲染引擎是 Apple 的开源 WebKit（`WKWebView`），协议与许可证说明见 `NOTICE`。

## 5. 验证可复现性

检查生成的 App 是 Apple Silicon 可执行文件，并确认 plist 有效：

```bash
file build/DeepSeekHarness.app/Contents/MacOS/DeepSeekHarness
plutil -lint build/DeepSeekHarness.app/Contents/Info.plist
```

验证成功时，`file` 应显示 Mach-O 64 位 arm64 可执行文件，`plutil` 应返回 `OK`。

App 应只连接 `http://127.0.0.1:3080/`；外部链接应交给系统浏览器。若本地服务尚未就绪，
App 会显示中文启动状态并重试，失败后提示日志位置。

## 6. Windows 配套环境

Windows 包是官方 DSH Web runtime 的独立启动器。它不包含 runtime 或凭据，也不会把
仅适用于 macOS 的 `dsh-mac-control` 工具变成 Windows 工具。环境要求是 Windows 10/11
x64、PowerShell 5.1 或 7，以及用于准备环境的 `winget`。

从源码目录准备 Windows 构建机：

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

该脚本通过 `winget` 安装 Git、Node.js LTS 和 NSIS，并在 `$HOME\dsh-runtime` 创建单独的
`@deepseek-ai/dsh@0.1.0-rc.7` runtime。给 Windows `web` profile 添加插件前，请先审阅
主仓库教程中的提交固定命令。安装器改变 `PATH` 后请重新打开 PowerShell。

在 Windows 上构建发布产物：

```powershell
& .\build-release.ps1 -Version 0.1.1
```

输出包括 `DeepSeek-Harness-Windows-x64-v0.1.1.zip`、
`DeepSeek-Harness-Setup-v0.1.1-x64.exe` 和 `.sha256` 校验文件。NSIS 安装器按当前用户
安装，不要求管理员权限。便携包包含 `launch-dsh.cmd`、`launch-dsh.ps1`、安装/卸载脚本、
12 种可选语言指南和 MIT 协议。

启动已安装的启动器：

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" `
  -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

它会等待 `127.0.0.1:3080` 就绪、打开默认浏览器，把日志写入
`%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`，并在启动器退出时停止子 DSH 进程。无头启动可用
`-NoBrowser`。GitHub Actions 会在 `windows-2025` runner 上调用同一个
`windows/build-release.ps1`，并上传 ZIP、安装器、哈希文件以及一组隔离生成的
`1600x1000` 教程截图。下方已经提交的 Windows 图片来自全新 Chromium profile，经过
逐张目检且不含凭据：

| 无凭据首次配置 | 空白工作区 |
| --- | --- |
| ![Windows API Key 配置，输入框为空](docs/images/windows/windows-02-api-key-onboarding.png) | ![Windows 空白工作区](docs/images/windows/windows-03-empty-workspace.png) |

模型设置、插件列表和机器可读证明见[完整 Windows 中文指南](windows/README.zh-CN.md)。

Windows 启动器会在监听端口前，对 `%DSH_HOME%\profiles\<profile>`（未设置时为
`%USERPROFILE%\.dsh\profiles\<profile>`）执行同一套物理副本检查。报告会指出冲突包和
引入者，但不会改动 profile。

## 故障排查

启动失败时检查日志和运行时路径：

```bash
tail -100 "$HOME/Library/Logs/DeepSeekHarness.log"
test -x "$(command -v node)"
test -f /绝对路径/dsh-runtime/node_modules/@deepseek-ai/dsh/lib/bin.js
```

如果 3080 端口已被占用，请停止冲突的本地服务，或同时修改 App 外壳和 LaunchAgent。不要
把其他用户的绝对路径写进公开提交。

Windows 出错时检查 `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`，确认 runtime 目录中存在
`node_modules\@deepseek-ai\dsh\lib\bin.js`，构建安装器失败时确认 NSIS 已安装。不要把
macOS 的 LaunchAgent 或 `osascript` 命令复制到 Windows 脚本中。

如果 profile 冲突后 API 报告 assistant `tool_calls` 后缺少工具消息，说明该会话已经保存
了不完整回合。请保留它作为记录，待依赖检查通过后，在新会话中重新发送原任务。
