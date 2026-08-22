//
//  AudioInput.swift
//  flutter_alib
//
//  Created by renan jegouzo on 05/12/2023.
//
@preconcurrency import AVFoundation
import Cocoa

/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct AudioDevice {
    public let id: AudioDeviceID
    public let name: String
    public let manufacturer: String
    public let inputChannels: [String]
    public let outputChannels: [String]

    // https://developer.apple.com/forums/thread/71008
    // https://forum.juce.com/t/how-to-fix-the-channel-names-of-coreaudio-devices/12349
    public func open(leftChannel: Int, rightChannel: Int = -1, fps: Double = 60) throws -> Stream<
        Float
    > {
        let engine = AVAudioEngine()
        guard let audioUnit: AudioUnit = engine.inputNode.audioUnit else {
            throw AudioError.audioUnitError
        }
        var inputDeviceID: AudioDeviceID = UInt32(id)
        AudioUnitSetProperty(
            audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Input, 0,
            &inputDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size))
        let stream = BufferedStream<Float>()
        let inputFormat = engine.inputNode.inputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 2,
            interleaved: true)!
        Debug.info("inputFormat: \(inputFormat) outputFormat: \(outputFormat)")
        // https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/audio/coreaudio.c
        var inNumberFrames: UInt32 = UInt32(inputFormat.sampleRate / fps)
        let propSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        AudioUnitSetProperty(
            audioUnit,
            kAudioDevicePropertyBufferFrameSize,
            kAudioUnitScope_Input,
            0,
            &inNumberFrames,
            propSize)

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioError.audioConverterError
        }
        converter.channelMap[0] = NSNumber(value: min(leftChannel, inputChannels.count - 1))
        converter.channelMap[1] = NSNumber(
            value: min(rightChannel >= 0 ? rightChannel : leftChannel, inputChannels.count - 1))
        let resample = Resample(inputSampleRate: inputFormat.sampleRate, outputSampleRate: 44100)
        let sinkNode = AVAudioSinkNode { (timestamp, frames, audioBufferList) -> OSStatus in
            guard
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: inputFormat, bufferListNoCopy: audioBufferList)
            else {
                Debug.warning("AVAudioPCMBuffer format mismatch")
                DispatchQueue.main.async {
                    stream.error(AudioError.formatError)
                }
                //stream.close()
                return noErr
            }
            if let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat, frameCapacity: buffer.frameLength)
            {
                do {
                    try converter.convert(to: convertedBuffer, from: buffer)
                } catch {}
                let audioData = [Float](
                    UnsafeBufferPointer(
                        start: convertedBuffer.floatChannelData?[0],
                        count: Int(convertedBuffer.frameLength) * convertedBuffer.stride))
                let resampled = resample.feed(data: audioData)
                if stream.write(resampled, offset: 0, count: resampled.count) != resampled.count {
                    Debug.error("AudioDevice: input skipping, buffer full")
                }
            }
            return noErr
        }
        engine.attach(sinkNode)
        engine.connect(engine.inputNode, to: sinkNode, format: inputFormat)
        engine.prepare()
        try engine.start()
        // https://medium.com/@itsuki.enjoy/swift-macos-listen-for-input-device-changes-three-ways-6b60e5367aa0
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { n in
            DispatchQueue.main.async {
                stream.error(AudioError.audioUnitSettingsChanged)
            }
        }
        stream.onClose.once {
            engine.stop()
            engine.detach(sinkNode)
        }
        return stream
    }
    // audio engine https://developer.apple.com/documentation/avfaudio/avaudioengine
    // audio sink https://developer.apple.com/documentation/avfaudio/avaudiosinknode

    public static var devices: [AudioDevice] {
        var devices = [AudioDevice]()
        var propertySize: UInt32 = 0
        var status: OSStatus = noErr
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        if status != noErr {
            print("Error: Unable to get the number of audio devices.")
            return devices
        }
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        if status != noErr {
            print("Error: Unable to get the audio device IDs.")
            return devices
        }
        for deviceID in deviceIDs {
            var deviceName: String = "No name"
            var deviceManufacturer: String = "No name"
            var inputChannels: Int = 0
            var outputChannels: Int = 0

            // Get device name
            propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
            propertySize = UInt32(MemoryLayout<CFString>.size)
            var name: CFString?
            withUnsafeMutablePointer(to: &name) { ptr in
                status = AudioObjectGetPropertyData(
                    deviceID,
                    &propertyAddress,
                    0,
                    nil,
                    &propertySize,
                    ptr
                )
            }
            if status == noErr, let deviceNameCF = name as String? {
                deviceName = deviceNameCF
            }
            // Get device manufacturer
            propertyAddress.mSelector = kAudioDevicePropertyDeviceManufacturerCFString
            propertySize = UInt32(MemoryLayout<CFString>.size)
            var manufacturer: CFString?
            withUnsafeMutablePointer(to: &manufacturer) { ptr in
                status = AudioObjectGetPropertyData(
                    deviceID,
                    &propertyAddress,
                    0,
                    nil,
                    &propertySize,
                    ptr
                )
            }
            if status == noErr, let deviceManufacturerCF = manufacturer as String? {
                deviceManufacturer = deviceManufacturerCF
            }
            // Get input channels
            propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
            propertyAddress.mScope = kAudioDevicePropertyScopeInput
            status = AudioObjectGetPropertyDataSize(
                deviceID, &propertyAddress, 0, nil, &propertySize)
            if status == noErr {
                let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                defer { bufferListPointer.deallocate() }
                status = AudioObjectGetPropertyData(
                    deviceID, &propertyAddress, 0, nil, &propertySize, bufferListPointer)
                if status == noErr {
                    let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
                    for buffer in bufferList {
                        inputChannels += Int(buffer.mNumberChannels)
                    }
                }
            }
            // Get output channels
            propertyAddress.mScope = kAudioDevicePropertyScopeOutput
            status = AudioObjectGetPropertyDataSize(
                deviceID, &propertyAddress, 0, nil, &propertySize)
            if status == noErr {
                let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                defer { bufferListPointer.deallocate() }
                status = AudioObjectGetPropertyData(
                    deviceID, &propertyAddress, 0, nil, &propertySize, bufferListPointer)
                if status == noErr {
                    let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
                    for buffer in bufferList {
                        outputChannels += Int(buffer.mNumberChannels)
                    }
                }
            }
            var inputChannelNames: [String] = []
            var outputChannelNames: [String] = []
            // get input channel names
            if inputChannels > 0 {
                for chan in 1...inputChannels {
                    var chanName: String = "Input \(chan)"
                    propertyAddress.mSelector = kAudioObjectPropertyElementName
                    propertyAddress.mScope = kAudioDevicePropertyScopeInput  // : kAudioDevicePropertyScopeOutput;
                    propertyAddress.mElement = UInt32(chan)
                    var name: CFString?
                    withUnsafeMutablePointer(to: &name) { ptr in
                        status = AudioObjectGetPropertyData(
                            deviceID,
                            &propertyAddress,
                            0,
                            nil,
                            &propertySize,
                            ptr
                        )
                    }
                    if status == noErr, let nameCF = name as String?, !nameCF.isEmpty {
                        chanName = nameCF
                    }
                    inputChannelNames.append(chanName)
                }
            }
            // get output channel names
            if outputChannels > 0 {
                for chan in 1...outputChannels {
                    var chanName: String = "Output \(chan)"
                    propertyAddress.mSelector = kAudioObjectPropertyElementName
                    propertyAddress.mScope = kAudioDevicePropertyScopeOutput
                    propertyAddress.mElement = UInt32(chan)
                    var name: CFString?
                    withUnsafeMutablePointer(to: &name) { ptr in
                        status = AudioObjectGetPropertyData(
                            deviceID,
                            &propertyAddress,
                            0,
                            nil,
                            &propertySize,
                            ptr
                        )
                    }
                    if status == noErr, let nameCF = name as String?, !nameCF.isEmpty {
                        chanName = nameCF
                    }
                    outputChannelNames.append(chanName)
                }
            }

            devices.append(
                AudioDevice(
                    id: deviceID, name: deviceName, manufacturer: deviceManufacturer,
                    inputChannels: inputChannelNames, outputChannels: outputChannelNames))
        }
        return devices
    }

    public static func getDevice(id: Int64) -> AudioDevice? {
        return devices.first(where: { $0.id == id })
    }

    public static func getDevice(name: String) -> AudioDevice? {
        return devices.first(where: { $0.name == name })
    }
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public enum AudioError: Swift.Error {
    case audioUnitError
    case audioUnitSettingsChanged
    case audioConverterError
    case channelError
    case formatError
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
