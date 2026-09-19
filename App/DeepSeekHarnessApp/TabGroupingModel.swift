import Foundation

/// 垂直标签分组（G4）的纯 Foundation 深模块：无 AppKit 依赖。
///
/// 把一组标签（仅需 `title` + `id`）按任意「分组键」（由调用方注入，
/// 例如按可注册域名、按标题首字母、按用户手动命名）聚成有序组。
/// 这样垂直标签侧栏的「分组」逻辑可独立 `swiftc` 单测，UI 只负责渲染。
struct TabGroupable: Equatable {
    let title: String
    let id: String
}

/// 一组标签的聚合结果。
struct TabGroup: Equatable {
    let name: String
    var tabs: [TabGroupable]

    /// 展示摘要，如“Apple（2）”。
    var summary: String { "\(name)（\(tabs.count)）" }
}

/// 按分组键聚合并保持首次出现顺序。
struct TabGroupingModel {
    /// 从单个标签导出分组键的函数（可注入，便于按域名/首字母/命名分组测试）。
    let groupingKey: (TabGroupable) -> String

    /// 分组：保持首次出现的组名顺序；同组标签按出现先后排列。
    func group(_ tabs: [TabGroupable]) -> [TabGroup] {
        var order: [String] = []
        var map: [String: [TabGroupable]] = [:]
        for tab in tabs {
            let key = groupingKey(tab)
            if map[key] == nil {
                order.append(key)
                map[key] = []
            }
            map[key]?.append(tab)
        }
        return order.map { TabGroup(name: $0, tabs: map[$0] ?? []) }
    }
}