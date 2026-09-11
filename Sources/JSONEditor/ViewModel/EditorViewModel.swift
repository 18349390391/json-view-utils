import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable, Identifiable {
    case tree, raw, split
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tree: return tr(.tree)
        case .raw: return tr(.raw)
        case .split: return tr(.split)
        }
    }
}

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var root: JSONNode?
    @Published var rawText: String = ""
    @Published var parseError: JSONParseError?
    @Published var mode: ViewMode = .tree
    @Published var collapsed: Set<UUID> = []
    @Published var fileURL: URL?
    @Published var statusMessage: String?
    @Published var canUndo = false
    @Published var canRedo = false
    @Published private(set) var matches: [UUID] = []
    @Published private(set) var matchSet: Set<UUID> = []
    @Published var currentMatch: Int = 0
    @Published var selectedNodeID: UUID?
    @Published var themeID: String = UserDefaults.standard.string(forKey: "themeID") ?? AppTheme.system.rawValue {
        didSet { UserDefaults.standard.set(themeID, forKey: "themeID") }
    }
    @Published var language: String = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.system.rawValue {
        didSet {
            UserDefaults.standard.set(language, forKey: "language")
            // 系统对话框（打开/保存面板、主菜单标准项）跟随 AppleLanguages，重启后生效
            let lang = AppLanguage(rawValue: language) ?? .system
            if lang == .system {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
            }
            setStatus(tr(.languageRestartHint))
        }
    }
    @Published var searchText: String = "" { didSet { recomputeMatches() } }

    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private var lastEditWasRaw = false
    private var debounceTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    var nodeCount: Int { root.map { countNodes($0) } ?? 0 }
    var treeDepth: Int { root.map { maxDepth($0) } ?? 0 }

    // MARK: 撤销 / 重做

    private func pushUndo() {
        undoStack.append(rawText)
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
        canUndo = true
        canRedo = false
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(rawText)
        rawText = prev
        lastEditWasRaw = false
        parseRaw()
        canUndo = !undoStack.isEmpty
        canRedo = true
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(rawText)
        rawText = next
        lastEditWasRaw = false
        parseRaw()
        canUndo = true
        canRedo = !redoStack.isEmpty
    }

    // MARK: 原文解析

    func parseRaw() {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            root = nil
            parseError = nil
            selectedNodeID = nil
            recomputeMatches()
            return
        }
        do {
            var parser = JSONParser()
            root = try parser.parse(rawText)
            parseError = nil
        } catch let e as JSONParseError {
            parseError = e
        } catch {
            parseError = JSONParseError(message: "Parse failed", line: 1, column: 1, offset: 0)
        }
        selectedNodeID = nil
        recomputeMatches()
    }

    /// 原文编辑器输入（带撤销合并与解析防抖）
    func userEditedRaw(_ text: String) {
        if !lastEditWasRaw { pushUndo() }
        lastEditWasRaw = true
        rawText = text
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.parseRaw()
        }
    }

    // MARK: 折叠

    func toggleCollapsed(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
        }
    }

    func expandAll() {
        withAnimation(.easeInOut(duration: 0.2)) { collapsed.removeAll() }
    }

    func collapseAll() {
        guard let root else { return }
        var ids = Set<UUID>()
        collectContainers(root, &ids)
        ids.remove(root.id)
        withAnimation(.easeInOut(duration: 0.2)) { collapsed = ids }
    }

    private func collectContainers(_ node: JSONNode, _ out: inout Set<UUID>) {
        if node.isContainer { out.insert(node.id) }
        for c in node.children { collectContainers(c, &out) }
    }

    // MARK: 搜索

    private func recomputeMatches() {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty, let root else {
            matches = []; matchSet = []; currentMatch = 0
            return
        }
        var result: [UUID] = []
        collectMatches(root, q, &result)
        matches = result
        matchSet = Set(result)
        currentMatch = result.isEmpty ? 0 : min(currentMatch, result.count - 1)
    }

    private func collectMatches(_ node: JSONNode, _ q: String, _ out: inout [UUID]) {
        var hit = false
        if let k = node.key?.lowercased(), k.contains(q) { hit = true }
        switch node.kind {
        case .string, .number:
            if node.text.lowercased().contains(q) { hit = true }
        case .bool:
            if (node.boolValue ? "true" : "false").contains(q) { hit = true }
        case .null:
            if "null".contains(q) { hit = true }
        default: break
        }
        if hit { out.append(node.id) }
        for c in node.children { collectMatches(c, q, &out) }
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        currentMatch = (currentMatch + 1) % matches.count
        expandAncestors(of: matches[currentMatch])
    }

    func prevMatch() {
        guard !matches.isEmpty else { return }
        currentMatch = (currentMatch - 1 + matches.count) % matches.count
        expandAncestors(of: matches[currentMatch])
    }

    private func expandAncestors(of id: UUID) {
        guard let root, let path = idPath(to: id, in: root) else { return }
        for pid in path.dropLast() { collapsed.remove(pid) }
    }

    // MARK: 复制

    private func copyToPasteboard(_ s: String, _ message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        setStatus(message)
    }

    private func scalarText(_ n: JSONNode) -> String {
        switch n.kind {
        case .bool: return n.boolValue ? "true" : "false"
        case .null: return "null"
        default: return n.text
        }
    }

    /// 节点的 value 文本：标量取原文，容器取格式化子树
    private func valueText(_ n: JSONNode) -> String {
        n.isContainer ? JSONSerializer.serialize(n, pretty: true) : scalarText(n)
    }

    /// 仅复制 Key（对象成员）
    func copyKey(_ id: UUID) {
        guard let root, let n = findNode(id, in: root), let k = n.key else { return }
        copyToPasteboard(k, tr(.copiedKey))
    }

    /// 仅复制 Value（标量原文 / 容器子树）
    func copyValue(_ id: UUID) {
        guard let root, let n = findNode(id, in: root) else { return }
        copyToPasteboard(valueText(n), tr(.copiedValue))
    }

    /// 复制键值对："key": value
    func copyPair(_ id: UUID) {
        guard let root, let n = findNode(id, in: root), let k = n.key else { return }
        copyToPasteboard("\(JSONSerializer.escape(k)): \(valueText(n))", tr(.copiedPair))
    }

    /// 复制 JSON 片段（子树）
    func copyJSON(_ id: UUID) {
        guard let root, let n = findNode(id, in: root) else { return }
        copyToPasteboard(JSONSerializer.serialize(n, pretty: true), tr(.copiedJSON))
    }

    func copyPath(_ id: UUID) {
        guard let root, let comps = pathToNode(id, in: root) else { return }
        copyToPasteboard(jsonPathString(comps), tr(.copiedPath))
    }

    /// ⌘C 复制选中节点：对象成员复制键值对，数组元素/根复制子树
    func selectedCopyText() -> String? {
        guard let selectedNodeID, let root, let n = findNode(selectedNodeID, in: root) else { return nil }
        if let k = n.key {
            return "\(JSONSerializer.escape(k)): \(valueText(n))"
        }
        return JSONSerializer.serialize(n, pretty: true)
    }

    func copySelection() {
        guard let s = selectedCopyText() else { return }
        copyToPasteboard(s, tr(.copiedSelection))
    }

    // MARK: 格式化 / 压缩

    func format() {
        guard parseError == nil, let root else {
            setStatus(tr(.formatErrorInvalid))
            return
        }
        pushUndo()
        lastEditWasRaw = false
        rawText = JSONSerializer.serialize(root, pretty: true)
        setStatus(tr(.formatted))
    }

    func minify() {
        guard parseError == nil, let root else {
            setStatus(tr(.formatErrorInvalid))
            return
        }
        pushUndo()
        lastEditWasRaw = false
        rawText = JSONSerializer.serialize(root, pretty: false)
        setStatus(tr(.minified))
    }

    // MARK: 文件

    func newDocument() {
        pushUndo()
        lastEditWasRaw = false
        rawText = ""
        root = nil
        parseError = nil
        fileURL = nil
        collapsed = []
        selectedNodeID = nil
        matches = []; matchSet = []; currentMatch = 0
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { openURL(url) }
    }

    func openURL(_ url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            pushUndo()
            lastEditWasRaw = false
            rawText = text
            fileURL = url
            parseRaw()
            setStatus(parseError == nil ? trf(.openedFile, url.lastPathComponent) : tr(.openedWithError))
        } catch {
            setStatus(trf(.openFailed, error.localizedDescription))
        }
    }

    func importClipboard() {
        guard let s = NSPasteboard.general.string(forType: .string),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setStatus(tr(.clipboardEmpty))
            return
        }
        pushUndo()
        lastEditWasRaw = false
        rawText = s
        parseRaw()
        setStatus(parseError == nil ? tr(.clipboardImported) : tr(.clipboardInvalid))
    }

    func loadSample() {
        pushUndo()
        lastEditWasRaw = false
        fileURL = nil
        rawText = """
        {
          "name": "JSON Editor",
          "version": "1.0.0",
          "features": ["树形查看", "双向编辑", "主题切换", "搜索定位"],
          "settings": {
            "theme": "system",
            "fontSize": 13,
            "autoFormat": true
          },
          "downloads": 10240,
          "rating": 4.9,
          "beta": false,
          "maintainer": null
        }
        """
        parseRaw()
        setStatus(tr(.sampleLoaded))
    }

    func save() {
        if let fileURL { write(to: fileURL) } else { saveAs() }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "untitled.json"
        if panel.runModal() == .OK, let url = panel.url { write(to: url) }
    }

    private func write(to url: URL) {
        debounceTask?.cancel()
        parseRaw()
        if let err = parseError {
            setStatus(trf(.saveInvalidJSON, err.line))
            return
        }
        guard root != nil else {
            setStatus(tr(.saveEmpty))
            return
        }
        do {
            try rawText.write(to: url, atomically: true, encoding: .utf8)
            fileURL = url
            setStatus(trf(.savedTo, url.lastPathComponent))
        } catch {
            setStatus(trf(.saveFailed, error.localizedDescription))
        }
    }

    // MARK: 状态提示

    func setStatus(_ msg: String) {
        statusMessage = msg
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            self?.statusMessage = nil
        }
    }
}
