import Foundation

/// 浏览器快捷键集的纯 Foundation 深模块：无 AppKit 依赖。
///
/// 把路线图要求的标准浏览器快捷键（⌘L 定位地址栏、⌘1-9 选标签、
/// ⌘W 关标签、⌘N 新建等）统一成 `key + modifier` → `Command` 的映射。
/// 菜单配置侧据此放置 keyEquivalent 与修饰键，侧栏/查找栏动作据此分发，
/// 保证「快捷键集合」这一需求可被独立 `swiftc` 单测，而不散落在 AppKit 胶水里。
enum BrowserShortcuts {
    /// 修饰键组合。
    enum Modifier {
        case command
        case commandShift
        case commandControl
    }

    /// 语义命令。
    enum Command: Equatable, Hashable {
        case focusAddressBar
        case newTab
        case closeTab
        case findInPage
        case selectTab(Int)
        case nextTab
        case previousTab
    }

    /// 解析一组按键为语义命令；无法识别返回 nil。
    static func parse(key: String, modifier: Modifier) -> Command? {
        switch modifier {
        case .command:
            switch key {
            case "l": return .focusAddressBar
            case "n": return .newTab
            case "w": return .closeTab
            case "f": return .findInPage
            case "0": return .selectTab(9) // 约定：最后一个标签
            case "1"..."9":
                return .selectTab((Int(key) ?? 1) - 1)
            default: return nil
            }
        case .commandShift:
            if key == "y" { return nil } // 保留给 AI 总结（命令栏入口），不在此表映射
            return nil
        case .commandControl:
            if key == "\t" { return .nextTab }
            return nil
        }
    }

    /// 路线图要求的快捷键表（防漏配）：每条都能解析成一个命令。
    static let roadmap: [(key: String, modifier: Modifier)] = [
        ("l", .command),       // ⌘L 聚焦地址栏
        ("n", .command),       // ⌘N 新建标签页
        ("w", .command),       // ⌘W 关闭当前标签
        ("f", .command),       // ⌘F 站内查找
        ("1", .command),
        ("2", .command),
        ("3", .command),
        ("4", .command),
        ("5", .command),
        ("6", .command),
        ("7", .command),
        ("8", .command),
        ("9", .command),
        ("0", .command),
        ("\t", .commandControl), // ⌃⌘Tab 下一个标签
    ]
}