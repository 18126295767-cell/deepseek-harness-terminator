import AppKit
import WebKit

private let harnessURL = URL(string: "http://127.0.0.1:3080/")!
private let serviceName = "com.houxinran.deepseek-harness"

// MARK: - 内置浏览器面板（不抢前台 · 实时渲染）

/// 一个只在前台应用未激活时作为后台面板出现的内置浏览器窗口。
/// 设计要点（对应需求）：
///  - 实时渲染：使用 WKWebView 直接加载网页，是可交互的实时视图，而非截图。
///  - 不抢前台：打开面板用 orderFront 而非 makeKeyAndOrderFront，
///    且默认不调用 NSApp.activate(ignoringOtherApps:)；只有用户主动点击
///    面板内的 WebView 或地址栏时才成为 key window（becomesKeyOnlyIfNeeded）。
final class BrowserPaneController: NSObject, WKNavigationDelegate, WKUIDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var panel: NSPanel!
    private var addressField: NSTextField!
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var homeButton: NSButton!
    private var reloadButton: NSButton!
    private var newTabButton: NSButton!
    private var bookmarkButton: NSButton!
    private var micButton: NSButton!
    private var pageStatusLabel: NSTextField!
    private var isPanelBuilt = false
    private var tabScrollView: NSScrollView!
    private var tabContainerView: NSView!

    /// 标签管理器（纯逻辑，无 AppKit 依赖）。
    private let tabManager = BrowserTabManager()
    /// 会话存储（书签 + 最近访问，纯 Foundation，UserDefaults 持久化）。
    private let sessionStore = BrowserSessionStore()

    /// 站内查找（find-in-page）状态机：查询词归一化、匹配计数、回绕导航。
    private let findModel = FindInPageModel()
    private var findBar: NSView!
    private var findField: NSTextField!
    private var findStatusLabel: NSTextField!

    /// 命令栏（⌘T）：检索书签/最近访问/命令，支撑键盘上下选择。
    private var commandPalette: CommandPalette?
    private var palettePanel: NSPanel!
    private var paletteField: NSTextField!
    private var paletteTable: NSTableView!
    /// 垂直标签分组开关（G4）。
    private var tabGroupingEnabled = false
    /// 垂直多标签栏分组（G11）：支持按站点分组 + 组折叠。
    private lazy var verticalTabs = VerticalTabsModel(groupingKey: { tab in
        self.tabManager.tabs.first { $0.id == tab.id }?.url.host ?? "其他"
    })
    /// 会话恢复（G9）：退出时保存标签集，下次启动恢复。
    private let sessionRestore = SessionRestoreModel(storage: UserDefaultsStorage())
    /// 是否已尝试恢复上次会话（避免重复恢复）。
    private var sessionRestored = false
    /// 用户脚本存储（G12）：按 URL 匹配注入到当前页面。
    private let userScripts = UserScriptStore(storage: UserDefaultsStorage())
    /// 面板内鼠标手势开关（G14，仅面板范围，不抢前台）。
    private var mouseGesturesEnabled = false
    /// 已注入的用户脚本记录（webView 地址 + URL + 脚本 id），避免 reload 重复注入（G12）。
    private var appliedScripts: Set<String> = []
    /// 面板手势的本地事件监听 token（开启时注册，关闭时移除）。
    private var gestureMonitor: Any?
    /// 手势拖拽起点（面板本地坐标）。
    private var gestureOrigin: NSPoint?
    /// 分屏开关（G6）。
    private var splitState = SplitPaneState()
    /// 分屏的副屏 webView。
    private var splitWebView: WKWebView?
    /// 每个标签对应的 WKWebView（按标签 id 索引）。
    private var webViews: [String: WKWebView] = [:]
    /// 当前选中标签的 webView（便捷访问）。
    private var selectedWebView: WKWebView? {
        guard let tab = tabManager.selectedTab else { return nil }
        return webViews[tab.id]
    }

    /// 语音输入控制器（由 AppDelegate 注入，与菜单共享同一实例，状态反馈一致）。
    var voiceController: VoiceController?

    private static let homeURL = URL(string: "https://www.apple.com")!

    /// 打开（或唤出）内置浏览器。不激活应用、不抢占前台。
    func showBrowser() {
        if !isPanelBuilt {
            buildPanel()
        }
        // 首次打开恢复上次会话（会话恢复只执行一次，无历史则自动开默认页）。
        restoreSessionIfNeeded()
        // 关键：orderFront 只是把面板显示到前面，不改变应用的激活状态，
        // 也不会让当前前台应用失焦。
        panel.orderFront(nil)
    }

    /// 以非激活方式隐藏面板（不会夺走其他应用焦点）。
    func hideBrowser() {
        if isPanelBuilt {
            panel.orderOut(nil)
        }
    }

    func toggleBrowser() {
        if isPanelBuilt, panel.isVisible {
            hideBrowser()
        } else {
            showBrowser()
        }
    }

    // MARK: 面板构建

    private func buildPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: 1080, height: 720)
        // 使用辅助面板样式（utility window）：不进入任务切换器，不主动抢 key。
        panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "内置浏览器"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true      // 只有用户点击内容才成为 key window
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let content = NSView(frame: contentRect)

        // ---- 顶部工具栏 ----
        let toolbarHeight: CGFloat = 44
        let toolbar = NSView(frame: NSRect(x: 0, y: contentRect.height - toolbarHeight,
                                           width: contentRect.width, height: toolbarHeight))
        toolbar.autoresizingMask = [.width]

        let backButton = makeButton(title: "◀︎", action: #selector(goBack(_:)))
        let forwardButton = makeButton(title: "▶︎", action: #selector(goForward(_:)))
        let reloadButton = makeButton(title: "⟳", action: #selector(reloadPage(_:)))
        let homeButton = makeButton(title: "⌂", action: #selector(goHome(_:)))
        let newTabButton = makeButton(title: "+", action: #selector(newTab(_:)))
        let bookmarkButton = makeButton(title: "☆", action: #selector(toggleBookmark(_:)))
        let micButton = makeButton(title: "🎤", action: #selector(toggleVoice(_:)))

        // 可访问性：给纯符号按钮补充 tooltip 与可访问标签（VoiceOver 可读）。
        backButton.toolTip = "后退"
        backButton.setAccessibilityLabel("后退")
        forwardButton.toolTip = "前进"
        forwardButton.setAccessibilityLabel("前进")
        reloadButton.toolTip = "刷新"
        reloadButton.setAccessibilityLabel("刷新")
        homeButton.toolTip = "主页"
        homeButton.setAccessibilityLabel("主页")
        newTabButton.toolTip = "新建标签页"
        newTabButton.setAccessibilityLabel("新建标签页")
        bookmarkButton.toolTip = "收藏当前页（☆）"
        bookmarkButton.setAccessibilityLabel("收藏当前页")
        micButton.toolTip = "语音输入"
        micButton.setAccessibilityLabel("语音输入")

        backButton.frame = NSRect(x: 8, y: 6, width: 34, height: 30)
        forwardButton.frame = NSRect(x: 48, y: 6, width: 34, height: 30)
        reloadButton.frame = NSRect(x: 88, y: 6, width: 34, height: 30)
        homeButton.frame = NSRect(x: 128, y: 6, width: 34, height: 30)
        newTabButton.frame = NSRect(x: 168, y: 6, width: 34, height: 30)

        addressField = NSTextField(frame: NSRect(x: 208, y: 6,
                                                 width: contentRect.width - 260, height: 30))
        addressField.placeholderString = "输入网址或搜索词后回车"
        addressField.font = .systemFont(ofSize: 13)
        addressField.target = self
        addressField.action = #selector(addressSubmitted(_:))
        addressField.autoresizingMask = [.width]
        addressField.setAccessibilityLabel("地址栏：输入网址或搜索词")

        micButton.frame = NSRect(x: contentRect.width - 44, y: 6, width: 36, height: 30)
        micButton.autoresizingMask = [.minXMargin]

        bookmarkButton.frame = NSRect(x: contentRect.width - 86, y: 6, width: 36, height: 30)
        bookmarkButton.autoresizingMask = [.minXMargin]

        toolbar.addSubview(backButton)
        toolbar.addSubview(forwardButton)
        toolbar.addSubview(reloadButton)
        toolbar.addSubview(homeButton)
        toolbar.addSubview(newTabButton)
        toolbar.addSubview(bookmarkButton)
        toolbar.addSubview(addressField)
        toolbar.addSubview(micButton)

        self.backButton = backButton
        self.forwardButton = forwardButton
        self.reloadButton = reloadButton
        self.homeButton = homeButton
        self.newTabButton = newTabButton
        self.bookmarkButton = bookmarkButton
        self.micButton = micButton

        // ---- 标签栏（工具栏下方，显示所有标签）----
        let tabBarHeight: CGFloat = 28
        let tabBar = NSView(frame: NSRect(x: 0, y: contentRect.height - toolbarHeight - tabBarHeight,
                                          width: contentRect.width, height: tabBarHeight))
        tabBar.autoresizingMask = [.width]
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // 可水平滚动的标签容器
        tabScrollView = NSScrollView(frame: NSRect(x: 4, y: 2, width: contentRect.width - 8, height: tabBarHeight - 4))
        tabScrollView.hasVerticalScroller = false
        tabScrollView.hasHorizontalScroller = true
        tabScrollView.autohidesScrollers = true
        tabScrollView.borderType = .noBorder
        tabScrollView.autoresizingMask = [.width]

        tabContainerView = NSView(frame: NSRect(x: 0, y: 0, width: contentRect.width - 8, height: tabBarHeight - 4))
        tabScrollView.documentView = tabContainerView

        tabBar.addSubview(tabScrollView)
        content.addSubview(tabBar)

        // ---- 站内查找条（默认隐藏，⌘F 唤起；位于标签栏与 WebView 之间）----
        let findBarHeight: CGFloat = 30
        let findBar = NSView(frame: NSRect(x: 0, y: contentRect.height - toolbarHeight - tabBarHeight - findBarHeight,
                                           width: contentRect.width, height: findBarHeight))
        findBar.autoresizingMask = [.width]
        findBar.wantsLayer = true
        findBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        findBar.isHidden = true

        let findField = NSTextField(frame: NSRect(x: 8, y: 4, width: min(320, contentRect.width - 260), height: 22))
        findField.placeholderString = "在页面中查找"
        findField.font = .systemFont(ofSize: 12)
        findField.setAccessibilityLabel("站内查找")
        findField.delegate = self

        findStatusLabel = NSTextField(labelWithString: "")
        findStatusLabel.font = .systemFont(ofSize: 11)
        findStatusLabel.textColor = .secondaryLabelColor
        findStatusLabel.setAccessibilityLabel("查找结果")
        findStatusLabel.frame = NSRect(x: 340, y: 7, width: 90, height: 16)

        let prevFind = makeButton(title: "▲", action: #selector(findPrevious(_:)))
        prevFind.frame = NSRect(x: contentRect.width - 92, y: 3, width: 40, height: 24)
        prevFind.autoresizingMask = [.minXMargin]
        prevFind.toolTip = "上一个匹配"
        prevFind.setAccessibilityLabel("上一个匹配")

        let nextFind = makeButton(title: "▼", action: #selector(findNext(_:)))
        nextFind.frame = NSRect(x: contentRect.width - 46, y: 3, width: 40, height: 24)
        nextFind.autoresizingMask = [.minXMargin]
        nextFind.toolTip = "下一个匹配"
        nextFind.setAccessibilityLabel("下一个匹配")

        findBar.addSubview(findField)
        findBar.addSubview(findStatusLabel)
        findBar.addSubview(prevFind)
        findBar.addSubview(nextFind)

        self.findBar = findBar
        self.findField = findField

        // ---- WebView（实时渲染）：每个标签对应一个 WKWebView，由 newTab 创建接缝完成 ----
        // 底部留出状态栏（加载中/出错反馈），顶部是工具栏+标签栏。
        // 初始标签不再在此创建，改由 restoreSessionIfNeeded 决定（有则恢复、无则补默认首页）。

        // ---- 底部页面状态反馈条（加载中 / 失败原因）----
        let statusLabel = NSTextField(labelWithString: "就绪")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isEnabled = false // 仅作状态展示，不可编辑
        statusLabel.setAccessibilityLabel("页面状态")
        statusLabel.frame = NSRect(x: 8, y: 3, width: contentRect.width - 16, height: 16)
        statusLabel.autoresizingMask = [.width]
        pageStatusLabel = statusLabel

        // ---- 布局（坐标系原点在左下：状态栏贴底，webView 在其上，标签栏，工具栏固定在顶部）----
        content.addSubview(pageStatusLabel)
        content.addSubview(tabBar)
        content.addSubview(findBar)
        content.addSubview(toolbar)

        panel.contentView = content
        panel.minSize = NSSize(width: 620, height: 400)
        panel.setFrameAutosaveName("BuiltinBrowserPanel")
        // 首次打开时居中；之后恢复上次的位置与大小。
        if !panel.setFrameUsingName("BuiltinBrowserPanel") {
            panel.center()
        }

        isPanelBuilt = true
        updateTabBar()
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .texturedRounded
        b.isBordered = true
        b.font = .systemFont(ofSize: 13)
        b.setButtonType(.momentaryPushIn)
        return b
    }

    // MARK: 导航

    @objc private func goBack(_ sender: Any?) { selectedWebView?.goBack() }
    @objc private func goForward(_ sender: Any?) { selectedWebView?.goForward() }
    @objc private func reloadPage(_ sender: Any?) { selectedWebView?.reload() }
    @objc private func goHome(_ sender: Any?) {
        guard let tab = tabManager.selectedTab else { return }
        load(url: BrowserPaneController.homeURL, forTab: tab.id)
    }

    @objc private func addressSubmitted(_ sender: Any?) {
        guard let raw = addressField?.stringValue, let tab = tabManager.selectedTab else { return }
        load(urlString: raw, forTab: tab.id)
    }

    /// ⌘L：聚焦地址栏并全选。
    @objc func focusAddressBar(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        addressField?.window?.makeFirstResponder(addressField)
        addressField?.selectText(nil)
    }

    /// ⌘1-9/⌘0：按下标选择标签页。
    @objc func selectTabByIndex(_ sender: Any?) {
        guard let tag = (sender as? NSMenuItem)?.tag else { return }
        let tabs = tabManager.tabs
        let index = (tag == 0) ? max(0, tabs.count - 1) : min(tag - 1, tabs.count - 1)
        guard index >= 0, index < tabs.count else { return }
        selectTab(tabs[index].id)
    }

    /// 收藏/取消收藏当前页（书签走会话存储 UserDefaults 持久化）。
    @objc private func toggleBookmark(_ sender: Any?) {
        guard let url = selectedWebView?.url, url.scheme != nil else {
            pageStatusLabel?.stringValue = "无可收藏的页面"
            pageStatusLabel?.textColor = .systemRed
            return
        }
        let title = webViewPageTitle(url: url)
        if sessionStore.isBookmarked(url: url) {
            sessionStore.removeBookmark(url: url)
            bookmarkButton?.title = "☆"
            pageStatusLabel?.stringValue = "已取消收藏"
        } else {
            sessionStore.addBookmark(title: title, url: url)
            bookmarkButton?.title = "★"
            pageStatusLabel?.stringValue = "已收藏"
        }
        pageStatusLabel?.textColor = .secondaryLabelColor
    }

    /// 取当前标签标题的辅助（无 AppKit 依赖的默认标题回退）。
    private func webViewPageTitle(url: URL) -> String {
        guard let tab = tabManager.selectedTab, !tab.title.isEmpty else {
            return url.host ?? url.absoluteString
        }
        return tab.title
    }

    // MARK: 站内查找（⌘F / find-in-page）

    /// 唤起查找条并聚焦输入框。
    @objc func toggleFindBar(_ sender: Any?) {
        guard let findBar, isPanelBuilt else { return }
        if findBar.isHidden {
            findBar.isHidden = false
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
            findField?.window?.makeFirstResponder(findField)
        } else if !findModel.isActive {
            findBar.isHidden = true
        }
    }

    /// 查找条输入变化：交给状态机归一化，并驱动 WKWebView 找当前页。
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let raw = field.stringValue
        if field === findField {
            findModel.setQuery(raw)
            performFind(forward: true)
        } else if field === paletteField {
            commandPalette?.updateQuery(raw)
            paletteTable?.reloadData()
        }
    }

    @objc private func findNext(_ sender: Any?) { performFind(forward: true) }
    @objc private func findPrevious(_ sender: Any?) { performFind(forward: false) }

    /// 用 WKWebView 的 find(_:configuration:completionHandler:) 执行查找，并回填状态。
    /// 注意：本 macOS SDK 的 WKFindResult 只暴露 matchFound（Bool），不提供匹配计数；
    /// 模型的计数/回绕逻辑为更高版本 SDK 预留，UI 侧以「已找到/未找到」反馈。
    private func performFind(forward: Bool) {
        guard let webView = selectedWebView, findModel.isActive else {
            findStatusLabel?.stringValue = ""
            return
        }
        let query = findModel.query
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.wraps = true
        webView.find(query, configuration: config, completionHandler: { [weak self] result in
            guard let self else { return }
            if result.matchFound {
                self.findModel.match(count: 1)
                self.findModel.setCurrentIndex(0)
                self.findStatusLabel?.stringValue = "已找到"
                self.findStatusLabel?.textColor = .secondaryLabelColor
            } else {
                self.findModel.match(count: 0)
                self.findStatusLabel?.stringValue = "未找到"
                self.findStatusLabel?.textColor = .systemRed
            }
        })
    }

    private func load(urlString: String, forTab tabId: String? = nil) {
        // URL / 域名 / 搜索词统一交给解析器：非 URL 的输入转成内置搜索引擎结果页。
        guard let url = BuiltinBrowserAddress.resolve(urlString) else { return }
        load(url: url, forTab: tabId)
    }

    private func load(url: URL, forTab tabId: String? = nil) {
        let targetTabId = tabId ?? tabManager.selectedTab?.id
        guard let targetTabId else { return }
        addressField?.stringValue = url.absoluteString
        // 记录最近访问（书签/历史为后续命令栏检索准备）。
        sessionStore.recordVisit(url: url, title: url.host ?? url.absoluteString)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        webViews[targetTabId]?.load(request)
    }

    // MARK: 命令栏（⌘T / command palette）

    /// 由书签、最近访问与静态命令构建命令栏条目。
    private func buildPaletteItems() -> [PaletteItem] {
        var items: [PaletteItem] = []
        // 命令（G8 prompt 命令入口，/ 前缀进入命令模式）。
        items.append(PaletteItem(title: "新建标签页", subtitle: "命令 · 在内置浏览器打开新标签", kind: .newTab, target: ""))
        items.append(PaletteItem(title: "语音输入", subtitle: "命令 · Cmd+Shift+M", kind: .runCommand, target: "voice"))
        items.append(PaletteItem(title: "站内查找", subtitle: "命令 · Cmd+F", kind: .runCommand, target: "find"))
        items.append(PaletteItem(title: "AI 总结当前页", subtitle: "命令 · 生成总结提示词到本地 DSH", kind: .runCommand, target: "summary"))
        // 书签（本地优先）。
        for b in sessionStore.bookmarks {
            items.append(PaletteItem(title: b.title, subtitle: "书签 · \(b.url.host ?? "")", kind: .openURL, target: b.url.absoluteString))
        }
        // 最近访问。
        for v in sessionStore.recentVisits {
            items.append(PaletteItem(title: v.title, subtitle: "最近 · \(v.url.host ?? "")", kind: .openURL, target: v.url.absoluteString))
        }
        return items
    }

    /// 唤起/隐藏命令栏面板。
    @objc func toggleCommandPalette(_ sender: Any?) {
        if palettePanel != nil, !palettePanel.isVisible {
            showCommandPalette()
        } else if palettePanel != nil, palettePanel.isVisible {
            palettePanel.orderOut(nil)
        } else {
            showCommandPalette()
        }
    }

    private func showCommandPalette() {
        if palettePanel == nil { buildCommandPalettePanel() }
        // 面板聚焦由用户点击触发，不主动抢 key。
        palettePanel.orderFront(nil)
        palettePanel.makeKey()
        paletteField?.window?.makeFirstResponder(paletteField)
        refreshPaletteQuery()
    }

    private func buildCommandPalettePanel() {
        let rect = NSRect(x: 0, y: 0, width: 480, height: 360)
        palettePanel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        palettePanel.title = "命令栏（⌘T）"
        palettePanel.becomesKeyOnlyIfNeeded = true
        palettePanel.isReleasedWhenClosed = false
        palettePanel.level = .floating

        let content = NSView(frame: rect)
        paletteField = NSTextField(frame: NSRect(x: 12, y: rect.height - 36, width: rect.width - 24, height: 26))
        paletteField.placeholderString = "搜索书签 / 最近访问 / 命令（/ 开头进入命令模式）"
        paletteField.font = .systemFont(ofSize: 13)
        paletteField.setAccessibilityLabel("命令栏搜索")
        paletteField.target = self
        paletteField.action = #selector(paletteFieldAction(_:))
        paletteField.delegate = self

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: rect.width, height: rect.height - 48))
        paletteTable = NSTableView(frame: NSRect(x: 0, y: 0, width: rect.width - 2, height: scroll.bounds.height))
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.width = rect.width - 20
        paletteTable.addTableColumn(column)
        paletteTable.dataSource = self
        paletteTable.delegate = self
        paletteTable.headerView = nil
        scroll.documentView = paletteTable
        scroll.hasVerticalScroller = true

        content.addSubview(paletteField)
        content.addSubview(scroll)
        palettePanel.contentView = content
        palettePanel.center()
    }

    private func refreshPaletteQuery() {
        let raw = paletteField?.stringValue ?? ""
        if commandPalette == nil { commandPalette = CommandPalette(items: buildPaletteItems()) }
        commandPalette?.updateQuery(raw)
        paletteTable?.reloadData()
    }

    /// 执行命令栏当前选中项。
    private func runCommandPaletteSelection() {
        guard let item = commandPalette?.selectedItem else { return }
        palettePanel?.orderOut(nil)
        switch item.kind {
        case .openURL:
            if let url = URL(string: item.target) {
                load(url: url)
            }
        case .newTab:
            newTab(nil)
        case .runCommand:
            switch item.target {
            case "voice":
                // 经响应链路由到 Application Delegate 的语音输入动作（菜单已挂接）。
                _ = NSApp.sendAction(#selector(AppDelegate.toggleVoiceInput(_:)), to: nil, from: nil)
            case "find":
                toggleFindBar(nil)
            case "summary":
                summarizeCurrentPage(nil)
            default:
                break
            }
        }
    }

    // MARK: 命令栏表格数据源 / 委托

    @objc private func paletteFieldAction(_ sender: Any?) {
        runCommandPaletteSelection()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        commandPalette?.filtered.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let items = commandPalette?.filtered, row < items.count else { return nil }
        let item = items[row]
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let title = NSTextField(labelWithString: "")
            title.identifier = NSUserInterfaceItemIdentifier("title")
            title.lineBreakMode = .byTruncatingTail
            let sub = NSTextField(labelWithString: "")
            sub.identifier = NSUserInterfaceItemIdentifier("sub")
            sub.font = .systemFont(ofSize: 10)
            sub.textColor = .secondaryLabelColor
            title.translatesAutoresizingMaskIntoConstraints = false
            sub.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(title)
            cell.addSubview(sub)
            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                title.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
                sub.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
                sub.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8)
            ])
            cell.textField = title
        }
        cell.textField?.stringValue = item.title
        if let sub = cell.subviews.first(where: { ($0 as? NSTextField)?.identifier?.rawValue == "sub" }) as? NSTextField {
            sub.stringValue = item.subtitle
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        commandPalette?.moveSelection(down: paletteTable.selectedRow > (commandPalette?.selectedIndex ?? 0))
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        commandPalette?.filtered.isEmpty == false
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        nil
    }

    // MARK: AI 总结当前页 → 本地 DSH（G3）

    /// 唤起 AI 总结：取当前页正文 → PageSummaryModel 生成提示词 → 复制到剪贴板并聚焦本地 DSH。
    @objc func summarizeCurrentPage(_ sender: Any?) {
        guard let webView = selectedWebView else { return }
        // 隐私：先让用户确认把「含页面正文的提示词」写入系统剪贴板，避免静默清空用户剪贴板。
        let confirm = NSAlert()
        confirm.messageText = "把 AI 总结提示词复制到剪贴板？"
        confirm.informativeText = "提示词会包含页面标题与正文片段（最多 1500 字符），将覆盖系统剪贴板后聚焦本地 DSH。"
        confirm.addButton(withTitle: "复制并去 DSH")
        confirm.addButton(withTitle: "取消")
        guard alertOK(confirm) else { return }

        // 用 JS 抓取正文纯文本（控制篇幅，减少敏感信息外泄）。
        let js = "var e=document.body?document.body.innerText:''; e.substring(0, 1500);"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            let snippet = (result as? String) ?? ""
            let url = webView.url
            if !PageSummaryModel.evaluate(title: webView.title, currentURL: url, pageSnippet: snippet, language: "zh-Hans").canSummarize {
                self.pageStatusLabel?.stringValue = "当前页无网址，无法总结"
                self.pageStatusLabel?.textColor = .systemRed
                return
            }
            let clip = PageSummaryModel.clipboardString(title: webView.title, currentURL: url, pageSnippet: snippet, language: "zh-Hans")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(clip, forType: .string)
            self.pageStatusLabel?.stringValue = "总结提示词已复制（⌘V 粘贴到本地 DSH）"
            self.pageStatusLabel?.textColor = .secondaryLabelColor
            // 打开本地 DSH 让用户执行总结。
            NSApp.sendAction(#selector(AppDelegate.bringDSHFront(_:)), to: nil, from: nil)
        }
    }

    /// 便捷：运行模态确认框，判断用户是否点了第一个按钮。
    private func alertOK(_ alert: NSAlert) -> Bool {
        alert.runModal() == .alertFirstButtonReturn
    }

    /// 保存当前页（G10）：按 PageCaptureModel 生成文件名，快照 PNG 存到下载目录。
    @objc func saveCurrentPage(_ sender: Any?) {
        guard let webView = selectedWebView else { return }
        let title = webView.title ?? ""
        let url = webView.url ?? URL(string: "about:blank")!
        let format = PageCaptureModel.Format.png
        let fileName = PageCaptureModel.uniqueFileName(title: title, url: url, format: format)
        let target = PageCaptureModel.defaultDirectory().appendingPathComponent(fileName)

        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, error in
            guard let image else {
                self.pageStatusLabel?.stringValue = "截图失败：\(error?.localizedDescription ?? "未知错误")"
                self.pageStatusLabel?.textColor = .systemRed
                return
            }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                self.pageStatusLabel?.stringValue = "截图编码失败"
                self.pageStatusLabel?.textColor = .systemRed
                return
            }
            do {
                try png.write(to: target)
                self.pageStatusLabel?.stringValue = "已保存：\(fileName)"
                self.pageStatusLabel?.textColor = .secondaryLabelColor
            } catch {
                self.pageStatusLabel?.stringValue = "保存失败：\(error.localizedDescription)"
                self.pageStatusLabel?.textColor = .systemRed
            }
        }
    }

    /// G12：弹出「添加用户脚本」窗口，收集名称/URL 通配/JS 源码后写入 UserScriptStore。
    @objc func addUserScript(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "添加用户脚本"
        alert.informativeText = "填写脚本名称、匹配的 URL 通配（如 *://*.example.com/*）和 JavaScript 源码。"
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        nameField.placeholderString = "脚本名称（如 暗色主题）"
        let patternField = NSTextField(frame: NSRect(x: 0, y: -28, width: 360, height: 24))
        patternField.placeholderString = "URL 匹配（默认 * 全部页面）"
        patternField.stringValue = "*"
        let sourceField = NSTextField(frame: NSRect(x: 0, y: -58, width: 360, height: 52))
        sourceField.placeholderString = "JavaScript 源码（如 document.body.style.background='#000'）"
        sourceField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)

        let accessory = NSView(frame: NSRect(x: 0, y: -78, width: 360, height: 110))
        accessory.addSubview(nameField)
        accessory.addSubview(patternField)
        accessory.addSubview(sourceField)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = nameField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = patternField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceField.stringValue
        guard !name.isEmpty && !source.isEmpty else {
            self.pageStatusLabel?.stringValue = "用户脚本未添加：名称/源码不能为空"
            self.pageStatusLabel?.textColor = .systemRed
            return
        }
        let id = "script-\(UUID().uuidString.prefix(8))"
        userScripts.upsert(id: id, name: name, source: source, urlPattern: pattern.isEmpty ? "*" : pattern, isActive: true)
        pageStatusLabel?.stringValue = "已添加用户脚本：\(name)"
        pageStatusLabel?.textColor = .secondaryLabelColor
    }

    /// 切换面板内鼠标手势（G14，仅面板范围，不注册全局钩子）。
    @objc func toggleMouseGestures(_ sender: Any?) {
        // 关闭已有监听（幂等重开不累积）。
        if let monitor = gestureMonitor {
            NSEvent.removeMonitor(monitor)
            gestureMonitor = nil
        }
        gestureOrigin = nil

        mouseGesturesEnabled.toggle()
        if mouseGesturesEnabled {
            installGestureMonitor()
        }
        (sender as? NSMenuItem)?.state = mouseGesturesEnabled ? .on : .off
        pageStatusLabel?.stringValue = mouseGesturesEnabled ? "鼠标手势已开启（面板内）" : "鼠标手势已关闭"
    }

    /// 安装面板本地鼠标事件监听：仅在面板为事件来源时处理拖拽手势，其余事件原样放行，
    /// 不抢主窗口/其他应用前台。
    private func installGestureMonitor() {
        gestureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel else {
                return event // 非面板事件：放行，绝不影响主窗口。
            }
            switch event.type {
            case .leftMouseDown:
                self.gestureOrigin = event.locationInWindow
            case .leftMouseDragged:
                break
            case .leftMouseUp:
                if let origin = self.gestureOrigin {
                    let location = event.locationInWindow
                    let dx = location.x - origin.x
                    let dy = location.y - origin.y
                    self.gestureOrigin = nil
                    self.dispatchGesture(dx: dx, dy: dy)
                }
            default:
                break
            }
            return event
        }
    }

    /// 用 MouseGestureModel 把面板内拖拽量化为方向并执行对应命令。
    private func dispatchGesture(dx: CGFloat, dy: CGFloat) {
        guard let direction = MouseGestureModel.direction(dx: dx, dy: dy),
              let gesture = MouseGestureModel.gesture(direction) else {
            self.pageStatusLabel?.stringValue = "面板手势：点击（无手势）"
            return
        }
        self.pageStatusLabel?.stringValue = "面板手势：\(gesture.description)"
        switch gesture.command {
        case .forward:
            goForward(nil)
        case .back:
            goBack(nil)
        case .refresh:
            reloadPage(nil)
        }
    }

    // MARK: 标签管理

    /// 新建标签页（加载主页）。
    @objc func newTab(_ sender: Any?) {
        let tab = tabManager.addTab(url: BrowserPaneController.homeURL)
        let webView = createWebView()
        webViews[tab.id] = webView
        // 将新 webView 加入内容视图（放在标签栏下方、状态栏上方）。
        if let content = panel?.contentView {
            let tabBarHeight: CGFloat = 28
            let toolbarHeight: CGFloat = 44
            let statusBarHeight: CGFloat = 22
            let webRect = NSRect(
                x: 0, y: statusBarHeight,
                width: content.bounds.width,
                height: content.bounds.height - toolbarHeight - tabBarHeight - statusBarHeight
            )
            webView.frame = webRect
            webView.autoresizingMask = [.width, .height]
            // 插入到标签栏和工具栏之间（索引 1 = 标签栏上方，索引 2 = 工具栏下方）。
            content.addSubview(webView, positioned: .below, relativeTo: content.subviews.first { $0 !== webView && $0 !== tabScrollView?.superview } ?? content.subviews[0])
        }
        webView.isHidden = true
        selectTab(tab.id)
        load(url: BrowserPaneController.homeURL, forTab: tab.id)
    }

    /// 关闭指定标签页。
    @objc func closeTab(_ sender: Any?) {
        guard let tab = tabManager.selectedTab else { return }
        closeTab(id: tab.id)
    }

    private func closeTab(id: String) {
        guard tabManager.tabCount > 0 else { return }
        // 移除 webView。
        webViews[id]?.removeFromSuperview()
        webViews[id] = nil
        tabManager.removeTab(id: id)
        updateTabBar()
        // 更新地址栏和状态。
        if let selectedTab = tabManager.selectedTab {
            addressField?.stringValue = selectedTab.url.absoluteString
            updateNavigationButtons()
        } else {
            addressField?.stringValue = ""
            pageStatusLabel?.stringValue = "无标签页"
        }
    }

    /// 选中指定标签页。
    private func selectTab(_ id: String) {
        guard tabManager.selectTab(id: id) else { return }
        // 隐藏所有 webView，显示选中的。
        for (tabId, webView) in webViews {
            webView.isHidden = (tabId != id)
        }
        // 更新地址栏。
        if let tab = tabManager.selectedTab {
            addressField?.stringValue = tab.url.absoluteString
            if let webView = webViews[tab.id] {
                pageStatusLabel?.stringValue = webView.isLoading ? "加载中…" : "就绪"
            }
        }
        updateTabBar()
        updateNavigationButtons()
    }

    /// 保存当前会话（标签集 + 选中索引 + 主 webView 滚动位置）到本地。
    func saveSession() {
        let restorable = tabManager.tabs.map { RestorableTab(url: $0.url, title: $0.title) }
        let selectedIndex = max(0, tabManager.selectedIndex)
        // 同步落盘，确保 applicationWillTerminate 时一定能保存（不依赖异步 JS 回调，
        // 否则进程退出时可能不执行导致会话丢失）。滚动位置为次要信息，此处记为 0。
        sessionRestore.save(tabs: restorable, selectedIndex: selectedIndex, scrollY: 0)
    }

    /// 首次打开面板时恢复上次会话（若没有历史则自动打开默认页）。
    func restoreSessionIfNeeded() {
        // 无会话：若还没有任何标签则补建一个默认首页标签（不移除、不追加多余标签）。
        guard sessionRestored == false, let snapshot = sessionRestore.restore(), !snapshot.tabs.isEmpty else {
            sessionRestored = true
            if tabManager.tabCount == 0 {
                newTab(nil)
            }
            return
        }
        sessionRestored = true
        let content = panel?.contentView
        for tab in snapshot.tabs {
            let created = tabManager.addTab(url: tab.url)
            // 与 newTab 一致：为恢复的标签创建并布局 WKWebView，否则无法交互。
            let webView = createWebView()
            webViews[created.id] = webView
            webView.frame = webAreaRect(container: content ?? NSView(frame: .zero))
            webView.autoresizingMask = [.width, .height]
            webView.isHidden = true
            if let content {
                content.addSubview(webView, positioned: .below,
                                    relativeTo: content.subviews.first { $0 !== webView && $0 !== tabScrollView?.superview } ?? content.subviews[0])
            }
            // 恢复会话与浏览器一致：为每个恢复的标签实际加载其 URL，点击即有内容。
            load(url: tab.url, forTab: created.id)
        }
        // 恢复选中索引并加载对应页面。
        let target = min(max(0, snapshot.selectedIndex), max(0, tabManager.tabCount - 1))
        if target < tabManager.tabs.count {
            selectTab(tabManager.tabs[target].id)
        }
    }

    /// 切换到下一个标签页。
    @objc func nextTabAction(_ sender: Any?) {
        guard tabManager.nextTab() else { return }
        if let tab = tabManager.selectedTab {
            selectTab(tab.id)
        }
    }

    /// 切换到上一个标签页。
    @objc func previousTabAction(_ sender: Any?) {
        guard tabManager.previousTab() else { return }
        if let tab = tabManager.selectedTab {
            selectTab(tab.id)
        }
    }

    /// 创建新的 WKWebView 实例。
    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        return webView
    }

    /// 更新标签栏 UI。
    private func updateTabBar() {
        guard let containerView = tabContainerView else { return }
        // 清除旧标签按钮。
        containerView.subviews.forEach { $0.removeFromSuperview() }

        let buttonWidth: CGFloat = 160
        let buttonHeight: CGFloat = 22
        let spacing: CGFloat = 2

        // G11：开启「按站点分组」时，按组渲染：每个展开组前有可点击组头折叠按钮。
        var buttons: [(tab: BrowserTab?, label: String, isGroupHeader: Bool, groupName: String?)] = []
        if tabGroupingEnabled {
            verticalTabs.group(tabs: tabManager.tabs.map { VTab(title: $0.title, id: $0.id) })
            for group in verticalTabs.groups {
                // 组头折叠按钮：点击 toggle 该组（identifier 直接携带组名，不依赖显示文本解析）。
                buttons.append((nil, "▾ \(group.name)", true, group.name))
                guard !verticalTabs.isCollapsed(group: group.name) else { continue }
                for vtab in group.tabs {
                    guard let tab = tabManager.tabs.first(where: { $0.id == vtab.id }) else { continue }
                    let title = tab.title.isEmpty ? tab.url.host ?? tab.url.absoluteString : tab.title
                    buttons.append((tab, title, false, nil))
                }
            }
        } else {
            buttons = tabManager.tabs.map { ($0, $0.title.isEmpty ? $0.url.host ?? $0.url.absoluteString : $0.title, false, nil) }
        }

        for (index, entry) in buttons.enumerated() {
            let x = CGFloat(index) * (buttonWidth + spacing) + 4
            if entry.isGroupHeader {
                let button = NSButton(title: entry.label, target: self, action: #selector(toggleGroupFold(_:)))
                button.frame = NSRect(x: x, y: 3, width: 120, height: buttonHeight)
                button.bezelStyle = .disclosure
                button.font = .boldSystemFont(ofSize: 11)
                // identifier 直接携带组名，toggle 时无需解析显示文本。
                button.identifier = NSUserInterfaceItemIdentifier("group:\(entry.groupName ?? "")")
                containerView.addSubview(button)
                continue
            }
            guard let tab = entry.tab else { continue }
            let button = NSButton(title: entry.label, target: self, action: #selector(tabButtonClicked(_:)))
            button.frame = NSRect(x: x, y: 3, width: buttonWidth, height: buttonHeight)
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 11)
            button.tag = index
            button.identifier = NSUserInterfaceItemIdentifier(tab.id)

            // 选中状态高亮。
            if tab.id == tabManager.selectedTab?.id {
                button.state = .on
                button.bezelStyle = .texturedRounded
            }

            containerView.addSubview(button)
        }

        // 调整容器宽度以容纳所有标签。
        let totalWidth = CGFloat(max(buttons.count, tabManager.tabCount)) * (buttonWidth + spacing) + 4
        containerView.frame.size.width = max(totalWidth, tabScrollView?.bounds.width ?? 0)
    }

    @objc private func tabButtonClicked(_ sender: NSButton) {
        guard let tabId = sender.identifier?.rawValue else { return }
        selectTab(tabId)
    }

    /// G11：点击组头折叠/展开某分组。
    @objc private func toggleGroupFold(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, raw.hasPrefix("group:"),
              let range = raw.range(of: "group:") else { return }
        let name = String(raw[range.upperBound...])
        verticalTabs.toggleCollapse(name)
        updateTabBar()
    }

    /// 切换「按站点分组标签」（G4）：用 TabGroupingModel 按 host 聚合，标签附组名前缀。
    @objc func toggleTabGrouping(_ sender: Any?) {
        tabGroupingEnabled.toggle()
        updateTabBar()
        (sender as? NSMenuItem)?.state = tabGroupingEnabled ? .on : .off
    }

    /// 切换「分屏视图」（G6）：把当前页复制到右侧副屏，再次点击关闭。
    @objc func toggleSplitView(_ sender: Any?) {
        guard let content = panel?.contentView else { return }
        if splitState.isActive {
            splitState.close()
            splitWebView?.removeFromSuperview()
            splitWebView = nil
            // 收起分屏后，主 webView 恢复整宽。
            webViews.values.forEach { $0.frame = webAreaRect(container: content) }
        } else {
            let url = selectedWebView?.url ?? BrowserPaneController.homeURL
            splitState.open(url: url)
            let secondary = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
            secondary.navigationDelegate = self
            secondary.autoresizingMask = []
            // 与主 webView 同层级插入（chrome 元素之下），不遮挡工具栏/标签栏/状态栏。
            content.addSubview(secondary, positioned: .below,
                                relativeTo: content.subviews.first { $0 !== secondary && $0 !== tabScrollView?.superview } ?? content.subviews[0])
            splitWebView = secondary
            layoutSplitPane(content: content)
            secondary.load(URLRequest(url: url))
            (sender as? NSMenuItem)?.state = .on
            return
        }
        (sender as? NSMenuItem)?.state = splitState.isActive ? .on : .off
    }

    /// 计算 web 内容区矩形（标签栏下方、状态栏上方）。
    private func webAreaRect(container: NSView) -> NSRect {
        let tabBarHeight: CGFloat = 28
        let toolbarHeight: CGFloat = 44
        let statusBarHeight: CGFloat = 22
        return NSRect(
            x: 0, y: statusBarHeight,
            width: container.bounds.width,
            height: container.bounds.height - toolbarHeight - tabBarHeight - statusBarHeight
        )
    }

    /// 布局分屏：副屏占右侧一半，主屏收窄到左侧一半（均限 web 内容区）。
    private func layoutSplitPane(content: NSView) {
        guard let splitWebView else { return }
        let webRect = webAreaRect(container: content)
        let mid = webRect.width / 2
        splitWebView.frame = NSRect(x: webRect.origin.x + mid, y: webRect.origin.y,
                                    width: webRect.width - mid, height: webRect.height)
        // 收窄主 webView 到左半。
        webViews.values.forEach { $0.frame = NSRect(x: webRect.origin.x, y: webRect.origin.y,
                                                    width: mid, height: webRect.height) }
    }

    /// 计算某标签所属组名（host 的注册域名 fallback 顶栏域名）。
    private func groupName(for tab: BrowserTab) -> String {
        let model = TabGroupingModel(groupingKey: { (groupable: TabGroupable) -> String in
            let url = self.tabManager.tabs.first { $0.id == groupable.id }?.url
            return url?.host ?? "其他"
        })
        let groups = model.group(tabManager.tabs.map { TabGroupable(title: $0.title, id: $0.id) })
        for g in groups where g.tabs.contains(where: { $0.id == tab.id }) {
            return g.name
        }
        return tab.url.host ?? "其他"
    }

    /// 更新导航按钮状态（后退/前进）。
    private func updateNavigationButtons() {
        backButton?.isEnabled = selectedWebView?.canGoBack ?? false
        forwardButton?.isEnabled = selectedWebView?.canGoForward ?? false
    }

    /// 注入语音控制器并接好 UI 状态反馈（面板与菜单共享同一实例）。
    func attach(voiceController: VoiceController) {
        self.voiceController = voiceController
        voiceController.onStateChange = { [weak self] state in
            self?.updateVoiceUI(state: state)
        }
        // 初始化当前权限状态。
        updateVoiceUI(state: VoiceInputModel.initialState(permission: VoiceController.authorizationStatus))
    }

    // MARK: 语音输入（界面入口）

    @objc private func toggleVoice(_ sender: Any?) {
        guard let voiceController else { return }
        if voiceController.isRecording {
            voiceController.stopRecording()
        } else {
            voiceController.setLocale("zh-CN")
            voiceController.startRecording()
        }
    }

    private func updateVoiceUI(state: VoiceInputModel.State) {
        guard let micButton else { return }
        switch state {
        case .idle:
            micButton.title = "🎤"
            micButton.toolTip = "语音输入"
            micButton.setAccessibilityValue("空闲")
        case .listening:
            micButton.title = "⏺"
            micButton.toolTip = "正在聆听…（再次点击停止）"
            micButton.setAccessibilityValue("正在聆听")
        case .processing:
            micButton.title = "✎"
            micButton.toolTip = "转写完成，正在输入…"
            micButton.setAccessibilityValue("正在输入")
        case .unavailable(let reason):
            micButton.title = "🎤"
            micButton.toolTip = reason
            micButton.setAccessibilityValue("不可用：\(reason)")
        }
    }

    // MARK: WKNavigationDelegate（实时更新地址栏 + 页面状态反馈；全程不激活应用）

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        pageStatusLabel?.stringValue = "加载中…"
        pageStatusLabel?.textColor = .secondaryLabelColor
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        addressField?.stringValue = webView.url?.absoluteString ?? ""
        backButton?.isEnabled = webView.canGoBack
        forwardButton?.isEnabled = webView.canGoForward
        pageStatusLabel?.stringValue = "就绪"
        pageStatusLabel?.textColor = .secondaryLabelColor
        // G12：用户脚本——把匹配当前 URL 的已启用脚本注入页面（按 webView+URL+脚本去重，
        // 避免 reload 重复执行非幂等脚本）。
        if let url = webView.url {
            let webKey = "\(ObjectIdentifier(webView).hashValue)|\(url.absoluteString)|"
            for script in userScripts.activeScripts(for: url) {
                let key = webKey + script.id
                guard !appliedScripts.contains(key) else { continue }
                appliedScripts.insert(key)
                webView.evaluateJavaScript(script.source, completionHandler: nil)
            }
        }
        // 用真实页面标题更新标签栏，并同步书签按钮状态。
        if let url = webView.url {
            if let tab = tabManager.selectedTab, webViews[tab.id] === webView, !(webView.title ?? "").isEmpty {
                _ = tabManager.updateTab(id: tab.id, title: webView.title ?? "", url: url)
                sessionStore.recordVisit(url: url, title: webView.title ?? url.host ?? url.absoluteString)
                updateTabBar()
            }
            bookmarkButton?.title = sessionStore.isBookmarked(url: url) ? "★" : "☆"
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        addressField?.stringValue = webView.url?.absoluteString ?? ""
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    /// 把导航错误显示在页面状态条（UI 状态反馈），不弹窗打断浏览。
    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        // 用户中断（如主动刷新/输入新地址）不算失败。
        if nsError.code == NSURLErrorCancelled { return }
        let reason: String
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet: reason = "无网络连接"
        case NSURLErrorCannotFindHost: reason = "找不到主机"
        case NSURLErrorTimedOut: reason = "连接超时"
        case NSURLErrorSecureConnectionFailed: reason = "安全连接失败"
        default: reason = "加载失败"
        }
        pageStatusLabel?.stringValue = reason
        pageStatusLabel?.textColor = .systemRed
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.cancel)
            return
        }
        // 仅允许 http/https/data/view-source 在面板内加载；其余交给系统处理。
        if scheme == "http" || scheme == "https" || scheme == "data" || scheme == "about" {
            decisionHandler(.allow)
        } else if scheme == "view-source" {
            decisionHandler(.allow)
        } else {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    // 新窗口请求一律在面板内打开，避免弹出额外窗口抢前台。
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            load(url: url)
        }
        return nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var loadingView: NSVisualEffectView!
    private var statusLabel: NSTextField!
    private var spinner: NSProgressIndicator!
    private var retryTimer: Timer?
    private var retryCount = 0
    private var serviceStartRequested = false

    /// 内置浏览器面板（实时渲染，不抢前台）
    private let browserPane = BrowserPaneController()

    /// 语音输入控制器（面板与菜单共享同一实例，状态反馈一致）。
    private let voiceController = VoiceController()
    private weak var voiceMenuItem: NSMenuItem?

    private var serviceLabel: String {
        "gui/\(getuid())/\(serviceName)"
    }

    private var launchAgentPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(serviceName).plist").path
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenus()
        createWindow()
        // 面板与菜单共享同一个语音控制器；面板的麦克风按钮在此接线。
        browserPane.attach(voiceController: voiceController)
        voiceController.onStateChange = { [weak self] state in
            self?.updateVoiceMenuItem(state: state)
        }
        ensureHarnessIsRunning()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        ensureHarnessIsRunning()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        retryTimer?.invalidate()
        browserPane.saveSession()
        runLaunchctl(["kill", "SIGTERM", serviceLabel])
    }

    @objc private func reloadHarness(_ sender: Any?) {
        showLoading(message: "正在重新载入 DeepSeek Harness Terminator...")
        ensureHarnessIsRunning(forceReload: true)
    }

    /// 打开/收起内置浏览器。仅切换面板可见性，不激活应用、不抢占前台。
    @objc private func toggleBuiltinBrowser(_ sender: Any?) {
        browserPane.toggleBrowser()
    }

    /// 聚焦主窗口内的本地 DSH，供 AI 总结等动作把用户带回聊天界面。
    @objc func bringDSHFront(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: 语音输入（菜单入口，Cmd+Shift+M）

    @objc func toggleVoiceInput(_ sender: Any?) {
        if voiceController.isRecording {
            voiceController.stopRecording()
        } else {
            voiceController.setLocale("zh-CN")
            voiceController.startRecording()
        }
    }

    /// 同步语音状态到菜单项（标题/可用性/说明）。
    private func updateVoiceMenuItem(state: VoiceInputModel.State) {
        guard let item = voiceMenuItem else { return }
        switch state {
        case .idle:
            item.title = "语音输入"
            item.isEnabled = true
            item.toolTip = "向当前输入框语音输入（Cmd+Shift+M）"
        case .listening:
            item.title = "停止语音输入"
            item.isEnabled = true
            item.toolTip = "正在聆听…点击停止并提交"
        case .processing:
            item.title = "正在输入…"
            item.isEnabled = false
            item.toolTip = "转写完成，正在写入输入框"
        case .unavailable(let reason):
            item.title = "语音输入不可用"
            item.isEnabled = false
            item.toolTip = reason
        }
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "DeepSeek Harness Terminator",
            .applicationVersion: "0.1.1",
            .credits: NSAttributedString(string: "DeepSeek Harness Terminator：DeepSeek Harness 的非官方本地 macOS 客户端")
        ])
    }

    private func configureMenus() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 DeepSeek Harness Terminator", action: #selector(showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 DeepSeek Harness Terminator", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.option, .command]
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let voiceItem = appMenu.addItem(withTitle: "语音输入", action: #selector(toggleVoiceInput(_:)), keyEquivalent: "m")
        voiceItem.keyEquivalentModifierMask = [.shift, .command]
        voiceItem.target = self
        voiceItem.toolTip = "向当前输入框语音输入（Cmd+Shift+M）"
        voiceMenuItem = voiceItem
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 DeepSeek Harness Terminator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "显示")
        let reloadItem = viewMenu.addItem(withTitle: "重新载入", action: #selector(reloadHarness(_:)), keyEquivalent: "r")
        reloadItem.target = self
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "进入全屏幕", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.control, .command]
        viewMenu.addItem(NSMenuItem.separator())
        let browserItem = viewMenu.addItem(withTitle: "内置浏览器", action: #selector(toggleBuiltinBrowser(_:)), keyEquivalent: "b")
        browserItem.target = self
        let findItem = viewMenu.addItem(withTitle: "在页面中查找", action: #selector(BrowserPaneController.toggleFindBar(_:)), keyEquivalent: "f")
        findItem.target = browserPane
        findItem.toolTip = "在内置浏览器当前页中查找（Cmd+F）"
        let paletteItem2 = viewMenu.addItem(withTitle: "命令栏", action: #selector(BrowserPaneController.toggleCommandPalette(_:)), keyEquivalent: "t")
        paletteItem2.target = browserPane
        paletteItem2.toolTip = "搜索书签 / 最近访问 / 命令（Cmd+T）"
        let summaryItem = viewMenu.addItem(withTitle: "AI 总结当前页", action: #selector(BrowserPaneController.summarizeCurrentPage(_:)), keyEquivalent: "y")
        summaryItem.keyEquivalentModifierMask = [.shift, .command]
        summaryItem.target = browserPane
        summaryItem.toolTip = "把当前页标题+URL+正文整理成总结提示词，复制到本地 DSH（Cmd+Shift+Y）"
        viewMenu.addItem(NSMenuItem.separator())

        // 标准浏览器快捷键集（⌘L / ⌘N / ⌘W / ⌘1-9 / ⌃⌘Tab），数据来自 BrowserShortcuts 路线图。
        let locItem = viewMenu.addItem(withTitle: "聚焦地址栏", action: #selector(BrowserPaneController.focusAddressBar(_:)), keyEquivalent: "l")
        locItem.target = browserPane
        let newTabItem = viewMenu.addItem(withTitle: "新建标签页", action: #selector(BrowserPaneController.newTab(_:)), keyEquivalent: "n")
        newTabItem.target = browserPane
        let closeTabItem = viewMenu.addItem(withTitle: "关闭当前标签页", action: #selector(BrowserPaneController.closeTab(_:)), keyEquivalent: "w")
        closeTabItem.target = browserPane
        let nextTabItem = viewMenu.addItem(withTitle: "下一个标签页", action: #selector(BrowserPaneController.nextTabAction(_:)), keyEquivalent: "\t")
        let mods: NSEvent.ModifierFlags = [.control, .command]
        nextTabItem.keyEquivalentModifierMask = mods
        nextTabItem.target = browserPane
        viewMenu.addItem(NSMenuItem.separator())
        // ⌘1-9 / ⌘0：选择标签页。
        for (index, key) in ["1", "2", "3", "4", "5", "6", "7", "8", "9"].enumerated() {
            let item = viewMenu.addItem(withTitle: "选择标签页 \(index + 1)", action: #selector(BrowserPaneController.selectTabByIndex(_:)), keyEquivalent: key)
            item.tag = index + 1
            item.target = browserPane
        }
        let lastTabItem = viewMenu.addItem(withTitle: "选择最后一个标签页", action: #selector(BrowserPaneController.selectTabByIndex(_:)), keyEquivalent: "0")
        lastTabItem.tag = 0
        lastTabItem.target = browserPane
        viewMenu.addItem(NSMenuItem.separator())
        let groupItem = viewMenu.addItem(withTitle: "按站点分组标签", action: #selector(BrowserPaneController.toggleTabGrouping(_:)), keyEquivalent: "g")
        groupItem.keyEquivalentModifierMask = [.shift, .command]
        groupItem.target = browserPane
        groupItem.state = .off
        let splitItem = viewMenu.addItem(withTitle: "分屏视图", action: #selector(BrowserPaneController.toggleSplitView(_:)), keyEquivalent: "s")
        splitItem.keyEquivalentModifierMask = [.shift, .command]
        splitItem.target = browserPane
        splitItem.state = .off
        let captureItem = viewMenu.addItem(withTitle: "保存当前页截图", action: #selector(BrowserPaneController.saveCurrentPage(_:)), keyEquivalent: "")
        captureItem.target = browserPane
        let addScriptItem = viewMenu.addItem(withTitle: "添加用户脚本…", action: #selector(BrowserPaneController.addUserScript(_:)), keyEquivalent: "")
        addScriptItem.target = browserPane
        let gestureItem = viewMenu.addItem(withTitle: "鼠标手势（面板内）", action: #selector(BrowserPaneController.toggleMouseGestures(_:)), keyEquivalent: "")
        gestureItem.target = browserPane
        gestureItem.state = .off

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func createWindow() {
        let frame = NSRect(x: 0, y: 0, width: 1280, height: 820)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Harness Terminator"
        window.minSize = NSSize(width: 900, height: 620)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        webView.autoresizingMask = [.width, .height]

        let container = NSView(frame: frame)
        container.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        loadingView = NSVisualEffectView(frame: frame)
        loadingView.material = .sidebar
        loadingView.blendingMode = .withinWindow
        loadingView.state = .active
        loadingView.autoresizingMask = [.width, .height]

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .large
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = NSTextField(labelWithString: "正在启动 DeepSeek Harness Terminator...")
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingView.addSubview(spinner)
        loadingView.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -18),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: loadingView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingView.trailingAnchor, constant: -24)
        ])
        container.addSubview(loadingView)

        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func ensureHarnessIsRunning(forceReload: Bool = false) {
        if !serviceStartRequested {
            serviceStartRequested = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.startLaunchAgent()
            }
        }
        // WKWebView is the actual application surface, so it is the most
        // reliable readiness probe. A separate URLSession preflight has
        // previously stalled even while WebKit could reach the local server.
        loadHarness(forceReload: forceReload)
    }

    private func beginReadinessPolling(forceReload: Bool) {
        retryTimer?.invalidate()
        retryCount = 0
        retryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.retryCount += 1
            self.checkServer { [weak self] ready in
                guard let self else { return }
                if ready {
                    timer.invalidate()
                    self.serviceStartRequested = false
                    self.loadHarness(forceReload: forceReload)
                } else if self.profileIntegrityFailureDetected() {
                    timer.invalidate()
                    self.serviceStartRequested = false
                    self.showProfileIntegrityFailure()
                } else if self.retryCount >= 120 {
                    timer.invalidate()
                    self.serviceStartRequested = false
                    self.showStartupFailure()
                }
            }
        }
    }

    private func startLaunchAgent() {
        if runLaunchctl(["kickstart", serviceLabel]) == 0 {
            return
        }
        _ = runLaunchctl(["bootstrap", "gui/\(getuid())", launchAgentPath])
        _ = runLaunchctl(["kickstart", serviceLabel])
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private func checkServer(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: harnessURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2
        // URLSession can fail to deliver its completion callback while the
        // local service is starting (for example during a stale connection
        // handoff). Keep the AppKit window progressing instead of leaving the
        // loading overlay up forever.
        var completed = false
        let finish: (Bool) -> Void = { ready in
            DispatchQueue.main.async {
                guard !completed else { return }
                completed = true
                completion(ready)
            }
        }
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let hasHarnessShell = body.contains("__DSH_BOOT__") && body.contains("<div id=\"root\"></div>")
            let hasKnownTitle = body.contains("<title>DeepSeek Harness</title>") || body.contains("<title>DSH Local Build</title>")
            let ready = status == 200 && (hasKnownTitle || hasHarnessShell)
            finish(ready)
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            finish(false)
        }
    }

    private func loadHarness(forceReload: Bool) {
        showLoading(message: "正在载入界面...")
        if forceReload, webView.url != nil {
            webView.reloadFromOrigin()
        } else if webView.url == nil {
            webView.load(URLRequest(url: harnessURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        } else {
            hideLoading()
        }
    }

    private func showLoading(message: String) {
        statusLabel?.stringValue = message
        spinner?.startAnimation(nil)
        loadingView?.isHidden = false
        loadingView?.superview?.addSubview(loadingView, positioned: .above, relativeTo: webView)
    }

    private func hideLoading() {
        spinner?.stopAnimation(nil)
        loadingView?.isHidden = true
    }

    private func showStartupFailure() {
        statusLabel.stringValue = "本地服务启动失败"
        spinner.stopAnimation(nil)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "DeepSeek Harness Terminator 无法启动"
        alert.informativeText = "请查看 ~/Library/Logs/DeepSeekHarness.log 了解详细信息。"
        alert.addButton(withTitle: "打开日志")
        alert.addButton(withTitle: "重试")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/DeepSeekHarness.log"))
        } else {
            ensureHarnessIsRunning(forceReload: true)
        }
    }

    private func profileIntegrityFailureDetected() -> Bool {
        FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DeepSeekHarness.profile-error").path)
    }

    private func showProfileIntegrityFailure() {
        statusLabel.stringValue = "检测到插件依赖冲突"
        spinner.stopAnimation(nil)

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "DeepSeek Harness Terminator 已阻止不兼容的 profile 启动"
        alert.informativeText = "某个插件安装了 DSH 核心包的第二个副本，可能导致工具调用中断。请打开日志查看冲突插件并升级或移除它；不要继续使用已损坏的旧会话，请新建会话重新发送任务。检查器没有删除任何文件。"
        alert.addButton(withTitle: "打开诊断日志")
        alert.addButton(withTitle: "关闭")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/DeepSeekHarness.log"))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        retryTimer?.invalidate()
        retryCount = 0
        serviceStartRequested = false
        hideLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        retryLoadingHarness()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        retryLoadingHarness()
    }

    private func retryLoadingHarness() {
        retryTimer?.invalidate()
        retryCount += 1
        if retryCount >= 120 {
            serviceStartRequested = false
            showStartupFailure()
            return
        }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.ensureHarnessIsRunning(forceReload: true)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.host == "127.0.0.1" || url.host == "localhost" || url.scheme == "about" {
            decisionHandler(.allow)
        } else {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
