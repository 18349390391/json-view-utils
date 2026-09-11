import SwiftUI
import AppKit

// MARK: - 树扁平化：渲染效果等同格式化后的 JSON 文本（含行号与闭合行）

struct FlatRow: Identifiable {
    enum Kind {
        case containerOpen       // 展开的容器起始行：{
        case containerCollapsed  // 折叠的容器行：{ … }
        case scalar              // 标量行："key": value
        case close               // 容器闭合行：},
    }

    let id: String
    let node: JSONNode
    let depth: Int
    let kind: Kind
    let trailingComma: Bool
    var line: Int
}

func flattenTree(_ root: JSONNode, collapsed: Set<UUID>) -> [FlatRow] {
    var rows: [FlatRow] = []

    func walk(_ node: JSONNode, _ depth: Int, _ comma: Bool) {
        if node.isContainer {
            if collapsed.contains(node.id) {
                rows.append(FlatRow(id: node.id.uuidString, node: node, depth: depth,
                                    kind: .containerCollapsed, trailingComma: comma, line: 0))
            } else {
                rows.append(FlatRow(id: node.id.uuidString, node: node, depth: depth,
                                    kind: .containerOpen, trailingComma: false, line: 0))
                for (i, c) in node.children.enumerated() {
                    walk(c, depth + 1, i < node.children.count - 1)
                }
                rows.append(FlatRow(id: "close-" + node.id.uuidString, node: node, depth: depth,
                                    kind: .close, trailingComma: comma, line: 0))
            }
        } else {
            rows.append(FlatRow(id: node.id.uuidString, node: node, depth: depth,
                                kind: .scalar, trailingComma: comma, line: 0))
        }
    }

    walk(root, 0, false)
    for i in rows.indices { rows[i].line = i + 1 }
    return rows
}

// MARK: - 单行视图（只读：点击查看选中，⌘C 复制，右键复制菜单）

struct TreeRowView: View {
    @EnvironmentObject private var vm: EditorViewModel
    let row: FlatRow
    let palette: ThemePalette
    let lineNumberWidth: CGFloat

    @State private var hovering = false

    private var node: JSONNode { row.node }
    private var isSelected: Bool { vm.selectedNodeID == node.id }

