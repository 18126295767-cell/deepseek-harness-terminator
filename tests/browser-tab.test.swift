// 浏览器标签管理的独立单测（swiftc 编译运行；由 tests/package.test.mjs 的 node test 驱动）。
// 纯 Foundation，无 AppKit/WebKit 依赖，可在 CI 无 GUI 环境运行。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/BrowserTabManager.swift tests/browser-tab.test.swift -o tests/browser-tab-test

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

// MARK: - Tab 模型测试

func testTabModel() {
    let url = URL(string: "https://example.com")!
    let tab = BrowserTab(id: "tab-1", title: "示例", url: url)
    
    expectEqual(tab.id, "tab-1", "tab id")
    expectEqual(tab.title, "示例", "tab title")
    expectEqual(tab.url, url, "tab url")
    expect(tab.favicon == nil, "默认无 favicon")
    
    let tabWithFavicon = BrowserTab(id: "tab-2", title: "带图标", url: url, favicon: URL(string: "https://example.com/favicon.ico"))
    expect(tabWithFavicon.favicon != nil, "可设置 favicon")
}

// MARK: - TabManager 测试

func testAddTab() {
    let manager = BrowserTabManager()
    let url = URL(string: "https://example.com")!
    
    let tab = manager.addTab(url: url)
    expect(manager.tabs.count == 1, "添加一个标签后数量为 1")
    expect(manager.selectedIndex == 0, "首个标签自动选中")
    expect(tab.id.isEmpty == false, "生成的 tab id 非空")
    expectEqual(tab.url, url, "标签 url 与输入一致")
}

func testSelectTab() {
    let manager = BrowserTabManager()
    let url1 = URL(string: "https://example.com/1")!
    let url2 = URL(string: "https://example.com/2")!

    manager.addTab(url: url1)
    let tab2 = manager.addTab(url: url2)

    expect(manager.selectedIndex == 1, "添加新标签后自动选中最后一个")
    
    let selected = manager.selectTab(id: tab2.id)
    expect(selected == true, "选中存在的标签返回 true")
    expect(manager.selectedIndex == 1, "选中后索引更新")
    expectEqual(manager.selectedTab?.id, tab2.id, "selectedTab 返回当前选中")
    
    let notSelected = manager.selectTab(id: "non-existent")
    expect(notSelected == false, "选中不存在的标签返回 false")
    expect(manager.selectedIndex == 1, "选中失败不改变索引")
}

func testRemoveTab() {
    let manager = BrowserTabManager()
    let url1 = URL(string: "https://example.com/1")!
    let url2 = URL(string: "https://example.com/2")!
    let url3 = URL(string: "https://example.com/3")!
    
    manager.addTab(url: url1)
    let tab2 = manager.addTab(url: url2)
    let tab3 = manager.addTab(url: url3)
    
    // 删除中间的标签，选中索引应调整
    manager.selectTab(id: tab2.id)
    expect(manager.selectedIndex == 1, "选中第二个标签")
    
    let removed = manager.removeTab(id: tab2.id)
    expect(removed == true, "删除存在的标签返回 true")
    expect(manager.tabs.count == 2, "删除后数量为 2")
    expect(manager.selectedIndex == 1, "删除中间标签后索引保持有效")
    expectEqual(manager.selectedTab?.id, tab3.id, "删除后选中下一个")
    
    // 删除最后一个标签，选中应回退
    let removedLast = manager.removeTab(id: tab3.id)
    expect(removedLast == true, "删除最后一个返回 true")
    expect(manager.selectedIndex == 0, "删除最后一个后选中回退到 0")
    
    // 删除不存在的标签
    let notRemoved = manager.removeTab(id: "non-existent")
    expect(notRemoved == false, "删除不存在的标签返回 false")
}

func testRemoveLastTab() {
    let manager = BrowserTabManager()
    let url = URL(string: "https://example.com")!
    let tab = manager.addTab(url: url)
    
    // 删除最后一个标签时，不应崩溃，索引归 -1
    let removed = manager.removeTab(id: tab.id)
    expect(removed == true, "删除最后一个标签返回 true")
    expect(manager.tabs.count == 0, "删除后数量为 0")
    expect(manager.selectedIndex == -1, "无标签时索引为 -1")
    expect(manager.selectedTab == nil, "无标签时 selectedTab 为 nil")
}

