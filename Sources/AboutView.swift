import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 14) {
            if let iconPath = Bundle.main.path(forResource: "Icon", ofType: "icns"),
               let icon = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(red: 0.8, green: 0.44, blue: 0.3).opacity(0.35), radius: 14, y: 6)
            } else {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .foregroundColor(Color(red: 0.8, green: 0.44, blue: 0.3))
            }

            Text("Whisper")
                .font(.title2).bold()
            Text("Version \(version)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Speak, and your Mac types for you.\nHold Fn to talk — transcribed by Whisper, polished by AI.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider().padding(.horizontal, 30)

            VStack(spacing: 4) {
                Text("Created by")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Gamezxz 🧙‍♂️")
                    .font(.headline)
                Text("Developer · Bitcoiner · Bangkok")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 14) {
                Link("cointh.com", destination: URL(string: "https://cointh.com")!)
                Link("GitHub", destination: URL(string: "https://github.com/Gamezxz/WhisperApp")!)
                Link("Website", destination: URL(string: "https://gamezxz.github.io/WhisperApp/")!)
            }
            .font(.callout)

            Text("© 2026 Gamezxz — free & open source")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(28)
        .frame(width: 340)
    }
}
