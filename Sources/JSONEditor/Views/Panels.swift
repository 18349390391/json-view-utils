import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var vm: EditorViewModel
    let palette: ThemePalette

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "curlybraces")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(palette.accent)
            Text(tr(.welcomeHint))
                .font(.title3)
                .foregroundStyle(palette.secondaryText)
            HStack(spacing: 14) {
                Button(tr(.openFile)) { vm.openPanel() }
                    .controlSize(.large)
                Button(tr(.pasteImport)) { vm.importClipboard() }
                    .controlSize(.large)
                Button(tr(.loadSample)) { vm.loadSample() }
                    .controlSize(.large)
                Button(tr(.writeRaw)) { vm.mode = .raw }
                    .controlSize(.large)
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .foregroundStyle(palette.secondaryText.opacity(0.4))
                .padding(24)
                .allowsHitTesting(false)
        }
        .padding()
    }
}

struct StatusBarView: View {
    @EnvironmentObject private var vm: EditorViewModel
    let palette: ThemePalette

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.parseError == nil ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            if let err = vm.parseError {
                Text(trf(.lineColError, err.line, err.column, err.message))
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(vm.root == nil ? tr(.emptyDocument) : tr(.validJSON))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            if let status = vm.statusMessage {
                Text("· \(status)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .transition(.opacity)
            }
            Spacer()
            if vm.root != nil {
                Text(trf(.nodeStats, vm.nodeCount, vm.treeDepth))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            if let url = vm.fileURL {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(palette.panel)
        .animation(.easeOut(duration: 0.2), value: vm.statusMessage)
    }
}
