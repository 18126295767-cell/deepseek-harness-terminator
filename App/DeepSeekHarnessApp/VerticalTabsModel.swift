import Foundation

/// 垂直多标签栏 / 工作区折叠（G11，Floorp 式）的纯 Foundation 深模块。
///
/// 在 G4 的「按站点分组」基础上提供更完整的标签管理语义：可注入分组键（域名/
/// 主题）、组折叠/展开状态、以及组内拖拽重排。UI 侧据此渲染垂直侧栏；折叠与
/// 排序等状态决策全部在此处可单测。
struct VTab: Equatable {
    let title: String
    let id: String
}

struct VGroup: Equatable {
    let name: String
    var tabs: [VTab]
}

final class VerticalTabsModel {
    /// 从标签导出的分组键（可注入：域名 / 主题 / 首字母）。
    private let groupingKey: (VTab) -> String

    /// 分组列表（保持首次出现顺序）。
    private(set) var groups: [VGroup] = []
    /// 折叠的组名集合。
    private(set) var collapsed: Set<String> = []

    private(set) var order: [String] = []

    init(groupingKey: @escaping (VTab) -> String) {
        self.groupingKey = groupingKey
    }

    /// 按分组键把标签聚成组；同名组聚合、组名按首次出现排序；保留已有折叠状态。
    func group(tabs: [VTab]) {
        var newGroups: [VGroup] = []
        var map: [String: [VTab]] = [:]
        var seen: [String] = []
        for tab in tabs {
            let key = groupingKey(tab)
            if map[key] == nil {
                seen.append(key)
                map[key] = []
            }
            map[key]?.append(tab)
        }
        newGroups = seen.map { VGroup(name: $0, tabs: map[$0] ?? []) }

        // 保留此前折叠状态（若组名仍存在）。
        collapsed = collapsed.intersection(Set(seen))
        groups = newGroups
        order = seen
    }

    /// 某组是否折叠。
    func isCollapsed(group name: String) -> Bool {
        collapsed.contains(name)
    }

    /// 切换组折叠。
    func toggleCollapse(_ name: String) {
        if collapsed.contains(name) {
            collapsed.remove(name)
        } else {
            collapsed.insert(name)
        }
    }

    /// 展开状态下可见的标签（折叠组被排除），按组顺序 + 组内顺序。
    func visibleTabs() -> [VTab] {
        groups.flatMap { group -> [VTab] in
            collapsed.contains(group.name) ? [] : group.tabs
        }
    }

    /// 在组内重排：把某标签移到组内指定索引。
    func move(tabID: String, toIndexWithinGroup index: Int) {
        guard let gi = groups.firstIndex(where: { $0.tabs.contains { $0.id == tabID } }) else { return }
        var group = groups[gi]
        guard let from = group.tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = group.tabs.remove(at: from)
        let target = min(max(0, index), group.tabs.count)
        group.tabs.insert(tab, at: target)
        groups[gi] = group
    }
}