func testNextPreviousTab() {
    let manager = BrowserTabManager()
    let tab1 = manager.addTab(url: URL(string: "https://a.com")!)
    _ = manager.addTab(url: URL(string: "https://b.com")!)
    _ = manager.addTab(url: URL(string: "https://c.com")!)

    manager.selectTab(id: tab1.id)
    expect(manager.selectedIndex == 0, "手动选中第一个")
    
    let next1 = manager.nextTab()
    expect(next1 == true, "nextTab 有下一个返回 true")
    expect(manager.selectedIndex == 1, "nextTab 移动到第二个")
    
    let next2 = manager.nextTab()
    expect(next2 == true, "再次 nextTab 返回 true")
    expect(manager.selectedIndex == 2, "移动到第三个")
    
    let next3 = manager.nextTab()
    expect(next3 == false, "已到最后一个，nextTab 返回 false")
    expect(manager.selectedIndex == 2, "索引不变（不循环）")
    
    let prev1 = manager.previousTab()
    expect(prev1 == true, "previousTab 返回 true")
    expect(manager.selectedIndex == 1, "回退到第二个")
    
    let prev2 = manager.previousTab()
    expect(prev2 == true, "再次 previousTab 返回 true")
    expect(manager.selectedIndex == 0, "回退到第一个")
    
    let prev3 = manager.previousTab()
    expect(prev3 == false, "已到第一个，previousTab 返回 false")
}

func testNextPreviousTabSingleTab() {
    let manager = BrowserTabManager()
    _ = manager.addTab(url: URL(string: "https://a.com")!)
    
    expect(manager.nextTab() == false, "只有一个标签时 nextTab 返回 false")
    expect(manager.previousTab() == false, "只有一个标签时 previousTab 返回 false")
    expect(manager.selectedIndex == 0, "索引不变")
}

func testNextPreviousTabEmpty() {
    let manager = BrowserTabManager()
    expect(manager.nextTab() == false, "无标签时 nextTab 返回 false")
    expect(manager.previousTab() == false, "无标签时 previousTab 返回 false")
}

func testUpdateTab() {
    let manager = BrowserTabManager()
    let tab = manager.addTab(url: URL(string: "https://example.com")!)
    
    let newURL = URL(string: "https://example.com/new")!
    let updated = manager.updateTab(id: tab.id, title: "新标题", url: newURL)
    
    expect(updated == true, "更新存在的标签返回 true")
    expectEqual(manager.tabs[0].title, "新标题", "标题已更新")
    expectEqual(manager.tabs[0].url, newURL, "url 已更新")
    
    let notUpdated = manager.updateTab(id: "non-existent", title: "x", url: newURL)
    expect(notUpdated == false, "更新不存在的标签返回 false")
}

func testTabCount() {
    let manager = BrowserTabManager()
    expect(manager.tabCount == 0, "初始数量为 0")
    _ = manager.addTab(url: URL(string: "https://a.com")!)
    expect(manager.tabCount == 1, "添加后数量为 1")
    _ = manager.addTab(url: URL(string: "https://b.com")!)
    expect(manager.tabCount == 2, "再添加后数量为 2")
}

func testCanGoNextCanGoPrevious() {
    let manager = BrowserTabManager()
    let tab1 = manager.addTab(url: URL(string: "https://a.com")!)
    _ = manager.addTab(url: URL(string: "https://b.com")!)

    manager.selectTab(id: tab1.id)
    expect(manager.canGoNext == true, "有两个标签时可以 next")
    expect(manager.canGoPrevious == false, "在第一个不能 previous")

    manager.nextTab()
    expect(manager.canGoNext == false, "在最后一个不能 next")
    expect(manager.canGoPrevious == true, "在第二个可以 previous")
}

func testTabEquatable() {
    let url = URL(string: "https://example.com")!
    let tab1 = BrowserTab(id: "tab-1", title: "A", url: url)
    let tab2 = BrowserTab(id: "tab-1", title: "A", url: url)
    let tab3 = BrowserTab(id: "tab-2", title: "A", url: url)
    
    expect(tab1 == tab2, "相同 id 的标签相等")
    expect(tab1 != tab3, "不同 id 的标签不等")
}

@main
struct BrowserTabTestMain {
    static func main() {
        testTabModel()
        testAddTab()
        testSelectTab()
        testRemoveTab()
        testRemoveLastTab()
        testNextPreviousTab()
        testNextPreviousTabSingleTab()
        testNextPreviousTabEmpty()
        testUpdateTab()
        testTabCount()
        testCanGoNextCanGoPrevious()
        testTabEquatable()
        print("\n\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
