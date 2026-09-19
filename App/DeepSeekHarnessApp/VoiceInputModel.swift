import Foundation

/// 语音输入的状态机与归一化（纯 Foundation 深模块，无 AppKit/Speech 依赖，可独立 swiftc 单测）。
///
/// 设计（对应 Alpha 架构 M3 的 VoiceInputModel 层）：
///  - 权限状态机：把 iOS/macOS `SFSpeechRecognizer` 的授权状态映射为用户可见的 UI 状态；
///  - 语言选择：把任意 ISO 语言标识归一化到受支持的语音 locale，不受支持回退默认；
///  - 转写归一化：修剪/折叠空行，空转写归一化为 nil（驱动 UI 的「无内容不提交」语义）。
enum VoiceInputModel {
    /// 用户可见的语音输入状态，驱动 UI（麦克风按钮 / 菜单项）的状态反馈。
    enum State: Equatable {
        /// 未在录音，可开始。
        case idle
        /// 正在录音/转写中。
        case listening
        /// 转写完成，等待注入输入框。
        case processing
        /// 权限/设备不可用，附带面向用户的说明（显示在 UI 状态反馈里）。
        case unavailable(String)
    }

    /// 语音识别权限状态（对应 `SFSpeechRecognizerAuthorizationStatus` 的语义子集）。
    enum Permission: Equatable {
        case undetermined
        case authorized
        case denied
        case restricted
    }

    /// 受支持的语音 locale；UI 用它做语言选择，转写器按此构造 `SFSpeechRecognizer`。
    static let supportedLocales = ["zh-CN", "en-US"]

    /// 默认回退语言。
    static let defaultLocale = "zh-CN"

    /// 把 ISO 语言标识（如系统 `Locale` 或用户配置）归一化到受支持的语音 locale。
    ///  - `zh*` → `zh-CN`；`en*` → `en-US`；其余/空/nil → 默认 `zh-CN`。大小写无关。
    static func normalizeLocale(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return defaultLocale }
        let lower = raw.lowercased()
        if lower.hasPrefix("zh") { return "zh-CN" }
        if lower.hasPrefix("en") { return "en-US" }
        return defaultLocale
    }

    /// 归一化转写文本：修剪每行并折叠空行，统一换行为 `\n`；空结果返回 nil。
    static func normalizedTranscript(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let unified = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = unified.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let joined = lines.joined(separator: "\n")
        let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 根据权限状态得出初始 UI 状态：授权/未询问 → idle；拒绝/受限 → 附说明的 unavailable。
    static func initialState(permission: Permission) -> State {
        switch permission {
        case .authorized, .undetermined:
            return .idle
        case .denied:
            return .unavailable("麦克风权限被拒绝")
        case .restricted:
            return .unavailable("语音识别受限")
        }
    }
}