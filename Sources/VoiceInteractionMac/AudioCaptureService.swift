@preconcurrency import AVFoundation

private final class ConverterInputProvider: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var providedInput = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private let onSamples: ([Float]) -> Void
    private var converter: AVAudioConverter?

    init(targetSampleRate: Double, onSamples: @escaping ([Float]) -> Void) {
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!
        self.onSamples = onSamples
    }

    func start() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else {
                return
            }
            let samples = self.convertToTargetSamples(buffer: buffer)
            guard !samples.isEmpty else {
                return
            }
            self.onSamples(samples)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func convertToTargetSamples(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let converter else {
            return []
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let estimatedFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: estimatedFrameCapacity
        ) else {
            return []
        }

        var error: NSError?
        let inputProvider = ConverterInputProvider(buffer: buffer)

        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputProvider.providedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputProvider.providedInput = true
            outStatus.pointee = .haveData
            return inputProvider.buffer
        }

        guard status != .error, error == nil else {
            return []
        }

        guard let channelData = convertedBuffer.floatChannelData?[0] else {
            return []
        }

        let frameLength = Int(convertedBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: frameLength))
    }
}
