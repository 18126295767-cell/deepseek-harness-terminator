// 分屏（split view，G6）纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/SplitPaneState.swift tests/split-pane.test.swift -o tests/split-pane-test

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

// MARK: - 开启/关闭

func testInitiallyClosed() {
    let state = SplitPaneState()
    expect(state.isActive == false, "初始分屏关闭")
    expectEqual(state.secondaryURL, nil, "初始无副屏 URL")
}

func testActivateWithURL() {
    var state = SplitPaneState()
    state.open(url: URL(string: "https://example.com/b")!)
    expect(state.isActive == true, "打开副屏后激活")
    expectEqual(state.secondaryURL?.absoluteString, "https://example.com/b", "副屏 URL 记录正确")
}

func testCloseClears() {
    var state = SplitPaneState()
    state.open(url: URL(string: "https://example.com/b")!)
    state.close()
    expect(state.isActive == false, "关闭后失活")
    expectEqual(state.secondaryURL, nil, "关闭后清空副屏 URL")
}

// MARK: - 镜像导航

func testMirrorFollowsPrimary() {
    var state = SplitPaneState()
    state.open(url: URL(string: "https://example.com/b")!)
    state.followPrimary(url: URL(string: "https://example.com/c")!)
    expectEqual(state.secondaryURL?.absoluteString, "https://example.com/c", "镜像模式下副屏跟随主屏导航")
}

func testNoMirrorWithoutReference() {
    var state = SplitPaneState()
    state.followPrimary(url: URL(string: "https://example.com/c")!)
    expectEqual(state.secondaryURL, nil, "未激活时不记录镜像")
}

// MARK: - 运行

@main
struct SplitPaneTestMain {
    static func main() {
        testInitiallyClosed()
        testActivateWithURL()
        testCloseClears()
        testMirrorFollowsPrimary()
        testNoMirrorWithoutReference()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}