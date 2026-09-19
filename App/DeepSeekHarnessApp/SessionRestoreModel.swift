import Foundation

/// 会话与标签生命周期恢复（G9）的纯 Foundation 深模块：无 AppKit/WebKit 依赖。
///
/// 把「打开的标签集 + 选中索引 + 滚动位置」序列化进注入的 `KeyValueStorage`，
/// 下次启动即恢复；关闭面板/退出时保存。纯本地、数据不出本机，与
/// `BrowserSessionStore` 使用同一持久化 seam，便于跨实例测试。
struct RestorableTab: Equatable {
    let url: URL
    let title: String
}

/// 恢复出的会话。
struct SessionSnapshot: Equatable {
    let tabs: [RestorableTab]
    let selectedIndex: Int
    let scrollY: Double
}

final class SessionRestoreModel {
    private let storage: KeyValueStorage
    private static let key = "browser.session.restore.v1"

    /// 允许恢复的最大标签数（防止脏数据撑爆）。
    private let maxTabs = 50

    private struct DTO: Codable {
        var tabs: [TabDTO]
        var selectedIndex: Int
        var scrollY: Double
    }
    private struct TabDTO: Codable {
        var url: String
        var title: String
    }

    init(storage: KeyValueStorage) {
        self.storage = storage
    }

    /// 保存当前会话。
    func save(tabs: [RestorableTab], selectedIndex: Int, scrollY: Double) {
        let dto = DTO(
            tabs: tabs.prefix(maxTabs).map { TabDTO(url: $0.url.absoluteString, title: $0.title) },
            selectedIndex: selectedIndex,
            scrollY: scrollY
        )
        guard let data = try? JSONEncoder().encode(dto),
              let json = String(data: data, encoding: .utf8) else { return }
        storage.set(json, forKey: Self.key)
    }

    /// 恢复会话；无可恢复会话或标签列表为空时返回 nil。
    func restore() -> SessionSnapshot? {
        guard let json = storage.string(forKey: Self.key),
              let data = json.data(using: .utf8),
              let dto = try? JSONDecoder().decode(DTO.self, from: data),
              !dto.tabs.isEmpty else { return nil }

        let tabs = dto.tabs.map { RestorableTab(url: URL(string: $0.url) ?? URL(string: "about:blank")!, title: $0.title) }
        let selected = min(max(0, dto.selectedIndex), tabs.count - 1)
        return SessionSnapshot(tabs: tabs, selectedIndex: selected, scrollY: dto.scrollY)
    }

    /// 清除已持久化的会话。
    func clear() {
        storage.set("", forKey: Self.key)
    }
}