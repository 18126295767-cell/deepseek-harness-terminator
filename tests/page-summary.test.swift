// AI 总结当前页 → 本地 DSH 的纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/PageSummaryModel.swift tests/page-summary.test.swift -o tests/page-summary-test

var failures = 0
var checks = 0

func expect(_ cond: Bool, _ label: String) {
    checks += 1
    if !cond {
        failures += 1
        print("FAIL: \(label)")
    }
}

func expectEqual(_ got: String, _ want: String, _ label: String) {
    checks += 1
    if got != want {
        failures += 1
        print("FAIL: \(label) — got: \(got), want: \(want)")
    }
}

// MARK: - 触发条件

func testMissingURLIsNotEligible() {
    let state = PageSummaryModel.evaluate(title: "无网址", currentURL: nil, pageSnippet: "正文", language: "zh-Hans")
    expect(state.canSummarize == false, "无当前页 URL 时不可总结")
}

func testValidPageIsEligible() {
    let url = URL(string: "https://www.apple.com/newsroom/")
    let state = PageSummaryModel.evaluate(title: "Apple Newsroom", currentURL: url, pageSnippet: "正文片段", language: "zh-Hans")
    expect(state.canSummarize == true, "有 URL 即可总结")
}

// MARK: - 提示词构建

func testPromptContainsKeyParts() {
    let url = URL(string: "https://www.apple.com/newsroom/2025/product/")
    let prompt = PageSummaryModel.buildPrompt(
        title: "Apple Newsroom",
        currentURL: url,
        pageSnippet: "这是一段用于测试的页面正文。",
        language: "zh-Hans"
    )
    expect(prompt.contains("Apple Newsroom"), "提示词含页面标题")
    expect(prompt.contains("https://www.apple.com/newsroom/2025/product/"), "提示词含页面 URL")
    expect(prompt.contains("这是一段用于测试的页面正文。"), "提示词含页面正文片段")
}

func testPromptRequestsChinese() {
    let url = URL(string: "https://example.com")
    let prompt = PageSummaryModel.buildPrompt(title: "T", currentURL: url, pageSnippet: "", language: "zh-Hans")
    expect(prompt.contains("中文"), "中文环境提示词要求中文总结")
}

func testPromptRequestsEnglish() {
    let url = URL(string: "https://example.com")
    let prompt = PageSummaryModel.buildPrompt(title: "T", currentURL: url, pageSnippet: "", language: "en")
    expect(prompt.contains("English"), "英文环境提示词要求英文总结")
}

// MARK: - 拷贝串

func testClipboardStringCombinesPromptAndURL() {
    let url = URL(string: "https://example.com/a")
    let copy = PageSummaryModel.clipboardString(
        title: "示例",
        currentURL: url,
        pageSnippet: "正文",
        language: "zh-Hans"
    )
    expect(copy.contains("示例"), "拷贝串含标题")
    expect(copy.contains("https://example.com/a"), "拷贝串含 URL")
    expect(copy.contains("正文"), "拷贝串含正文")
}

// MARK: - 运行

@main
struct PageSummaryTestMain {
    static func main() {
        testMissingURLIsNotEligible()
        testValidPageIsEligible()
        testPromptContainsKeyParts()
        testPromptRequestsChinese()
        testPromptRequestsEnglish()
        testClipboardStringCombinesPromptAndURL()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}