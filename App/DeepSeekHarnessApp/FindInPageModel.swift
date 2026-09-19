import Foundation

/// 站内查找（find-in-page）的状态模型：纯 Foundation 深模块，无 AppKit/WebKit 依赖。
///
/// 对应需求缺口 G5（页面内站内搜索）：WKWebView 的 `find(_:completionHandler:)`
/// 会异步返回当前匹配索引与总数，本模型把这些零散状态收敛为稳定的状态机与
/// 回绕导航逻辑，UI 侧只需驱动 `setQuery` / `match` / `advance` 并读 `statusText`。
///
/// 这样把「查找逻辑」从 AppKit 胶水里剥离出来，可独立 `swiftc` 单测。
final class FindInPageModel {
    /// 当前查找词（已去除首尾空白）。
    private(set) var query: String = ""

    /// 匹配总数（由 WebKit 的 completion handler 回报）。
    private(set) var matchCount: Int = 0

    /// 当前命中的匹配索引（0-based；无匹配时为 0）。
    private(set) var currentIndex: Int = 0

    /// 是否有有效查询（非空词才驱动查找）。
    var isActive: Bool { !query.isEmpty }

    /// 归一化查询词：仅去首尾空白。
    func setQuery(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let changed = (trimmed != query)
        query = trimmed
        if changed {
            // 查询词一变，旧匹配结果作废。
            matchCount = 0
            currentIndex = 0
        }
    }

    /// 由 WebKit 回报匹配总数，并把当前索引钳制在合法范围内。
    func match(count: Int) {
        matchCount = max(0, count)
        currentIndex = clampIndex(currentIndex)
    }

    /// 手动指定当前命中索引（供 UI 在 WebKit 回调间同步用）。
    func setCurrentIndex(_ index: Int) {
        currentIndex = clampIndex(index)
    }

    /// 前进/后退一个匹配，越过边界时回绕。
    ///  - 返回新的当前索引；无匹配或只有 1 个匹配时返回 nil（无需移动）。
    func advance(forward: Bool) -> Int? {
        guard matchCount > 1 else { return nil }
        if forward {
            currentIndex = (clampIndex(currentIndex) + 1) % matchCount
        } else {
            currentIndex = (clampIndex(currentIndex) - 1 + matchCount) % matchCount
        }
        return currentIndex
    }

    /// 查找条状态文案："当前/总数"（如 "2/3"）；无匹配显示 "0/0"。
    var statusText: String {
        "\(clampIndex(currentIndex))/\(matchCount)"
    }

    private func clampIndex(_ index: Int) -> Int {
        guard matchCount > 0 else { return 0 }
        return min(max(0, index), matchCount - 1)
    }
}