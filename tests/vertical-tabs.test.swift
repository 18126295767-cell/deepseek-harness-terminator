// 垂直多标签栏 / 工作区折叠（G11，Floorp 式）纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/VerticalTabsModel.swift tests/vertical-tabs.test.swift -o tests/vertical-tabs-test

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

// MARK: - 分组折叠

func testManualGrouping() {
    let model = VerticalTabsModel(groupingKey: { $0.title.components(separatedBy: " ").first ?? $0.title })
    model.group(tabs: [
        VTab(title: "Apple", id: "a1"),
        VTab(title: "Apple News", id: "a2"),
        VTab(title: "Bing", id: "b1"),
    ])
    expectEqual(model.groups.map { $0.name }.sorted(), ["Apple", "Bing"].sorted(), "按标题首词分组")
}

func testExpandCollapse() {
    let model = VerticalTabsModel(groupingKey: { String($0.title.prefix(1)) })
    model.group(tabs: [
        VTab(title: "Alpha", id: "a1"),
        VTab(title: "Beta", id: "b1"),
    ])
    expectEqual(model.groups.count, 2, "两组")
    // 默认展开。
    expect(model.isCollapsed(group: "A") == false, "默认展开")
    model.toggleCollapse("A")
    expect(model.isCollapsed(group: "A") == true, "折叠后收起")
    model.toggleCollapse("A")
    expect(model.isCollapsed(group: "A") == false, "再次切换展开")
}

func testVisibleTabsOnlyShowsExpanded() {
    let model = VerticalTabsModel(groupingKey: { String($0.title.prefix(1)) })
    model.group(tabs: [
        VTab(title: "Alpha", id: "a1"),
        VTab(title: "Apple", id: "a2"),
        VTab(title: "Beta", id: "b1"),
    ])
    model.toggleCollapse("A")
    let visible = model.visibleTabs()
    expectEqual(visible.map { $0.id }, ["b1"], "折叠 A 组后只显示 B 组标签")
}

// MARK: - 拖拽排序

func testMoveTabWithinGroup() {
    let model = VerticalTabsModel(groupingKey: { String($0.title.prefix(1)) })
    model.group(tabs: [
        VTab(title: "A1", id: "a1"),
        VTab(title: "A2", id: "a2"),
        VTab(title: "B1", id: "b1"),
    ])
    // a2 与 a1 同组（首字母 A）；把 a2 移到组内首位。
    model.move(tabID: "a2", toIndexWithinGroup: 0)
    let groupA = model.groups.first { $0.name == "A" }
    expectEqual(groupA?.tabs.map { $0.id }, ["a2", "a1"], "组内重排后 a2 到首位")
}

// MARK: - 运行

@main
struct VerticalTabsTestMain {
    static func main() {
        testManualGrouping()
        testExpandCollapse()
        testVisibleTabsOnlyShowsExpanded()
        testMoveTabWithinGroup()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}