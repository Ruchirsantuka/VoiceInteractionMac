@preconcurrency import AVFoundation
import Combine
import Foundation
import SwiftUI
import WhisperKit

final class VoiceTypingController: ObservableObject, @unchecked Sendable {
    private enum Status: Equatable {
        case stopped
        case loading
        case listening
        case paused
    }

    @Published private var status: Status = .stopped
    @Published var errorMessage: String?
    @Published var lastTranscript = ""
    @Published var microphoneGranted = false
    @Published var accessibilityGranted = false

    private let modelName = "large-v3-v20240930_626MB"
    private let silenceThreshold: Float = 0.01
    private let lowEnergyHallucinationThreshold: Float = 0.02
    private let silenceDuration: Double = 1.0
    private let minSpeechDuration: Double = 0.3
    private let maxSpeechDuration: Double = 15.0
    private let sampleRate: Double = 16_000

    private let audioQueue = DispatchQueue(label: "VoiceInteractionMac.audio")
    private let transcriptionQueue = DispatchQueue(label: "VoiceInteractionMac.transcription")

    private var whisperKit: WhisperKit?
    private var audioCapture: AudioCaptureService?
    private var hotKey: GlobalHotKey?

    private var segmentBuffer: [Float] = []
    private var silenceSampleCount = 0
    private var speechSampleCount = 0
    private var inSpeech = false

    init() {
        accessibilityGranted = AccessibilityTyper.isTrusted(prompt: false)
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        hotKey = GlobalHotKey(keyCode: 101) { [weak self] in
            DispatchQueue.main.async {
                self?.togglePause()
            }
        }
        hotKey?.register()
    }

    deinit {
        hotKey?.unregister()
        audioCapture?.stop()
    }

    var isRunning: Bool {
        switch status {
        case .stopped:
            return false
        case .loading, .listening, .paused:
            return true
        }
    }

    var isPaused: Bool {
        status == .paused
    }

    var statusTitle: String {
        switch status {
        case .stopped:
            return "Stopped"
        case .loading:
            return "Loading..."
        case .listening:
            return "Listening"
        case .paused:
            return "Paused"
        }
    }

    var statusSymbolName: String {
        menuBarSymbolName
    }

    var statusColor: Color {
        switch status {
        case .stopped:
            return .gray
        case .loading:
            return .gray
        case .listening:
            return .green
        case .paused:
            return .orange
        }
    }

    var menuBarSymbolName: String {
        switch status {
        case .listening:
            return "waveform.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .loading:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .stopped:
            return "mic.slash.circle"
        }
    }

    func start() {
        guard !isRunning else {
            return
        }

        requestPermissions()
        status = .loading
        errorMessage = nil

        Task {
            do {
                if whisperKit == nil {
                    let config = WhisperKitConfig(model: modelName)
                    whisperKit = try await WhisperKit(config)
                }

                try await startAudioCapture()
                await MainActor.run {
                    self.resetSegmentationState()
                    self.status = .listening
                }
            } catch {
                await MainActor.run {
                    self.status = .stopped
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stop() {
        audioCapture?.stop()
        audioCapture = nil
        resetSegmentationState()
        status = .stopped
    }

    func togglePause() {
        guard isRunning else {
            return
        }

        if status == .paused {
            status = .listening
        } else if status == .listening {
            status = .paused
        }
    }

    func requestPermissions() {
        accessibilityGranted = AccessibilityTyper.isTrusted(prompt: true)

        Task {
            let granted = await requestMicrophonePermission()
            await MainActor.run {
                self.microphoneGranted = granted
                if !granted {
                    self.errorMessage = "Microphone access was denied."
                }
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func startAudioCapture() async throws {
        let capture = AudioCaptureService(targetSampleRate: sampleRate) { [weak self] samples in
            guard let controller = self else {
                return
            }
            controller.audioQueue.async {
                controller.consume(samples: samples)
            }
        }
        try capture.start()
        audioCapture = capture
    }

    private func consume(samples: [Float]) {
        guard status == .listening else {
            return
        }

        let rms = rootMeanSquare(samples)
        let isSpeech = rms > silenceThreshold

        if isSpeech {
            if !inSpeech {
                inSpeech = true
                segmentBuffer.removeAll(keepingCapacity: true)
                speechSampleCount = 0
            }
            silenceSampleCount = 0
            segmentBuffer.append(contentsOf: samples)
            speechSampleCount += samples.count

            if Double(speechSampleCount) / sampleRate >= maxSpeechDuration {
                flushSegment()
            }
        } else if inSpeech {
            segmentBuffer.append(contentsOf: samples)
            silenceSampleCount += samples.count
            speechSampleCount += samples.count

            if Double(silenceSampleCount) / sampleRate >= silenceDuration {
                if Double(speechSampleCount) / sampleRate >= minSpeechDuration {
                    flushSegment()
                } else {
                    resetSegmentationState()
                }
            }
        }
    }

    private func flushSegment() {
        let audio = segmentBuffer
        let segmentRMS = rootMeanSquare(audio)
        resetSegmentationState()
        guard !audio.isEmpty else {
            return
        }

        transcriptionQueue.async { [weak self] in
            self?.transcribe(audio: audio, segmentRMS: segmentRMS)
        }
    }

    private func transcribe(audio: [Float], segmentRMS: Float) {
        guard let whisperKit else {
            return
        }

        Task {
            do {
                let result = try await whisperKit.transcribe(audioArray: audio)
                let text = result
                    .map(\.text)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    return
                }
                guard !shouldIgnoreLowEnergyTranscript(text, segmentRMS: segmentRMS) else {
                    return
                }

                await MainActor.run {
                    self.lastTranscript = text
                    self.errorMessage = nil
                }
                AccessibilityTyper.paste(text + " ")
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func shouldIgnoreLowEnergyTranscript(_ text: String, segmentRMS: Float) -> Bool {
        guard segmentRMS < lowEnergyHallucinationThreshold else {
            return false
        }

        let normalizedText = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)

        return normalizedText == "thank you"
    }

    private func resetSegmentationState() {
        segmentBuffer.removeAll(keepingCapacity: false)
        silenceSampleCount = 0
        speechSampleCount = 0
        inSpeech = false
    }

    private func rootMeanSquare(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else {
            return 0
        }
        let sum = samples.reduce(Float.zero) { partial, sample in
            partial + (sample * sample)
        }
        return sqrt(sum / Float(samples.count))
    }
}
