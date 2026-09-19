// 语音输入纯逻辑（VoiceInputModel）的独立单测（swiftc 编译运行；由 tests/package.test.mjs 的 node test 驱动）。
// 与 BuiltinBrowserAddress 同一测试形态：纯 Foundation，无 AppKit/Speech 依赖，可在 CI 无麦克风环境运行。
import Foundation

// 复用上层纯逻辑：直接 include 源码文件（无系统权限依赖）。
// 编译命令：swiftc App/DeepSeekHarnessApp/VoiceInputModel.swift tests/voice-input.test.swift -o tests/voice-input-test

var failures = 0
var checks = 0

func expect(_ cond: Bool, _ label: String) {
    checks += 1
    if !cond {
        failures += 1
        print("FAIL: \(label)")
    }
}

func expectEqual<T: Equatable>(_ got: T, _ want: T, _ label: String) {
    checks += 1
    if got != want {
        failures += 1
        print("FAIL: \(label) — got \(got), want \(want)")
    }
}

func testNormalizeLocale() {
    // 支持的语言原样保留
    expectEqual(VoiceInputModel.normalizeLocale("zh-CN"), "zh-CN", "zh-CN 保留")
    expectEqual(VoiceInputModel.normalizeLocale("en-US"), "en-US", "en-US 保留")
    // 地区变体映射到主语言
    expectEqual(VoiceInputModel.normalizeLocale("zh-Hans"), "zh-CN", "zh 变体映射 zh-CN")
    expectEqual(VoiceInputModel.normalizeLocale("zh-Hant"), "zh-CN", "繁体 zh 仍映射 zh-CN")
    expectEqual(VoiceInputModel.normalizeLocale("en-GB"), "en-US", "en 变体映射 en-US")
    // 不受支持 / 空 → 默认回退
    expectEqual(VoiceInputModel.normalizeLocale("fr-FR"), "zh-CN", "不受支持回退默认")
    expectEqual(VoiceInputModel.normalizeLocale(""), "zh-CN", "空串回退默认")
    expectEqual(VoiceInputModel.normalizeLocale(nil), "zh-CN", "nil 回退默认")
    // 大小写无关
    expectEqual(VoiceInputModel.normalizeLocale("zh-cn"), "zh-CN", "小写变体仍映射")
}

func testNormalizedTranscript() {
    // 空/纯空白 → nil
    expect(VoiceInputModel.normalizedTranscript(nil) == nil, "nil 转写 → nil")
    expect(VoiceInputModel.normalizedTranscript("") == nil, "空转写 → nil")
    expect(VoiceInputModel.normalizedTranscript("   \n\t ") == nil, "纯空白转写 → nil")
    // 首尾空白修剪
    expectEqual(VoiceInputModel.normalizedTranscript("  你好世界  "), "你好世界", "修剪首尾空白")
    // 多行折叠空行 + 每行修剪
    expectEqual(VoiceInputModel.normalizedTranscript("  你好  \n\n  世界  "), "你好\n世界", "多行折叠空行")
    // CRLF / CR 归一化
    expectEqual(VoiceInputModel.normalizedTranscript("你好\r\n世界"), "你好\n世界", "CRLF 归一化为 LF")
}

func testInitialState() {
    expectEqual(VoiceInputModel.initialState(permission: .authorized), .idle, "授权 → idle")
    expectEqual(VoiceInputModel.initialState(permission: .undetermined), .idle, "未询问 → idle")
    expectEqual(VoiceInputModel.initialState(permission: .denied), .unavailable("麦克风权限被拒绝"), "拒绝 → unavailable")
    expectEqual(VoiceInputModel.initialState(permission: .restricted), .unavailable("语音识别受限"), "受限 → unavailable")

    // State 必须可判等（UI 据此驱动按钮状态）
    expectEqual(VoiceInputModel.State.idle, VoiceInputModel.State.idle, "State 判等 idle==idle")
    expect(VoiceInputModel.State.idle != VoiceInputModel.State.listening, "State 判等 idle!=listening")
}

func testSupportedLocales() {
    expect(VoiceInputModel.supportedLocales.contains("zh-CN"), "支持 zh-CN")
    expect(VoiceInputModel.supportedLocales.contains("en-US"), "支持 en-US")
    expectEqual(VoiceInputModel.supportedLocales.count, 2, "恰好两个受支持语言")
}

func testMainSwiftVoiceEntryExists() {
    // 校验 main.swift 确实暴露了语音输入入口（防止忘了接线到 UI）。
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let main = try! String(contentsOf: root.appendingPathComponent("App/DeepSeekHarnessApp/main.swift"), encoding: .utf8)
    expect(main.contains("VoiceController"), "main.swift 接线 VoiceController")
    expect(main.contains("语音输入"), "UI 暴露语音输入入口")
}

@main
struct VoiceInputTestMain {
    static func main() {
        testNormalizeLocale()
        testNormalizedTranscript()
        testInitialState()
        testSupportedLocales()
        testMainSwiftVoiceEntryExists()
        print("\n\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}