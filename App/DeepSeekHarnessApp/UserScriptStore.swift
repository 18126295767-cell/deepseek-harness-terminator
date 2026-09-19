import Foundation

/// 用户脚本 / 站点定制（G12）的纯 Foundation 深模块：无 AppKit/WebKit 依赖。
///
/// 管理用户注入脚本的增删改查、启用/禁用，以及按 URL 通配模式匹配「该对哪些页面
/// 注入哪些脚本」。脚本源与元数据经注入的 `KeyValueStorage` 持久化（纯本地）。
/// UI 侧把这些匹配到的脚本转成 `WKUserScript` 挂到 WKWebView。
struct UserScript: Equatable {
    let id: String
    var name: String
    /// JavaScript 源码。
    var source: String
    /// URL 匹配通配模式，如 `*://*.apple.com/*`。
    var urlPattern: String
    var isActive: Bool
}

final class UserScriptStore {
    private let storage: KeyValueStorage
    private static let key = "browser.userscripts.v1"
    private var scripts: [UserScript]

    init(storage: KeyValueStorage) {
        self.storage = storage
        if let json = storage.string(forKey: Self.key),
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([UserScriptDTO].self, from: data) {
            self.scripts = decoded.map { UserScript(id: $0.id, name: $0.name, source: $0.source, urlPattern: $0.urlPattern, isActive: $0.isActive) }
        } else {
            self.scripts = []
        }
    }

    private struct UserScriptDTO: Codable {
        var id: String
        var name: String
        var source: String
        var urlPattern: String
        var isActive: Bool
    }

    private func persist() {
        let dtos = scripts.map { UserScriptDTO(id: $0.id, name: $0.name, source: $0.source, urlPattern: $0.urlPattern, isActive: $0.isActive) }
        guard let data = try? JSONEncoder().encode(dtos),
              let json = String(data: data, encoding: .utf8) else { return }
        storage.set(json, forKey: Self.key)
    }

    /// 新增或按 id 更新脚本。
    func upsert(id: String, name: String, source: String, urlPattern: String, isActive: Bool) {
        if let idx = scripts.firstIndex(where: { $0.id == id }) {
            scripts[idx] = UserScript(id: id, name: name, source: source, urlPattern: urlPattern, isActive: isActive)
        } else {
            scripts.append(UserScript(id: id, name: name, source: source, urlPattern: urlPattern, isActive: isActive))
        }
        persist()
    }

    /// 启用/禁用。
    func setActive(id: String, active: Bool) {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[idx].isActive = active
        persist()
    }

    /// 删除脚本。
    func remove(id: String) {
        scripts.removeAll { $0.id == id }
        persist()
    }

    /// 全部脚本。
    func all() -> [UserScript] { scripts }

    /// 匹配某 URL 应注入的已启用脚本（通配模式子串/星号匹配）。
    func activeScripts(for url: URL) -> [UserScript] {
        scripts.filter { $0.isActive && matches(url.absoluteString, pattern: $0.urlPattern) }
    }

    /// 简单通配匹配：`*` 匹配任意子串；不写星号则子串匹配。
    private func matches(_ value: String, pattern: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.contains("*") {
            // 把 * 转成 .* 做正则匹配。
            let escaped = pattern.split(separator: "*", omittingEmptySubsequences: false).map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: ".*")
            guard let regex = try? NSRegularExpression(pattern: "^\(escaped)$") else { return false }
            let range = NSRange(value.startIndex..., in: value)
            return regex.firstMatch(in: value, options: [], range: range) != nil
        }
        return value.contains(pattern)
    }
}