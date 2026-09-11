import SwiftUI

@main
struct JSONEditorApp: App {
    @StateObject private var vm = EditorViewModel()

    init() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                // 隐藏视图：建立对 language 的依赖，语言切换时重建全部菜单
                Text(vm.language).hidden().accessibilityHidden(true)
                Button(tr(.newDocument)) { vm.newDocument() }
                    .keyboardShortcut("n")
                Button(tr(.open)) { vm.openPanel() }
                    .keyboardShortcut("o")
                Button(tr(.importClipboard)) { vm.importClipboard() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button(tr(.save)) { vm.save() }
                    .keyboardShortcut("s")
                Button(tr(.saveAs)) { vm.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button(tr(.undo)) { vm.undo() }
                    .keyboardShortcut("z")
                    .disabled(!vm.canUndo)
                Button(tr(.redo)) { vm.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!vm.canRedo)
            }
            CommandGroup(after: .pasteboard) {
                Button(tr(.format)) { vm.format() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Button(tr(.minify)) { vm.minify() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Divider()
                Button(tr(.expandAll)) { vm.expandAll() }
                Button(tr(.collapseAll)) { vm.collapseAll() }
            }
        }
    }
}
