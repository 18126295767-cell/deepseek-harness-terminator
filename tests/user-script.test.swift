// 用户脚本 / 站点定制（G12）纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/UserScriptStore.swift tests/user-script.test.swift -o tests/user-script-test

var failures = 0
var checks = 0

func expect(_ cond: Bool, _ label: String) {
    checks += 1
    if !cond {
        failures += 1
        print("FAIL: \(label)")
    }
}

func expectEqual<T: Equatable>(_ got: T?, _ want: T?, _ label: String) {
    checks += 1
    if got != want {
        failures += 1
        print("FAIL: \(label) — got \(String(describing: got)), want \(String(describing: want))")
    }
}

/// 内存 KV 桩。
final class InMemoryKV2: KeyValueStorage {
    private var store: [String: String] = [:]
    func set(_ value: String, forKey key: String) { store[key] = value }
    func string(forKey key: String) -> String? { store[key] }
}

func makeStore() -> UserScriptStore {
    UserScriptStore(storage: InMemoryKV2())
}

// MARK: - 添加与列表

func testAddScript() {
    let store = makeStore()
    store.upsert(id: "s1", name: "暗色主题", source: "document.body.style.background='#000'", urlPattern: "*://*.example.com/*", isActive: true)
    expectEqual(store.all().count, 1, "添加后有一条脚本")
    expectEqual(store.all().first?.name, "暗色主题", "脚本名正确")
}

// MARK: - 启用/禁用

func testToggleActive() {
    let store = makeStore()
    store.upsert(id: "s1", name: "x", source: "y", urlPattern: "*", isActive: true)
    store.setActive(id: "s1", active: false)
    expect(store.all().first?.isActive == false, "可禁用脚本")
    store.setActive(id: "s1", active: true)
    expect(store.all().first?.isActive == true, "可重新启用脚本")
}

// MARK: - 作用域匹配

func testMatchByPattern() {
    let store = makeStore()
    store.upsert(id: "s1", name: "a", source: "x", urlPattern: "*://*.apple.com/*", isActive: true)
    let url = URL(string: "https://www.apple.com/newsroom/")!
    expectEqual(store.activeScripts(for: url).count, 1, "URL 命中脚本")
    let other = URL(string: "https://www.google.com")!
    expectEqual(store.activeScripts(for: other).count, 0, "不匹配的 URL 不注入")
}

func testInactiveNotInjected() {
    let store = makeStore()
    store.upsert(id: "s1", name: "a", source: "x", urlPattern: "*", isActive: false)
    let url = URL(string: "https://example.com")!
    expectEqual(store.activeScripts(for: url).count, 0, "禁用的脚本不注入")
}

// MARK: - 删除

func testRemoveScript() {
    let store = makeStore()
    store.upsert(id: "s1", name: "a", source: "x", urlPattern: "*", isActive: true)
    store.remove(id: "s1")
    expectEqual(store.all().count, 0, "删除后无脚本")
}

// MARK: - 运行

@main
struct UserScriptTestMain {
    static func main() {
        testAddScript()
        testToggleActive()
        testMatchByPattern()
        testInactiveNotInjected()
        testRemoveScript()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}