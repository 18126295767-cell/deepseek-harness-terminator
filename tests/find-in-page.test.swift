// 站内查找（find-in-page）纯逻辑单测（swiftc 编译运行；由 tests/package.test.mjs 驱动）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/FindInPageModel.swift tests/find-in-page.test.swift -o tests/find-in-page-test

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

func expectNil(_ v: Int?, _ label: String) {
    checks += 1
    if v != nil { failures += 1; print("FAIL: \(label) — expected nil, got \(v!)") }
}

// MARK: - 查询归一化

func testEmptyQueryIsInactive() {
    let model = FindInPageModel()
    expect(model.isActive == false, "初始无查询 → 不激活")
    model.setQuery("   ")
    expect(model.isActive == false, "空白查询 → 不激活")
}

func testWhitespaceTrimmed() {
    let model = FindInPageModel()
    model.setQuery("  hello  ")
    expectEqual(model.query, "hello", "查询去除首尾空白")
    expect(model.isActive == true, "非空查询 → 激活")
}

// MARK: - 匹配计数与当前索引

func testMatchCountUpdates() {
    let model = FindInPageModel()
    model.setQuery("foo")
    model.match(count: 3)
    expectEqual(model.matchCount, 3, "匹配总数")
    expectEqual(model.currentIndex, 0, "默认从第 0 个匹配开始")
}

func testAdvanceWraps() {
    let model = FindInPageModel()
    model.setQuery("foo")
    model.match(count: 3)
    // 0 → 1
    let next = model.advance(forward: true)
    expectEqual(next, 1, "前进到第 1 个匹配")
    // 1 → 2
    let last = model.advance(forward: true)
    expectEqual(last, 2, "前进到最后一个匹配")
    // wrap: 2 → 0
    let wrap = model.advance(forward: true)
    expectEqual(wrap, 0, "越过末尾回绕到第 0 个")
}

func testAdvanceBackwardWraps() {
    let model = FindInPageModel()
    model.setQuery("x")
    model.match(count: 2)
    _ = model.advance(forward: true) // 0→1
    let back = model.advance(forward: false) // 1→0
    expectEqual(back, 0, "后退到前一个")
    let wrapBack = model.advance(forward: false) // 0→1 (回绕到最后一个)
    expectEqual(wrapBack, 1, "越过开头回绕到最后一个")
}

func testAdvanceWithZeroOrOneMatch() {
    let model = FindInPageModel()
    model.setQuery("none")
    model.match(count: 0)
    expectNil(model.advance(forward: true), "零匹配不前进")
    expectNil(model.advance(forward: false), "零匹配不后退")

    model.match(count: 1)
    expectNil(model.advance(forward: true), "单匹配前进仍为第 0 个（nil）")
    expectNil(model.advance(forward: false), "单匹配后退仍为第 0 个（nil）")
}

func testChangeQueryResetsMatches() {
    let model = FindInPageModel()
    model.setQuery("aaa")
    model.match(count: 5)
    model.setQuery("bbb")
    expectEqual(model.matchCount, 0, "查询变更后计数清零")
    expectEqual(model.currentIndex, 0, "查询变更后索引回到开头")
}

// MARK: - 显示文案（供查找条 UI）

func testStatusText() {
    let model = FindInPageModel()
    model.setQuery("foo")
    model.match(count: 3)
    model.setCurrentIndex(2)
    expectEqual(model.statusText, "2/3", "状态文案显示当前/总数")
}

// MARK: - 运行

@main
struct FindInPageTestMain {
    static func main() {
        testEmptyQueryIsInactive()
        testWhitespaceTrimmed()
        testMatchCountUpdates()
        testAdvanceWraps()
        testAdvanceBackwardWraps()
        testAdvanceWithZeroOrOneMatch()
        testChangeQueryResetsMatches()
        testStatusText()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}