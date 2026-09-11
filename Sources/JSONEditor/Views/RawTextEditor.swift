import SwiftUI
import AppKit

/// 原文编辑器：NSTextView 封装。
/// 关键：关闭智能引号/破折号/拼写替换，避免输入 " 被自动替换成 “ ” 导致 JSON 失效。
struct RawTextEditor: NSViewRepresentable {
    @EnvironmentObject var vm: EditorViewModel
    let palette: ThemePalette

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.usesFontPanel = false
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.string = vm.rawText
        textView.textColor = palette.nsText
        textView.backgroundColor = palette.nsBackground
        textView.insertionPointColor = palette.nsText
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = palette.nsBackground
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textColor = palette.nsText
        textView.backgroundColor = palette.nsBackground
        textView.insertionPointColor = palette.nsText
        scrollView.backgroundColor = palette.nsBackground

        // 外部变更（撤销/格式化/打开文件等）同步进编辑器，不覆盖用户正在输入的内容
        if textView.string != vm.rawText {
            let selected = textView.selectedRanges
            textView.string = vm.rawText
            let length = (textView.string as NSString).length
            textView.selectedRanges = selected.map {
                NSValue(range: NSRange(location: min($0.rangeValue.location, length), length: 0))
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RawTextEditor
        init(_ parent: RawTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.vm.userEditedRaw(textView.string)
        }
    }
}
