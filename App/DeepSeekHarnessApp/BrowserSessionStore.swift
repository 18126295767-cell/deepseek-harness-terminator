import Foundation

/// 会话存储的持久化接缝：允许注入不同的后端（测试用内存实现，运行时用 UserDefaults）。
protocol KeyValueStorage {
    func set(_ value: String, forKey key: String)
    func string(forKey key: String) -> String?
}

/// UserDefaults 实现的 KeyValueStorage（运行时默认后端）。
struct UserDefaultsStorage: KeyValueStorage {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func set(_ value: String, forKey key: String) { defaults.set(value, forKey: key) }
    func string(forKey key: String) -> String? { defaults.string(forKey: key) }
}

/// 书签条目。
struct BrowserBookmark: Equatable {
    let url: URL
    var title: String
}

/// 最近访问条目。
struct BrowserVisit: Equatable {
    let url: URL
    let title: String
}

/// 浏览器会话存储（书签 + 最近访问历史）：纯 Foundation 深模块，持久化经 `KeyValueStorage` 注入。
///
/// 对应需求缺口 G2（书签/历史）与 G1（命令栏检索）：
///  - `addBookmark`/`removeBookmark`/`isBookmarked`：收藏当前页；
///  - `recordVisit`：每次加载页面记录最近访问（LIFO，默认上限 50）；
///  - `searchBookmarks`：按标题/主机检索书签，供命令/查找栏使用。
/// 数据以 JSON 编码进 KV 后端，跨实例持久化；纯本地、不开发者外部。
final class BrowserSessionStore {
    private struct BookmarkDTO: Codable { var url: String; var title: String }
    private struct VisitDTO: Codable { var url: String; var title: String }

    private let kv: KeyValueStorage
    private let bookmarkKey = "browser.session.bookmarks"
    private let historyKey = "browser.session.recent"
    private let maxHistory: Int

    init(kv: KeyValueStorage, maxHistory: Int = 50) {
        self.kv = kv
        self.maxHistory = maxHistory
        loadBookmarks()
        loadHistory()
    }

    convenience init() {
        self.init(kv: UserDefaultsStorage())
    }

    // MARK: - 书签

    private(set) var bookmarks: [BrowserBookmark] = []

    func isBookmarked(url: URL) -> Bool {
        loadBookmarks()
        return bookmarks.contains { $0.url == url }
    }

    func addBookmark(title: String, url: URL) {
        loadBookmarks()
        // 已存在则用最新标题替换（不新增重复项）。
        if let idx = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks[idx].title = title
        } else {
            bookmarks.append(BrowserBookmark(url: url, title: title))
        }
        saveBookmarks()
    }

    func removeBookmark(url: URL) {
        loadBookmarks()
        bookmarks.removeAll { $0.url == url }
        saveBookmarks()
    }

    func reload() {
        loadBookmarks()
        loadHistory()
    }

    // MARK: - 历史

    private(set) var recentVisits: [BrowserVisit] = []

    func recordVisit(url: URL, title: String) {
        loadHistory()
        // 相同 URL 去重：移除旧记录，置顶最新标题。
        recentVisits.removeAll { $0.url == url }
        recentVisits.insert(BrowserVisit(url: url, title: title), at: 0)
        if recentVisits.count > maxHistory {
            recentVisits = Array(recentVisits.prefix(maxHistory))
        }
        saveHistory()
    }

    // MARK: - 检索（命令栏）

    /// 检索书签：命中标题或主机（大小写不敏感）。空查询返回全部。
    func searchBookmarks(_ query: String) -> [BrowserBookmark] {
        loadBookmarks()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return bookmarks }
        return bookmarks.filter {
            $0.title.lowercased().contains(q) || ($0.url.host?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - 持久化

    private func loadBookmarks() {
        guard let data = kv.string(forKey: bookmarkKey)?.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([BookmarkDTO].self, from: data) else {
            bookmarks = []
            return
        }
        bookmarks = dtos.compactMap { dto in
            guard let url = URL(string: dto.url) else { return nil }
            return BrowserBookmark(url: url, title: dto.title)
        }
    }

    private func saveBookmarks() {
        let dtos = bookmarks.map { BookmarkDTO(url: $0.url.absoluteString, title: $0.title) }
        if let data = try? JSONEncoder().encode(dtos), let s = String(data: data, encoding: .utf8) {
            kv.set(s, forKey: bookmarkKey)
        }
    }

    private func loadHistory() {
        guard let data = kv.string(forKey: historyKey)?.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([VisitDTO].self, from: data) else {
            recentVisits = []
            return
        }
        recentVisits = dtos.compactMap { dto in
            guard let url = URL(string: dto.url) else { return nil }
            return BrowserVisit(url: url, title: dto.title)
        }
    }

    private func saveHistory() {
        let dtos = recentVisits.map { VisitDTO(url: $0.url.absoluteString, title: $0.title) }
        if let data = try? JSONEncoder().encode(dtos), let s = String(data: data, encoding: .utf8) {
            kv.set(s, forKey: historyKey)
        }
    }
}