import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var vm: EditorViewModel
    @Environment(\.colorScheme) private var scheme

    private var theme: AppTheme { AppTheme(rawValue: vm.themeID) ?? .system }
    private var palette: ThemePalette { theme.palette(for: scheme) }

    private var showWelcome: Bool {
        vm.root == nil
            && vm.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && vm.mode == .tree
    }

    var body: some View {
        VStack(spacing: 0) {
            if showWelcome {
                WelcomeView(palette: palette)
                    .transition(.opacity)
            } else {
                mainContent
            }
            Divider()
            StatusBarView(palette: palette)
        }
        .background(palette.background)
        .animation(.easeInOut(duration: 0.2), value: vm.mode)
        .animation(.easeInOut(duration: 0.2), value: showWelcome)
        .toolbar { toolbarContent }
        .id(vm.language)
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
            providers.first?.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async { vm.openURL(url) }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch vm.mode {
        case .tree:
            TreeView(palette: palette)
                .transition(.opacity)
        case .raw:
            RawTextEditor(palette: palette)
                .transition(.opacity)
        case .split:
            HSplitView {
                TreeView(palette: palette)
                    .frame(minWidth: 320)
                RawTextEditor(palette: palette)
                    .frame(minWidth: 320)
            }
            .transition(.opacity)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { vm.openPanel() } label: {
                Image(systemName: "folder")
            }
            .help(tr(.openHelp))
            Button { vm.importClipboard() } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .help(tr(.pasteHelp))
        }

        ToolbarItem(placement: .principal) {
            Picker("", selection: $vm.mode) {
                ForEach(ViewMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button { vm.format() } label: {
                Image(systemName: "text.alignleft")
            }
            .help(tr(.formatHelp))
            Button { vm.minify() } label: {
                Image(systemName: "arrow.left.and.right.line.vertical.and.arrow.right")
            }
            .help(tr(.minifyHelp))

            Menu {
                Picker(tr(.theme), selection: $vm.themeID) {
                    ForEach(AppTheme.allCases) { t in
                        Text(t.displayName).tag(t.rawValue)
                    }
                }
                Picker(tr(.language), selection: $vm.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                Divider()
                Button(tr(.expandAll)) { vm.expandAll() }
                Button(tr(.collapseAll)) { vm.collapseAll() }
            } label: {
                Image(systemName: "paintpalette")
            }
            .help(tr(.settingsHelp))

            Button { vm.save() } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help(tr(.saveHelp))

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.secondaryText)
                TextField(tr(.searchPlaceholder), text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 130)
                if !vm.searchText.isEmpty {
                    Text(vm.matches.isEmpty ? "0/0" : "\(vm.currentMatch + 1)/\(vm.matches.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.secondaryText)
                    Button { vm.prevMatch() } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.plain)
                        .disabled(vm.matches.isEmpty)
                    Button { vm.nextMatch() } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.plain)
                        .disabled(vm.matches.isEmpty)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
