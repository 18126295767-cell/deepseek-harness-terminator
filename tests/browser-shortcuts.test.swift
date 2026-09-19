// 浏览器快捷键集（⌘L / ⌘1-9 / ⌘W / ⌘N 等）纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/BrowserShortcuts.swift tests/browser-shortcuts.test.swift -o tests/browser-shortcuts-test

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

// MARK: - 快捷键映射

func testAddressBarShortcut() {
    let command = BrowserShortcuts.parse(key: "l", modifier: .command)
    expectEqual(command, .focusAddressBar, "⌘L → 聚焦地址栏")
}

func testNewTabShortcut() {
    let command = BrowserShortcuts.parse(key: "n", modifier: .command)
    expectEqual(command, .newTab, "⌘N → 新建标签页")
}

func testCloseTabShortcut() {
    let command = BrowserShortcuts.parse(key: "w", modifier: .command)
    expectEqual(command, .closeTab, "⌘W → 关闭当前标签")
}

func testDigitSelectsTab() {
    expectEqual(BrowserShortcuts.parse(key: "3", modifier: .command), .selectTab(2), "⌘3 → 选择第 3 个标签")
    expectEqual(BrowserShortcuts.parse(key: "9", modifier: .command), .selectTab(8), "⌘9 → 选择第 9 个标签")
    expectEqual(BrowserShortcuts.parse(key: "0", modifier: .command), .selectTab(9), "⌘0 → 选择最后一个标签")
}

func testTabCycleShortcuts() {
    expectEqual(BrowserShortcuts.parse(key: "\t", modifier: .commandControl), .nextTab, "⌃⌘Tab → 下一个标签")
}

func testFindShortcut() {
    expectEqual(BrowserShortcuts.parse(key: "f", modifier: .command), .findInPage, "⌘F → 站内查找")
}

func testUnknownReturnsNil() {
    expectEqual(BrowserShortcuts.parse(key: "x", modifier: .command), nil, "未知快捷键 → nil")
}

// MARK: - 必备集合覆盖检查（防止漏配）

func testRoadmapShortcutCoverage() {
    // 路线图要求的每个快捷键都能解析成命令，且不重不漏。
    let mapped = BrowserShortcuts.roadmap.map { BrowserShortcuts.parse(key: $0.key, modifier: $0.modifier) }
    expect(mapped.allSatisfy { $0 != nil }, "路线图所有快捷键都能解析为命令")
    expectEqual(Set(mapped.compactMap { $0 }).count, mapped.compactMap { $0 }.count, "路线图快捷键映射到不同命令，无重复")
}

// MARK: - 运行

@main
struct BrowserShortcutsTestMain {
    static func main() {
        testAddressBarShortcut()
        testNewTabShortcut()
        testCloseTabShortcut()
        testDigitSelectsTab()
        testTabCycleShortcuts()
        testFindShortcut()
        testUnknownReturnsNil()
        testRoadmapShortcutCoverage()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}