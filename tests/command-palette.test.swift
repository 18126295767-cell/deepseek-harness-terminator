// 命令栏（command palette，⌘T）纯逻辑单测（swiftc 编译运行；由 tests/package.test.mjs 驱动）。
// 纯 Foundation，无 AppKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/CommandPalette.swift tests/command-palette.test.swift -o tests/command-palette-test

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

func makeItems() -> [PaletteItem] {
    [
        PaletteItem(title: "DeepSeek Harness", subtitle: "本地 AI 工作台", kind: .openURL, target: "http://127.0.0.1:3080/"),
        PaletteItem(title: "Apple", subtitle: "apple.com", kind: .openURL, target: "https://www.apple.com"),
        PaletteItem(title: "Bing Search", subtitle: "bing.com", kind: .openURL, target: "https://www.bing.com/search?q="),
        PaletteItem(title: "新建标签页", subtitle: "命令", kind: .newTab, target: ""),
        PaletteItem(title: "语音输入", subtitle: "命令", kind: .runCommand, target: "voice"),
    ]
}

// MARK: - 检索过滤

func testEmptyQueryReturnsAll() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("")
    expectEqual(palette.filteredTitles, ["DeepSeek Harness", "Apple", "Bing Search", "新建标签页", "语音输入"], "空前缀返回全部条目")
}

func testCaseInsensitiveMatchByTitleAndHost() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("apple")
    expectEqual(palette.filteredTitles, ["Apple"], "按标题/域名大小写不敏感匹配")
}

func testMatchBySubtitle() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("本地")
    expectEqual(palette.filteredTitles, ["DeepSeek Harness"], "匹配副标题")
}

func testMatchByHostOnly() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("bing.com")
    expectEqual(palette.filteredTitles, ["Bing Search"], "按 URL 域名匹配")
}

func testPrefixCommandMode() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("/")
    expect(palette.filteredContainsCommand, "以 / 开头进入命令模式")
}

// MARK: - 键盘导航

func testSelectionNavigation() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("")
    expectEqual(palette.selectedIndex, 0, "默认选中第 0 项")
    let down = palette.moveSelection(down: true)
    expectEqual(down, 1, "下移选中第 1 项")
    _ = palette.moveSelection(down: true)
    _ = palette.moveSelection(down: true)
    let downWrap = palette.moveSelection(down: true)
    expectEqual(downWrap, 4, "下移到末尾后回绕到开头")
    let up = palette.moveSelection(down: false)
    expectEqual(up, 3, "上移回绕到末尾")
}

func testSelectionResetsOnQueryChange() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("")
    _ = palette.moveSelection(down: true)
    _ = palette.moveSelection(down: true)
    palette.updateQuery("apple")
    expectEqual(palette.selectedIndex, 0, "查询变更后选中回到开头")
}

// MARK: - 命中动作

func testSelectedItemResolution() {
    let palette = CommandPalette(items: makeItems())
    palette.updateQuery("apple")
    guard let item = palette.selectedItem else {
        expect(false, "应能解析出选中条目")
        return
    }
    expectEqual(item.kind, .openURL, "选中条目动作为打开 URL")
    expectEqual(item.target, "https://www.apple.com", "选中条目 URL 正确")
}

// MARK: - 运行

@main
struct CommandPaletteTestMain {
    static func main() {
        testEmptyQueryReturnsAll()
        testCaseInsensitiveMatchByTitleAndHost()
        testMatchBySubtitle()
        testMatchByHostOnly()
        testPrefixCommandMode()
        testSelectionNavigation()
        testSelectionResetsOnQueryChange()
        testSelectedItemResolution()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}