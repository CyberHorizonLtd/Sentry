import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox

final class SirenEngine {
    static let shared = SirenEngine()

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isAlarmActive = false
    private var volumeLockTimer: Timer?
    private var targetDeviceID: AudioDeviceID = 0

    private init() {}

    func startAlarm() {
        guard !isAlarmActive else { return }
        isAlarmActive = true

        // Find Built-In MacBook Internal Speaker (bypassing AirPods / Bluetooth / External displays)
        targetDeviceID = findBuiltInSpeakerDeviceID() ?? defaultOutputDeviceID()

        print("[Sentry] Locking MAX volume (100%) on MacBook Internal Speakers (Device ID: \(targetDeviceID))...")
        setMaxVolumeForDevice(targetDeviceID)

        // Lock volume to 100% every 200ms
        volumeLockTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.setMaxVolumeForDevice(self.targetDeviceID)
        }

        // Play synthesized police siren wave routed directly to Built-In Speakers
        playSirenTone(onDevice: targetDeviceID)
    }

    func stopAlarm() {
        guard isAlarmActive else { return }
        isAlarmActive = false
        volumeLockTimer?.invalidate()
        volumeLockTimer = nil

        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }

    private func findBuiltInSpeakerDeviceID() -> AudioDeviceID? {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        )
        guard status == noErr, size > 0 else { return nil }

        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &devices
        )

        for device in devices {
            // Check if device has output channels
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            if AudioObjectGetPropertyDataSize(device, &streamAddress, 0, nil, &streamSize) == noErr && streamSize > 0 {
                let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(streamSize))
                defer { bufferListPointer.deallocate() }
                if AudioObjectGetPropertyData(device, &streamAddress, 0, nil, &streamSize, bufferListPointer) == noErr {
                    let buffers = UnsafeMutableAudioBufferListPointer(bufferListPointer)
                    let outputChannels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
                    if outputChannels == 0 { continue }
                }
            } else {
                continue
            }

            // Check Transport Type for Built-In Speaker ('bltn')
            var transportType: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            var transportAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            if AudioObjectGetPropertyData(device, &transportAddress, 0, nil, &transportSize, &transportType) == noErr {
                if transportType == kAudioDeviceTransportTypeBuiltIn {
                    print("[Sentry] Identified Built-In MacBook Speaker Device ID: \(device)")
                    return device
                }
            }
        }
        return nil
    }

    private func defaultOutputDeviceID() -> AudioDeviceID {
        var defaultDeviceID = AudioDeviceID(0)
        var defaultDeviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        _ = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDevicePropertyAddress,
            0,
            nil,
            &defaultDeviceSize,
            &defaultDeviceID
        )
        return defaultDeviceID
    }

    private func setMaxVolumeForDevice(_ deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        var volume: Float32 = 1.0 // 100% Max Volume
        var volumeSize = UInt32(MemoryLayout<Float32>.size)

        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(deviceID, &volumePropertyAddress) {
            AudioObjectSetPropertyData(deviceID, &volumePropertyAddress, 0, nil, volumeSize, &volume)
        } else {
            // Channel 1 & 2 fallback
            volumePropertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
            volumePropertyAddress.mElement = 1
            if AudioObjectHasProperty(deviceID, &volumePropertyAddress) {
                AudioObjectSetPropertyData(deviceID, &volumePropertyAddress, 0, nil, volumeSize, &volume)
            }
            volumePropertyAddress.mElement = 2
            if AudioObjectHasProperty(deviceID, &volumePropertyAddress) {
                AudioObjectSetPropertyData(deviceID, &volumePropertyAddress, 0, nil, volumeSize, &volume)
            }
        }
    }

    private func playSirenTone(onDevice deviceID: AudioDeviceID) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        // Route audio output directly to Internal MacBook Speakers
        if deviceID != 0, let audioUnit = engine.outputNode.audioUnit {
            var devID = deviceID
            AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &devID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }

        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        
        // Generate a 4-second looping siren buffer (sweeping frequency between 700 Hz and 1500 Hz)
        let duration: Double = 4.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let floatData = buffer.floatChannelData else { return }
        let channels = floatData[0]
        let twoPi = 2.0 * Double.pi

        var phase: Double = 0.0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Modulating frequency (0.5 Hz sweep rate between 700 Hz and 1600 Hz)
            let sweep = (sin(twoPi * 0.75 * t) + 1.0) / 2.0
            let currentFreq = 700.0 + (900.0 * sweep)

            phase += twoPi * currentFreq / sampleRate
            if phase > twoPi { phase -= twoPi }

            // High intensity square/sine hybrid wave
            let sample = Float(sin(phase) > 0 ? 0.85 : -0.85)
            channels[i] = sample
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            player.play()
            // Loop buffer endlessly
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            
            self.audioEngine = engine
            self.playerNode = player
        } catch {
            print("Failed to start AVAudioEngine siren: \(error)")
        }
    }
}
