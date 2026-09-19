// 垂直标签分组（G4）纯逻辑单测（swiftc 编译运行；由 tests/package.test.mjs 驱动）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/TabGroupingModel.swift tests/tab-grouping.test.swift -o tests/tab-grouping-test

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

func tabs() -> [TabGroupable] {
    [
        TabGroupable(title: "Apple", id: "a1"),
        TabGroupable(title: "Apple News", id: "a2"),
        TabGroupable(title: "Bing", id: "b1"),
        TabGroupable(title: "未分组页", id: "c1"),
    ]
}

// MARK: - 分组计算

func testGroupByDomain() {
    // 用「标题首词」作分组键，模拟按站点聚合（Apple / Apple News → Apple 组）。
    let model = TabGroupingModel(groupingKey: { $0.title.components(separatedBy: " ").first ?? $0.title })
    let groups = model.group(tabs())
    // 三个不同首词 → 三组（Apple、Bing、未分组页）。
    expectEqual(groups.map { $0.name }.sorted(), ["Apple", "Bing", "未分组页"].sorted(), "按分组键聚合同名")
    let apple = groups.first { $0.name == "Apple" }
    expectEqual(apple?.tabs.count, 2, "Apple 组含 2 个标签")
    expectEqual(apple?.tabs.map { $0.id }.sorted(), ["a1", "a2"].sorted(), "Apple 组标签 id 正确")
}

func testGroupOrderPreservesFirstSeen() {
    let model = TabGroupingModel(groupingKey: { String($0.title.prefix(1)) })
    let groups = model.group(tabs())
    expectEqual(groups.map { $0.name }, ["A", "B", "未"], "分组按首次出现顺序排列")
}

func testGroupSummary() {
    let model = TabGroupingModel(groupingKey: { $0.title.components(separatedBy: " ").first ?? $0.title })
    let groups = model.group(tabs())
    let apple = groups.first { $0.name == "Apple" }
    expectEqual(apple?.summary, "Apple（2）", "组摘要显示名称与数量")
}

// MARK: - 运行

@main
struct TabGroupingTestMain {
    static func main() {
        testGroupByDomain()
        testGroupOrderPreservesFirstSeen()
        testGroupSummary()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}