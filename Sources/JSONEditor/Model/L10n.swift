import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zh, en
    var id: String { rawValue }

    var resolvedCode: String {
        switch self {
        case .zh: return "zh"
        case .en: return "en"
        case .system:
            return (Locale.preferredLanguages.first?.hasPrefix("zh") ?? false) ? "zh" : "en"
        }
    }

    var displayName: String {
        switch self {
        case .system: return tr(.followSystem)
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

enum L10nKey {
    // 视图模式
    case tree, raw, split
    // 工具栏
    case openHelp, pasteHelp, formatHelp, minifyHelp, saveHelp, settingsHelp, searchPlaceholder
    case expandAll, collapseAll
    case theme, language, followSystem
    // 主菜单
    case newDocument, open, importClipboard, save, saveAs, undo, redo, format, minify
    // 右键菜单
    case copyKeyOnly, copyValueOnly, copyPair, copyJSONFragment, copyPath, collapse, expand
    // 状态栏
    case validJSON, emptyDocument, lineColError, nodeStats
    // 欢迎页
    case welcomeHint, openFile, pasteImport, loadSample, writeRaw
    // 复制提示
    case copiedJSON, copiedValue, copiedKey, copiedPair, copiedPath, copiedSelection
    // 格式化 / 压缩
    case formatErrorInvalid, formatted, minified
    // 文件
    case openFailed, openedFile, openedWithError
    case clipboardEmpty, clipboardImported, clipboardInvalid, sampleLoaded
    case saveInvalidJSON, saveEmpty, savedTo, saveFailed
    // 语言
    case languageRestartHint
    // 折叠按钮
    case collapseExpandHelp
}

enum L10n {
    static let table: [L10nKey: (zh: String, en: String)] = [
        .tree: ("树形", "Tree"),
        .raw: ("原文", "Raw"),
        .split: ("分屏", "Split"),
        .openHelp: ("打开 JSON 文件 (⌘O)", "Open JSON file (⌘O)"),
        .pasteHelp: ("从剪贴板导入 (⇧⌘V)", "Import from clipboard (⇧⌘V)"),
        .formatHelp: ("格式化 (⇧⌘F)", "Format (⇧⌘F)"),
        .minifyHelp: ("压缩为单行 (⇧⌘M)", "Minify (⇧⌘M)"),
        .saveHelp: ("保存为 .json 文件 (⌘S)", "Save as .json (⌘S)"),
        .settingsHelp: ("主题 / 语言 / 折叠设置", "Theme / Language / Folding"),
        .searchPlaceholder: ("搜索 key 或 value", "Search key or value"),
        .expandAll: ("全部展开", "Expand All"),
        .collapseAll: ("全部折叠", "Collapse All"),
        .theme: ("主题", "Theme"),
        .language: ("语言", "Language"),
        .followSystem: ("跟随系统", "Follow System"),
        .newDocument: ("新建", "New"),
        .open: ("打开…", "Open…"),
        .importClipboard: ("从剪贴板导入", "Import from Clipboard"),
        .save: ("保存", "Save"),
        .saveAs: ("另存为…", "Save As…"),
        .undo: ("撤销", "Undo"),
        .redo: ("重做", "Redo"),
        .format: ("格式化", "Format"),
        .minify: ("压缩为单行", "Minify"),
        .copyKeyOnly: ("仅复制 Key", "Copy Key Only"),
        .copyValueOnly: ("仅复制 Value", "Copy Value Only"),
        .copyPair: ("复制键值对", "Copy Key-Value Pair"),
        .copyJSONFragment: ("复制 JSON 片段", "Copy JSON Fragment"),
        .copyPath: ("复制路径 (JSONPath)", "Copy Path (JSONPath)"),
        .collapse: ("折叠", "Collapse"),
        .expand: ("展开", "Expand"),
        .validJSON: ("JSON 有效", "Valid JSON"),
        .emptyDocument: ("空文档", "Empty document"),
        .lineColError: ("第 %d 行 第 %d 列：%@", "Line %d, Col %d: %@"),
        .nodeStats: ("节点 %d · 深度 %d", "%d nodes · depth %d"),
        .welcomeHint: ("拖入 .json 文件，或从下方开始", "Drop a .json file, or start below"),
        .openFile: ("打开文件…", "Open File…"),
        .pasteImport: ("从剪贴板导入", "Paste from Clipboard"),
        .loadSample: ("载入示例", "Load Sample"),
        .writeRaw: ("直接写原文", "Write Raw JSON"),
        .copiedJSON: ("已复制 JSON 片段", "JSON fragment copied"),
        .copiedValue: ("已复制 Value", "Value copied"),
        .copiedKey: ("已复制 Key", "Key copied"),
        .copiedPair: ("已复制键值对", "Key-value pair copied"),
        .copiedPath: ("已复制路径", "Path copied"),
        .copiedSelection: ("已复制选中内容", "Selection copied"),
        .formatErrorInvalid: ("JSON 存在错误，无法格式化", "Invalid JSON, cannot format"),
        .formatted: ("已格式化", "Formatted"),
        .minified: ("已压缩为单行", "Minified"),
        .openFailed: ("打开失败：%@", "Open failed: %@"),
        .openedFile: ("已打开 %@", "Opened %@"),
        .openedWithError: ("文件已打开，但 JSON 存在错误", "File opened, but JSON has errors"),
        .clipboardEmpty: ("剪贴板中没有文本", "No text in clipboard"),
        .clipboardImported: ("已从剪贴板导入", "Imported from clipboard"),
        .clipboardInvalid: ("剪贴板内容不是有效的 JSON", "Clipboard content is not valid JSON"),
        .sampleLoaded: ("已载入示例", "Sample loaded"),
        .saveInvalidJSON: ("JSON 有错误（第 %d 行），无法保存", "JSON error (line %d), cannot save"),
        .saveEmpty: ("没有内容可保存", "Nothing to save"),
        .savedTo: ("已保存到 %@", "Saved to %@"),
        .saveFailed: ("保存失败：%@", "Save failed: %@"),
        .languageRestartHint: ("系统对话框的语言将在重启应用后生效", "System dialogs will switch language after relaunch"),
        .collapseExpandHelp: ("折叠 / 展开", "Collapse / Expand"),
    ]
}

func tr(_ key: L10nKey) -> String {
    let raw = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.system.rawValue
    let lang = AppLanguage(rawValue: raw) ?? .system
    let pair = L10n.table[key] ?? ("?", "?")
    return lang.resolvedCode == "zh" ? pair.zh : pair.en
}

func trf(_ key: L10nKey, _ args: CVarArg...) -> String {
    String(format: tr(key), arguments: args)
}
