import Foundation

/// 截图 / 页面保存（G10）的纯 Foundation 深模块：无 AppKit/WebKit 依赖。
///
/// 负责保存动作的「语义」：根据标题/URL 生成合法文件名、按格式解析捕获类型、
/// 给出默认保存目录。WKWebView 的 `takeSnapshot` / `createPDF` 由薄 UI 层调用，
/// 本模块专注可单测的命名与格式决策。
enum PageCaptureModel {
    /// 支持的保存格式。
    enum Format {
        case png      // 当前视图截图
        case pdf      // 整页 PDF
        case html     // 页面 HTML 存档
        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .pdf: return "pdf"
            case .html: return "html"
            }
        }
    }

    /// 捕获类型：快照截图 / 整页 PDF。
    enum CaptureKind {
        case snapshot
        case fullPagePDF
    }

    /// 去掉文件名中的非法字符（macOS: 排除 / : 空白折叠等）。
    private static let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")

    /// 生成保存文件名：标题优先，空标题用主机名，并附加格式扩展名。
    static func fileName(title: String, url: URL, format: Format) -> String {
        let base = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (url.host ?? "page")
            : title
        var cleaned = base
            .components(separatedBy: illegal)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { cleaned = "page" }
        // 限制长度，避免过长的标题撑爆路径（约 80 字符）。
        let limit = 80
        if cleaned.count > limit { cleaned = String(cleaned.prefix(limit)) }
        return "\(cleaned).\(format.fileExtension)"
    }

    /// 按格式推导捕获类型。
    static func captureKind(format: Format) -> CaptureKind {
        switch format {
        case .png: return .snapshot
        case .pdf: return .fullPagePDF
        case .html: return .snapshot // HTML 由 WKWebView 页面自身提供，走快照降级
        }
    }

    /// 默认保存目录（用户下载目录）。
    static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    /// 生成不与现有文件冲突的文件名：若基础名已存在则追加 -1/-2/… 序号，防止重复保存覆盖。
    static func uniqueFileName(title: String, url: URL, format: Format,
                               fileManager: FileManager = .default,
                               directory: URL? = nil) -> String {
        let base = fileName(title: title, url: url, format: format)
        let dir = directory ?? defaultDirectory()
        var candidate = base
        var index = 1
        while fileManager.fileExists(atPath: dir.appendingPathComponent(candidate).path) {
            let stem = (base as NSString).deletingPathExtension
            let ext = (base as NSString).pathExtension
            candidate = "\(stem)-\(index).\(ext)"
            index += 1
        }
        return candidate
    }
}