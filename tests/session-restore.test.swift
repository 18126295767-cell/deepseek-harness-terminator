// 会话与标签生命周期恢复（G9）纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/SessionRestoreModel.swift tests/session-restore.test.swift -o tests/session-restore-test

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

/// 内存 KV 桩（与会话测试一致），验证跨实例持久化 seam。
final class InMemoryKV: KeyValueStorage {
    private var store: [String: String] = [:]
    func set(_ value: String, forKey key: String) { store[key] = value }
    func string(forKey key: String) -> String? { store[key] }
}

func tabs() -> [RestorableTab] {
    [
        RestorableTab(url: URL(string: "https://www.apple.com")!, title: "Apple"),
        RestorableTab(url: URL(string: "https://www.bing.com")!, title: "Bing"),
    ]
}

// MARK: - 快照与恢复

func testSnapshotRoundTrips() {
    let kv = InMemoryKV()
    let model = SessionRestoreModel(storage: kv)
    model.save(tabs: tabs(), selectedIndex: 1, scrollY: 42)

    let restored = model.restore()
    expectEqual(restored?.tabs.count, 2, "恢复出 2 个标签")
    expectEqual(restored?.tabs[0].url.absoluteString, "https://www.apple.com", "第一个标签 URL 恢复正确")
    expectEqual(restored?.selectedIndex, 1, "恢复选中标签索引")
    expectEqual(restored?.scrollY, 42, "恢复滚动位置")
}

func testEmptySnapshotRestoresNil() {
    let kv = InMemoryKV()
    let model = SessionRestoreModel(storage: kv)
    // 从未保存过 → 无会话。
    expectEqual(model.restore(), nil, "无历史快照时返回 nil")
}

func testClearClearsPersisted() {
    let kv = InMemoryKV()
    let model = SessionRestoreModel(storage: kv)
    model.save(tabs: tabs(), selectedIndex: 0, scrollY: 0)
    expect(model.restore() != nil, "保存后存在会话")
    model.clear()
    expectEqual(model.restore(), nil, "清除后无会话")
}

// MARK: - 校验与钳制

func testRestoreClampsInvalidIndex() {
    let kv = InMemoryKV()
    let model = SessionRestoreModel(storage: kv)
    // 保存时选中索引越界，恢复时钳制到 0..<count。
    model.save(tabs: tabs(), selectedIndex: 99, scrollY: 0)
    let restored = model.restore()
    expect(restored != nil, "能恢复")
    expectEqual(restored?.selectedIndex, 1, "越界选中索引被钳制到最后一个")
}

func testRestoreIgnoresEmptyTabList() {
    let kv = InMemoryKV()
    let model = SessionRestoreModel(storage: kv)
    model.save(tabs: [], selectedIndex: 0, scrollY: 0)
    expectEqual(model.restore(), nil, "空标签列表当作无会话")
}

// MARK: - 运行

@main
struct SessionRestoreTestMain {
    static func main() {
        testSnapshotRoundTrips()
        testEmptySnapshotRestoresNil()
        testClearClearsPersisted()
        testRestoreClampsInvalidIndex()
        testRestoreIgnoresEmptyTabList()
        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}