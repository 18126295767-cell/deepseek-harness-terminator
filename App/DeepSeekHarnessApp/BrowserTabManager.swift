import Foundation

/// 浏览器标签模型（纯 Foundation 深模块，无 AppKit/WebKit 依赖，可独立 swiftc 单测）。
///
/// 设计（对应 Alpha 架构 M2 的标签管理需求）：
///  - 每个标签有唯一 id、标题、url、可选 favicon；
///  - 可判等（按 id），用于 TabManager 的状态管理。
struct BrowserTab: Equatable {
    /// 唯一标识（UUID 风格，由 TabManager 生成）。
    let id: String
    /// 页面标题（初始为空串，由 WKWebView 导航回调更新）。
    var title: String
    /// 页面 URL。
    var url: URL
    /// 网站图标（可选，由 WKWebView 导航回调更新）。
    var favicon: URL?

    init(id: String = UUID().uuidString, title: String = "", url: URL, favicon: URL? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.favicon = favicon
    }
}

/// 浏览器标签管理器（纯 Foundation 深模块，无 AppKit/WebKit 依赖，可独立 swiftc 单测）。
///
/// 职责：
///  - 维护标签列表与选中状态；
///  - 提供添加/删除/选中/切换标签的操作；
///  - 所有操作保证索引有效性（删除时自动调整选中）。
///
/// 使用方：BrowserPaneController 持有此管理器，并根据其状态更新 WKWebView 与 UI。
final class BrowserTabManager {
    /// 所有标签（按添加顺序）。
    private(set) var tabs: [BrowserTab] = []
    /// 当前选中标签的索引；无标签时为 -1。
    private(set) var selectedIndex: Int = -1

    /// 标签总数。
    var tabCount: Int { tabs.count }

    /// 当前选中的标签（无标签时返回 nil）。
    var selectedTab: BrowserTab? {
        guard selectedIndex >= 0, selectedIndex < tabs.count else { return nil }
        return tabs[selectedIndex]
    }

    /// 是否可以切换到下一个标签。
    var canGoNext: Bool {
        selectedIndex >= 0 && selectedIndex < tabs.count - 1
    }

    /// 是否可以切换到上一个标签。
    var canGoPrevious: Bool {
        selectedIndex > 0
    }

    // MARK: - 操作

    /// 添加一个新标签（追加到末尾并自动选中）。
    /// - Parameter url: 新标签的初始 URL。
    /// - Returns: 新创建的标签。
    @discardableResult
    func addTab(url: URL) -> BrowserTab {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        selectedIndex = tabs.count - 1
        return tab
    }

    /// 删除指定标签。
    /// - Parameter id: 要删除的标签 id。
    /// - Returns: 是否成功删除（id 存在时返回 true）。
    ///
    /// 删除后选中索引自动调整：
    ///  - 若删除的是当前选中的标签，选中同位置的新标签（若存在），否则回退到前一个。
    @discardableResult
    func removeTab(id: String) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        tabs.remove(at: index)
        if tabs.isEmpty {
            selectedIndex = -1
        } else if index <= selectedIndex {
            // 删除的是当前选中或其前面的标签，索引需要回退。
            selectedIndex = min(index, tabs.count - 1)
        }
        return true
    }

    /// 选中指定标签。
    /// - Parameter id: 要选中的标签 id。
    /// - Returns: 是否成功选中（id 存在时返回 true）。
    @discardableResult
    func selectTab(id: String) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        selectedIndex = index
        return true
    }

    /// 切换到下一个标签（不循环）。
    /// - Returns: 是否成功切换（有下一个时返回 true）。
    @discardableResult
    func nextTab() -> Bool {
        guard canGoNext else { return false }
        selectedIndex += 1
        return true
    }

    /// 切换到上一个标签（不循环）。
    /// - Returns: 是否成功切换（有上一个时返回 true）。
    @discardableResult
    func previousTab() -> Bool {
        guard canGoPrevious else { return false }
        selectedIndex -= 1
        return true
    }

    /// 更新指定标签的标题和 URL。
    /// - Parameters:
    ///   - id: 要更新的标签 id。
    ///   - title: 新标题。
    ///   - url: 新 URL。
    /// - Returns: 是否成功更新（id 存在时返回 true）。
    @discardableResult
    func updateTab(id: String, title: String, url: URL) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        tabs[index].title = title
        tabs[index].url = url
        return true
    }

    /// 更新指定标签的 favicon。
    /// - Parameters:
    ///   - id: 要更新的标签 id。
    ///   - favicon: 新 favicon URL（nil 表示清除）。
    /// - Returns: 是否成功更新。
    @discardableResult
    func updateFavicon(id: String, favicon: URL?) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        tabs[index].favicon = favicon
        return true
    }
}
