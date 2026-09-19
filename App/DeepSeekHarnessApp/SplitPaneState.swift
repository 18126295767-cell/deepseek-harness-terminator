import Foundation

/// 分屏（split view，G6）的纯 Foundation 深模块：无 AppKit/WebKit 依赖。
///
/// 只记录分屏状态的语义：是否激活、副屏当前 URL、以及「镜像跟随」是否把
/// 主屏导航同步到副屏。UI 侧据此创建/复用第二个 WKWebView 并布局，状态机
/// 逻辑不沾视图层，可独立 `swiftc` 单测。
struct SplitPaneState {
    private(set) var isActive = false
    private(set) var secondaryURL: URL?
    /// 是否镜像跟随主屏导航（默认开启，副屏作为联动参考窗）。
    var mirrorsPrimary = true

    /// 打开副屏并载入指定 URL。
    mutating func open(url: URL) {
        isActive = true
        secondaryURL = url
    }

    /// 关闭分屏并清空副屏状态。
    mutating func close() {
        isActive = false
        secondaryURL = nil
    }

    /// 主屏导航变化时，若处于镜像模式则同步副屏。
    mutating func followPrimary(url: URL) {
        guard isActive, mirrorsPrimary else { return }
        secondaryURL = url
    }
}