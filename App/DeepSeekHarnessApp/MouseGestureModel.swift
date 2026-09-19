import Foundation

/// 鼠标手势 / 扩展（G14）的纯 Foundation 深模块：无 AppKit 依赖。
///
/// 受「不抢前台」约束，手势只在**内置浏览器面板范围内**生效（由薄 UI 层用本地
/// `NSEvent` 监听实现，绝不注册全局钩子）。本模块负责可单测的两件事：
/// 把拖拽位移量化为方向，以及把方向手势映射为页面命令。
enum MouseGestureModel {
    /// 手势方向。
    enum Direction: Equatable {
        case up, down, left, right
    }

    /// 手势触发的页面命令。
    enum Command: Equatable {
        case forward
        case back
        case refresh
    }

    /// 位移阈值（像素），小于该位移视为点击而非手势。
    static let threshold: CGFloat = 20

    /// 把拖拽位移量化为方向；不足阈值返回 nil。
    static func direction(dx: CGFloat, dy: CGFloat) -> Direction? {
        guard abs(dx) >= threshold || abs(dy) >= threshold else { return nil }
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .down : .up
        }
    }

    /// 方向手势 → 命令。常见映射：右=前进，左=后退，上=刷新，下=刷新（无惊悚行为）。
    static func gesture(_ direction: Direction) -> (command: Command, description: String)? {
        switch direction {
        case .right: return (.forward, "前进")
        case .left: return (.back, "后退")
        case .up, .down: return (.refresh, "刷新")
        }
    }
}