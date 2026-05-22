import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: VoiceTypingController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(controller.statusColor)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.statusTitle)
                        .font(.headline)
                    Text("Hotkey: F9 (start/stop)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !controller.accessibilityGranted {
                Text("Accessibility permission is required to type into other apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !controller.microphoneGranted {
                Text("Microphone permission is required to capture audio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(controller.isRunning ? "Stop" : "Start") {
                    controller.isRunning ? controller.stop() : controller.start()
                }
                .keyboardShortcut(.defaultAction)

                Spacer()

                Button("Permissions") {
                    controller.requestPermissions()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Last Transcript")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(controller.lastTranscript.isEmpty ? "No transcription yet." : controller.lastTranscript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 110, maxHeight: 160)
            }
        }
        .padding(14)
    }
}
