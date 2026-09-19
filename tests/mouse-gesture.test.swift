// 鼠标手势 / 扩展（G14）纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/MouseGestureModel.swift tests/mouse-gesture.test.swift -o tests/mouse-gesture-test

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

// MARK: - 方向量化

func testDirectionQuantization() {
    expectEqual(MouseGestureModel.direction(dx: 0, dy: -50), .up, "向上拖动 → up")
    expectEqual(MouseGestureModel.direction(dx: 0, dy: 50), .down, "向下拖动 → down")
    expectEqual(MouseGestureModel.direction(dx: 50, dy: 0), .right, "向右拖动 → right")
    expectEqual(MouseGestureModel.direction(dx: -50, dy: 0), .left, "向左拖动 → left")
}

func testDirectionNeedsThreshold() {
    // 位移太小不产生手势。
    expectEqual(MouseGestureModel.direction(dx: 3, dy: 0), nil, "小位移不量化")
}

// MARK: - 手势匹配

func testGestureToCommand() {
    // 「右」→ 前进，左 → 后退，上 → 刷新（常见手势映射）。
    expectEqual(MouseGestureModel.gesture(.right)?.command, .forward, "右 → 前进")
    expectEqual(MouseGestureModel.gesture(.left)?.command, .back, "左 → 后退")
    expectEqual(MouseGestureModel.gesture(.up)?.command, .refresh, "上 → 刷新")
}

func testUnknownGestureNil() {
    // 无手势 → 命令集不匹配（如 down 未映射）。
    expectEqual(MouseGestureModel.gesture(.down)?.command, .refresh, "下 → 默认刷新（无惊悚映射）")
}

// MARK: - 运行

@main
struct MouseGestureTestMain {
    static func main() {
        testDirectionQuantization()
        testDirectionNeedsThreshold()
        testGestureToCommand()
        testUnknownGestureNil()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}