    private var query: String {
        vm.searchText.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var isCurrentMatch: Bool {
        vm.matches.indices.contains(vm.currentMatch) && vm.matches[vm.currentMatch] == node.id
    }

    private var keyMatched: Bool {
        !query.isEmpty && (node.key?.lowercased().contains(query) ?? false)
    }

    private var valueMatched: Bool {
        guard !query.isEmpty else { return false }
        switch node.kind {
        case .string, .number: return node.text.lowercased().contains(query)
        case .bool: return (node.boolValue ? "true" : "false").contains(query)
        case .null: return "null".contains(query)
        default: return false
        }
    }

    private func matchPill(_ matched: Bool) -> Color {
        guard matched else { return .clear }
        return isCurrentMatch ? palette.currentMatch : palette.match
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("\(row.line)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(palette.secondaryText.opacity(0.55))
                .frame(width: lineNumberWidth, alignment: .trailing)
                .padding(.trailing, 4)
                .allowsHitTesting(false)

            disclosureArea
            content
                .padding(.leading, CGFloat(row.depth) * 16)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2.5)
        .padding(.trailing, 10)
        .background(hovering && !isSelected ? palette.panel.opacity(0.55) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.12)) {
                vm.selectedNodeID = node.id
            }
        }
        .id(row.id)
        .contextMenu { contextMenu }
    }

    @ViewBuilder
    private var disclosureArea: some View {
        if node.isContainer && row.kind != .close {
            Button { vm.toggleCollapsed(node.id) } label: {
                Image(systemName: row.kind == .containerOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 26, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(tr(.collapseExpandHelp))
        } else {
            Spacer().frame(width: 26, height: 22)
        }
    }

    /// 内容区：选中时整体药丸高亮
    @ViewBuilder
    private var content: some View {
        let inner = HStack(spacing: 0) {
            switch row.kind {
            case .close:
                Text(node.kind == .object ? "}" : "]")
                    .foregroundStyle(palette.text)
                comma
            case .containerOpen:
                keyPart
                Text(node.kind == .object ? "{" : "[")
                    .foregroundStyle(palette.text)
                    .background(matchPill(keyMatched && node.key == nil), in: RoundedRectangle(cornerRadius: 3))
            case .containerCollapsed:
                keyPart
                Text(node.kind == .object ? "{ … }" : "[ … ]")
                    .foregroundStyle(palette.secondaryText)
                comma
            case .scalar:
                keyPart
                scalarValue
                comma
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(
            isSelected ? palette.accent.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: 5)
        )

        if row.kind == .containerCollapsed {
            inner.onTapGesture {
                withAnimation(.easeOut(duration: 0.12)) {
                    vm.selectedNodeID = node.id
                }
                vm.toggleCollapsed(node.id)
            }
        } else {
            inner
        }
    }

    @ViewBuilder
    private var keyPart: some View {
        if let key = node.key {
            Text("\"\(key)\"")
                .foregroundStyle(palette.key)
                .background(matchPill(keyMatched), in: RoundedRectangle(cornerRadius: 3))
            Text(":")
                .foregroundStyle(palette.secondaryText)
                .padding(.trailing, 8)
        }
    }

    @ViewBuilder
    private var scalarValue: some View {
        let pill = matchPill(valueMatched)
        switch node.kind {
        case .string:
            Text("\"\(node.text)\"")
                .foregroundStyle(palette.string)
                .background(pill, in: RoundedRectangle(cornerRadius: 3))
        case .number:
            Text(node.text)
                .foregroundStyle(palette.number)
                .background(pill, in: RoundedRectangle(cornerRadius: 3))
        case .bool:
            Text(node.boolValue ? "true" : "false")
                .foregroundStyle(palette.bool)
                .background(pill, in: RoundedRectangle(cornerRadius: 3))
        case .null:
            Text("null")
                .foregroundStyle(palette.nullColor)
                .background(pill, in: RoundedRectangle(cornerRadius: 3))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var comma: some View {
        if row.trailingComma {
            Text(",")
                .foregroundStyle(palette.secondaryText)
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if node.key != nil {
            Button(tr(.copyKeyOnly)) { vm.copyKey(node.id) }
            Button(tr(.copyValueOnly)) { vm.copyValue(node.id) }
            Button(tr(.copyPair)) { vm.copyPair(node.id) }
        } else {
            Button(tr(.copyJSONFragment)) { vm.copyJSON(node.id) }
        }
        Button(tr(.copyPath)) { vm.copyPath(node.id) }
        if node.isContainer {
            Divider()
            Button(row.kind == .containerOpen ? tr(.collapse) : tr(.expand)) {
                vm.toggleCollapsed(node.id)
            }
        }
    }
}

// MARK: - 树视图

struct TreeView: View {
    @EnvironmentObject private var vm: EditorViewModel
    let palette: ThemePalette

    @FocusState private var treeFocused: Bool

    private var rows: [FlatRow] {
        guard let root = vm.root else { return [] }
        return flattenTree(root, collapsed: vm.collapsed)
    }

    private var lineNumberWidth: CGFloat {
        CGFloat(String(rows.count).count) * 8 + 18
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        TreeRowView(row: row, palette: palette, lineNumberWidth: lineNumberWidth)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.background)
            .focusable()
            .focused($treeFocused)
            .onCopyCommand {
                guard let text = vm.selectedCopyText() else { return [] }
                return [NSItemProvider(object: text as NSString)]
            }
            .onChange(of: vm.selectedNodeID) { _ in
                if vm.selectedNodeID != nil { treeFocused = true }
            }
            .onChange(of: vm.currentMatch) { _ in scrollToMatch(proxy) }
            .onChange(of: vm.matches) { _ in scrollToMatch(proxy) }
        }
    }

    private func scrollToMatch(_ proxy: ScrollViewProxy) {
        guard !vm.matches.isEmpty, vm.matches.indices.contains(vm.currentMatch) else { return }
        withAnimation {
            proxy.scrollTo(vm.matches[vm.currentMatch].uuidString, anchor: .center)
        }
    }
}
