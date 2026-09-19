// 截图 / 页面保存（G10）纯逻辑单测（swiftc 编译运行）。
// 纯 Foundation，无 AppKit/WebKit 依赖。
import Foundation

// 编译命令：swiftc App/DeepSeekHarnessApp/PageCaptureModel.swift tests/page-capture.test.swift -o tests/page-capture-test

var failures = 0
var checks = 0

func expect(_ cond: Bool, _ label: String) {
    checks += 1
    if !cond {
        failures += 1
        print("FAIL: \(label)")
    }
}

func expectEqual<T: Equatable>(_ got: T?, _ want: T?, _ label: String) {
    checks += 1
    if got != want {
        failures += 1
        print("FAIL: \(label) — got \(String(describing: got)), want \(String(describing: want))")
    }
}

// MARK: - 文件名生成

func testFileNameFromTitle() {
    let name = PageCaptureModel.fileName(title: "Apple Newsroom", url: URL(string: "https://www.apple.com/newsroom/")!, format: .png)
    expect(name.hasSuffix(".png"), "PNG 文件名带扩展名")
    expect(name.contains("Apple Newsroom"), "文件名包含标题")
}

func testFileNameSanitizesIllegalChars() {
    let name = PageCaptureModel.fileName(title: "A/B:C*D?E<F>G|H 页", url: URL(string: "https://example.com")!, format: .pdf)
    for ch in ["/", ":", "*", "?", "<", ">", "|"] {
        expect(!name.contains(ch), "文件名不含非法字符 \(ch)")
    }
}

func testFileNameUsesHostWhenTitleEmpty() {
    let name = PageCaptureModel.fileName(title: "", url: URL(string: "https://www.example.com/x")!, format: .html)
    expect(name.contains("example"), "标题为空时用主机名")
    expect(name.hasSuffix(".html"), "HTML 格式扩展名正确")
}

// MARK: - 格式选择

func testCaptureKindByFormat() {
    expectEqual(PageCaptureModel.captureKind(format: .png), .snapshot, "PNG → 快照截图")
    expectEqual(PageCaptureModel.captureKind(format: .pdf), .fullPagePDF, "PDF → 整页 PDF")
}

// MARK: - 保存目录

func testDefaultDirectoryIsDownloads() {
    let dir = PageCaptureModel.defaultDirectory()
    expect(dir.lastPathComponent == "Downloads", "默认目录为下载目录")
}

// MARK: - 文件名唯一化（防止重复保存覆盖）

func testUniqueFileNameAvoidsOverwrite() {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("pcap-\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }

    let title = "Apple"
    let url = URL(string: "https://www.apple.com")!

    let first = PageCaptureModel.uniqueFileName(title: title, url: url, format: .png, fileManager: fm, directory: dir)
    expectEqual(first, "Apple.png", "无冲突时用基础名")
    // 模拟第一次已保存。
    try? Data("x".utf8).write(to: dir.appendingPathComponent(first))

    let second = PageCaptureModel.uniqueFileName(title: title, url: url, format: .png, fileManager: fm, directory: dir)
    expect(second.hasPrefix("Apple-1.png"), "冲突时追加序号：\(second)")

    // 再模拟第二次已保存 → 得到 -2。
    try? Data("x".utf8).write(to: dir.appendingPathComponent(second))
    let third = PageCaptureModel.uniqueFileName(title: title, url: url, format: .png, fileManager: fm, directory: dir)
    expect(third.hasPrefix("Apple-2.png"), "再冲突再递增：\(third)")
}

// MARK: - 运行

@main
struct PageCaptureTestMain {
    static func main() {
        testFileNameFromTitle()
        testFileNameSanitizesIllegalChars()
        testFileNameUsesHostWhenTitleEmpty()
        testCaptureKindByFormat()
        testDefaultDirectoryIsDownloads()
        testUniqueFileNameAvoidsOverwrite()

        print("\(checks) checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}