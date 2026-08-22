import AVFoundation

final class NESAudioOutput {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 44_100,
        channels: 1,
        interleaved: false
    )!

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            player.play()
        } catch {
            // Video and input remain usable when the host cannot open audio.
        }
    }

    func enqueue(samples: UnsafePointer<Int16>, count: Int) {
        guard count > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(count)
            ),
            let destination = buffer.int16ChannelData?[0]
        else { return }

        buffer.frameLength = AVAudioFrameCount(count)
        destination.update(from: samples, count: count)
        player.scheduleBuffer(buffer)
    }

    func pause() {
        player.pause()
    }

    func resume() {
        if engine.isRunning { player.play() }
    }

    func stop() {
        player.stop()
        engine.stop()
    }
}
