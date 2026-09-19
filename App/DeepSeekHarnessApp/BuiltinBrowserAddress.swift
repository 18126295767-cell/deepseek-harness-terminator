import Foundation

/// 内置浏览器地址栏输入的解析器（纯 Foundation，可独立单测）。
///
/// 规则（对应“内置浏览器搜索”需求）：
///  - 明文 `http(s)://...` URL → 原样加载；
///  - 看起来是域名/主机（含 `.`，或 localhost / 127.0.0.1，或含端口 `:`）→ 补 `https://`；
///  - 其余一律视为搜索词 → URL 编码后拼到默认搜索引擎结果页，在面板内打开。
enum BuiltinBrowserAddress {
    /// 默认搜索引擎结果页模板，`%@` 替换为 URL 编码后的搜索词。
    static let searchEngineURLTemplate = "https://www.bing.com/search?q=%@"

    /// 把地址栏输入解析为要加载的 URL；空输入返回 nil。
    static func resolve(_ raw: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        let lower = s.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: s)
        }

        // 主机判断：无空格；含 '.' 视为域名，或含 ':' 视为带端口（如 127.0.0.1:3080），
        // 或 localhost / 携带 scheme 的本地地址。
        let looksLikeHost =
            !s.contains(" ")
            && (s.contains(".") || lower.contains("localhost")
                || s.contains(":") || lower.hasPrefix("file:"))
        if looksLikeHost {
            return URL(string: "https://" + s)
        }

        if let query = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: String(format: searchEngineURLTemplate, query))
        }
        return nil
    }
}