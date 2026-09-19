import Foundation

/// 命令栏（command palette，⌘T）的条目载荷：纯 Foundation 深模块，无 AppKit 依赖。
///
/// `kind` 决定选中后执行的动作：
///  - `.openURL`：在浏览器打开 `target` URL；
///  - `.newTab`：新建标签页；
///  - `.runCommand`：执行命令（`target` 是命令标识，例如 "voice"）。
enum PaletteItemKind: Equatable {
    case openURL
    case newTab
    case runCommand
}

/// 命令栏中的一条可选条目：标题 + 副标题 + 动作 + 目标。
struct PaletteItem: Equatable {
    let title: String
    let subtitle: String
    let kind: PaletteItemKind
    let target: String

    init(title: String, subtitle: String, kind: PaletteItemKind, target: String) {
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.target = target
    }
}

/// 命令栏逻辑：给定条目清单，做大小写不敏感的标题/副标题/域名检索，
/// 支撑键盘上下移动（含回绕）与「/ 开头进入命令模式」的判定。
///
/// 它不持有 AppKit 视图，也不直接访问书签/历史存储；调用方把
/// `BrowserSessionStore` 的书签与最近访问转成 `PaletteItem` 喂进来即可。
/// 这样检索与导航逻辑可独立 `swiftc` 单测。
final class CommandPalette {
    private let items: [PaletteItem]
    private(set) var query: String = ""
    private(set) var filtered: [PaletteItem] = []

    /// 当前高亮下标（0-based；无条目时为 0）。
    private(set) var selectedIndex: Int = 0

    init(items: [PaletteItem]) {
        self.items = items
        self.filtered = items
    }

    /// 归一化后的检索词。
    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 以 `/` 前缀进入命令模式（G8 prompt 命令的入口标记）。
    var filteredContainsCommand: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")
    }

    /// 当前选中条目。
    var selectedItem: PaletteItem? {
        guard selectedIndex >= 0, selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }

    /// 命中标题列表（测试与 UI 用）。
    var filteredTitles: [String] { filtered.map { $0.title } }

    /// 更新检索词并重新过滤，选中回到开头。
    func updateQuery(_ raw: String) {
        query = raw
        let needle = normalizedQuery
        filtered = needle.isEmpty
            ? items
            : items.filter { match($0, needle: needle) }
        selectedIndex = 0
    }

    /// 上下移动选中（越过边界回绕）。返回新的选中下标。
    @discardableResult
    func moveSelection(down: Bool) -> Int {
        guard !filtered.isEmpty else {
            selectedIndex = 0
            return 0
        }
        let count = filtered.count
        if down {
            selectedIndex = (selectedIndex + 1) % count
        } else {
            selectedIndex = (selectedIndex - 1 + count) % count
        }
        return selectedIndex
    }

    private func match(_ item: PaletteItem, needle: String) -> Bool {
        let title = item.title.lowercased()
        let subtitle = item.subtitle.lowercased()
        let host = hostOf(item.target).lowercased()
        return title.contains(needle) || subtitle.contains(needle) || host.contains(needle)
    }

    /// 从 URL/目标里粗略提取域名，供按 host 检索。
    private func hostOf(_ target: String) -> String {
        guard let url = URL(string: target), let host = url.host else {
            return target
        }
        return host
    }
}