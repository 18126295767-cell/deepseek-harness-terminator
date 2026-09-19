// 浏览器会话存储（书签 + 最近访问历史）纯逻辑单测（swiftc 编译运行；
// 由 tests/package.test.mjs 驱动）。纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/BrowserSessionStore.swift tests/browser-session.test.swift -o tests/browser-session-test

var failures = 0
var checks = 0

func expect(_ cond: Bool, _ label: String) {
    checks += 1
    if !cond {
        failures += 1
        print("FAIL: \(label)")
    }
}

func expectEqual<T: Equatable>(_ got: T, _ want: T, _ label: String) {
    checks += 1
    if got != want {
        failures += 1
        print("FAIL: \(label) — got \(got), want \(want)")
    }
}

// MARK: - 使用内存存储做持久化 seam（不碰 UserDefaults，测试可重复）

final class InMemoryKV: KeyValueStorage {
    var dict: [String: String] = [:]
    func set(_ value: String, forKey key: String) { dict[key] = value }
    func string(forKey key: String) -> String? { dict[key] }
}

// MARK: - 书签测试

func testAddAndRemoveBookmark() {
    let store = BrowserSessionStore(kv: InMemoryKV())
    let url = URL(string: "https://example.com")!

    expect(store.bookmarks.isEmpty, "初始无书签")
    store.addBookmark(title: "示例", url: url)
    expect(store.bookmarks.count == 1, "添加后书签数量为 1")
    expectEqual(store.bookmarks.first?.title, "示例", "书签标题")
    expectEqual(store.bookmarks.first?.url, url, "书签 URL")

    store.removeBookmark(url: url)
    expect(store.bookmarks.isEmpty, "移除后书签为空")
}

func testDuplicateBookmarkReplacesTitle() {
    let store = BrowserSessionStore(kv: InMemoryKV())
    let url = URL(string: "https://example.com")!
    store.addBookmark(title: "旧标题", url: url)
    store.addBookmark(title: "新标题", url: url)
    expect(store.bookmarks.count == 1, "重复 URL 不新增")
    expectEqual(store.bookmarks.first?.title, "新标题", "重复收藏用最新标题")
    expect(store.isBookmarked(url: url), "isBookmarked 返回 true")
}

// MARK: - 历史测试

func testRecentVisitsAreLifoAndCapped() {
    let store = BrowserSessionStore(kv: InMemoryKV())
    let url1 = URL(string: "https://a.com")!
    let url2 = URL(string: "https://b.com")!
    let url3 = URL(string: "https://c.com")!

    store.recordVisit(url: url1, title: "A")
    store.recordVisit(url: url2, title: "B")
    store.recordVisit(url: url3, title: "C")
    expectEqual(store.recentVisits.count, 3, "记录三次访问")
    expectEqual(store.recentVisits.first?.url, url3, "最近访问排最前（LIFO）")

    // 上限：默认 50
    for i in 0..<60 {
        store.recordVisit(url: URL(string: "https://bulk\(i).com")!, title: "B\(i)")
    }
    expect(store.recentVisits.count <= 50, "历史条数有上限")
    expectEqual(store.recentVisits.first?.url.absoluteString, "https://bulk59.com", "上限裁剪后最新仍在最前")
}

func testPersistAcrossInstances() {
    let kv = InMemoryKV()
    do {
        let store = BrowserSessionStore(kv: kv)
        store.addBookmark(title: "持久", url: URL(string: "https://persist.com")!)
        store.recordVisit(url: URL(string: "https://visit.com")!, title: "访问")
    }
    let store2 = BrowserSessionStore(kv: kv)
    expect(store2.bookmarks.count == 1, "书签跨实例持久化")
    expect(store2.recentVisits.count == 1, "历史跨实例持久化")
}

// MARK: - 查找/搜索测试（命令栏用）

func testSearchFindsBookmarkByTitleOrHost() {
    let store = BrowserSessionStore(kv: InMemoryKV())
    store.addBookmark(title: "DeepSeek 文档", url: URL(string: "https://deepseek.com")!)
    store.addBookmark(title: "Apple", url: URL(string: "https://www.apple.com")!)

    let byTitle = store.searchBookmarks("deepseek")
    expect(byTitle.count == 1, "按标题搜索命中")
    expectEqual(byTitle.first?.title, "DeepSeek 文档", "标题命中正确")

    let byHost = store.searchBookmarks("apple")
    expect(byHost.count == 1, "按主机搜索命中")
    expectEqual(byHost.first?.title, "Apple", "主机命中正确")
}

// MARK: - 运行

@main
struct BrowserSessionTestMain {
    static func main() {
        testAddAndRemoveBookmark()
        testDuplicateBookmarkReplacesTitle()
        testRecentVisitsAreLifoAndCapped()
        testPersistAcrossInstances()
        testSearchFindsBookmarkByTitleOrHost()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
