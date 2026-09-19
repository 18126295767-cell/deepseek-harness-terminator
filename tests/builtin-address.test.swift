// 内置浏览器地址解析的独立单测（swiftc 编译运行；由 tests/package.test.mjs 的 node test 驱动）。
import Foundation

// 复用上层纯逻辑，避免复制实现：直接 include 源码文件（无 AppKit 依赖）。
// 编译命令：swiftc App/DeepSeekHarnessApp/BuiltinBrowserAddress.swift tests/builtin-address.test.swift -o tests/builtin-address-test
// 然后把同目录 main.swift 中的 BuiltinBrowserAddress 一并参与编译，保证与真机一致。

var failures = 0
var checks = 0

func expect(_ cond: Bool, _ label: String) {
    checks += 1
    if !cond {
        failures += 1
        print("FAIL: \(label)")
    }
}

func testResolve() throws {
    // 1) 完整 URL 原样
    expect(try XCTUnwrapURL(BuiltinBrowserAddress.resolve("https://www.apple.com")) == "https://www.apple.com", "完整 https URL")
    expect(try XCTUnwrapURL(BuiltinBrowserAddress.resolve("http://127.0.0.1:3080/")) == "http://127.0.0.1:3080/", "完整 http URL")

    // 2) 域名补 https
    expect(try XCTUnwrapURL(BuiltinBrowserAddress.resolve("apple.com")) == "https://apple.com", "域名补 https")

    // 3) 带端口/主机
    expect(try XCTUnwrapURL(BuiltinBrowserAddress.resolve("127.0.0.1:3080")) == "https://127.0.0.1:3080", "host:port")

    // 4) 搜索词 → 搜索引擎结果页
    expect(try XCTUnwrapURL(BuiltinBrowserAddress.resolve("macOS 内置浏览器")).hasPrefix("https://www.bing.com/search?q="), "搜索词走 bing")
    expect(try XCTUnwrapURL(BuiltinBrowserAddress.resolve("apple watch")).contains("%20"), "搜索词含空格需编码")

    // 5) 空白 → nil
    expect(BuiltinBrowserAddress.resolve("   ") == nil, "空白输入返回 nil")
    expect(BuiltinBrowserAddress.resolve("") == nil, "空输入返回 nil")
}

func testMainSwiftConsistency() throws {
    // 校验 main.swift 确实调用了 BuiltinBrowserAddress.resolve（防止忘了接线）。
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let main = try String(contentsOf: root.appendingPathComponent("App/DeepSeekHarnessApp/main.swift"), encoding: .utf8)
    expect(main.contains("BuiltinBrowserAddress.resolve"), "main.swift 使用 BuiltinBrowserAddress.resolve")
    expect(main.contains("输入网址或搜索词"), "地址栏 placeholder 提示可搜索")
}

// 小工具：把 URL? 转字符串，nil 抛错
func XCTUnwrapURL(_ url: URL?) throws -> String {
    guard let url else { throw NSError(domain: "test", code: 1) }
    return url.absoluteString
}

// swiftc 多文件编译时顶层变量/语句只能出现在名为 main.swift 的文件里；
// 这里用 @main 提供唯一入口，避免与产品源码冲突。
@main
struct BuiltinAddressTestMain {
    static func main() {
        do {
            try testResolve()
            try testMainSwiftConsistency()
            print("\n\(checks) checks, \(failures) failures")
            exit(failures == 0 ? 0 : 1)
        } catch {
            print("测试抛错: \(error)")
            exit(1)
        }
    }
}