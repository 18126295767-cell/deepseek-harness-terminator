import Foundation

/// AI 总结当前页 → 本地 DSH 的纯逻辑深模块：纯 Foundation，无 AppKit/WebKit 依赖。
///
/// 对应需求缺口 G3（AI 总结当前页）：把「当前页 URL + 标题 + 正文片段」收敛成
/// 一条可直接交给本地 DeepSeek Harness 的总结提示词与拷贝串。它不发起网络请求，
/// 只负责「能否总结」的判断与提示词构建，UI 胶水再决定如何送进本地 DSH。
struct PageSummaryModel {
    /// 某次评估结果：是否可总结 + 提示词 + 拷贝串。
    struct Evaluation: Equatable {
        let canSummarize: Bool
        let prompt: String
        let clipboard: String
    }

    private static let languageName: [String: String] = [
        "zh-Hans": "简体中文",
        "zh-Hant": "繁体中文",
        "en": "English",
        "ja": "日本語",
    ]

    /// 评估当前页是否可总结，并同时产出提示词与拷贝串。
    static func evaluate(title: String?, currentURL: URL?, pageSnippet: String?, language: String) -> Evaluation {
        guard let url = currentURL, url.scheme != nil else {
            return Evaluation(canSummarize: false, prompt: "", clipboard: "")
        }
        let prompt = buildPrompt(
            title: title,
            currentURL: url,
            pageSnippet: pageSnippet,
            language: language
        )
        return Evaluation(
            canSummarize: true,
            prompt: prompt,
            clipboard: clipboardString(title: title, currentURL: url, pageSnippet: pageSnippet, language: language)
        )
    }

    /// 构建总结提示词：页头（标题+URL）+ 正文片段 + 语言要求。
    static func buildPrompt(title: String?, currentURL: URL?, pageSnippet: String?, language: String) -> String {
        let langLabel = languageName[language] ?? ("语言：" + language)
        var parts: [String] = []
        parts.append("请总结以下网页内容，输出要点式摘要。")
        if let title, !title.isEmpty {
            parts.append("标题：\(title)")
        }
        if let url = currentURL {
            parts.append("URL：\(url.absoluteString)")
        }
        if let snippet = pageSnippet, !snippet.isEmpty {
            parts.append("正文：\(snippet)")
        }
        parts.append("请用 \(langLabel) 回答，控制在 300 字以内，分条列出要点。")
        return parts.joined(separator: "\n")
    }

    /// 生成可直接复制粘贴到本地 DSH 聊天框的完整串（含 URL）。方便用户一键带走。
    static func clipboardString(title: String?, currentURL: URL?, pageSnippet: String?, language: String) -> String {
        let prompt = buildPrompt(title: title, currentURL: currentURL, pageSnippet: pageSnippet, language: language)
        if let url = currentURL {
            return "\(prompt)\n（原网页：\(url.absoluteString)）"
        }
        return prompt
    }
}