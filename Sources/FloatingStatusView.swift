import SwiftUI

/// Floating overlay that shows the current processing stage with icons + spinners.
/// IMPORTANT: keeps a FIXED frame and stable view structure so the NSHostingView
/// inside the NSPanel never renegotiates constraints during stage transitions
/// (that caused EXC_BREAKPOINT crashes in _NSViewUpdateConstraints).
struct FloatingStatusView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        ZStack {
            content
        }
        .frame(width: 300, height: 76)
        .animation(nil, value: controller.stage)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.stage {
        case .recording:
            WaveformView(recorder: controller.recorder)
        case .transcribing:
            StatusPill(icon: "waveform", iconColor: .cyan, text: "Transcribing…", spin: true)
        case .correcting:
            StatusPill(icon: "sparkles", iconColor: .purple, text: "Fixing text…", spin: true)
        case .done(let snippet):
            StatusPill(icon: "checkmark.circle.fill", iconColor: .green,
                       text: snippet.isEmpty ? "Done" : snippet, spin: false)
        case .error(let msg):
            StatusPill(icon: "exclamationmark.triangle.fill", iconColor: .orange,
                       text: msg, spin: false)
        case .idle:
            Color.clear
        }
    }
}

/// Pill-shaped status indicator: icon + optional spinner + label
struct StatusPill: View {
    let icon: String
    let iconColor: Color
    let text: String
    let spin: Bool

    var body: some View {
        HStack(spacing: 10) {
            if spin {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 16)
            }

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        // fixed frame keeps intrinsic size stable → no constraint churn
        .frame(width: 240, height: 40, alignment: .center)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
