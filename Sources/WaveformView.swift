import SwiftUI

/// Scrolling waveform bars that respond to real-time audio level (floating overlay while speaking)
struct WaveformView: View {
    @ObservedObject var recorder: AudioRecorder
    @State private var bars: [CGFloat] = Array(repeating: 0.05, count: 32)
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(bars.indices, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: max(4, bars[i] * 56))
            }
        }
        .frame(width: 250, height: 70)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.08), value: bars)
        .onReceive(timer) { _ in
            let lvl = CGFloat(recorder.level)
            // Shift left, append new value on right with slight jitter for organic feel
            bars.removeFirst()
            let jitter = CGFloat.random(in: 0.5...1.1)
            bars.append(min(1, max(0.05, lvl * jitter)))
        }
    }
}
