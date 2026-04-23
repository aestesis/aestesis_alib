//
//  AudioInput.swift
//  flutter_alib
//
//  Created by renan jegouzo on 05/12/2023.
//
@preconcurrency

import AVFoundation
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
    public func open(leftChannel: Int, rightChannel: Int = -1, fps: Double = 60) throws -> Stream<Float> {
        // TODO: debug, suxx if selected input not the same than system default input
        // forum https://forums.developer.apple.com/forums/thread/71008
        let engine = AVAudioEngine()
        let inputNode: AVAudioInputNode = engine.inputNode
        // get the low level input audio unit from the engine:
        guard let inputUnit: AudioUnit = inputNode.audioUnit else {
            throw AudioError.audioUnitError
        }
        // use core audio low level call to set the input device:
        var inputDeviceID: AudioDeviceID = UInt32(id)
        AudioUnitSetProperty(
            inputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
            &inputDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size))

        var inNumberFrames: UInt32 = UInt32(44100 / fps)
        let propSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        AudioUnitSetProperty(
            inputUnit,
            kAudioDevicePropertyBufferFrameSize,
            kAudioUnitScope_Input,
            0,
            &inNumberFrames,
            propSize)
        /*
         // https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/audio/coreaudio.c
         var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyBufferFrameSize, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
         AudioObjectSetPropertyData(UInt32(id),
         &addr,
         0,
         nil,
         propSize,
         &inNumberFrames);
         */
        let stream = BufferedStream<Float>()

        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: true)!
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioError.audioConverterError
        }
        converter.channelMap[0] = NSNumber(value: min(leftChannel, inputChannels.count - 1))
        converter.channelMap[1] = NSNumber(
            value: min(rightChannel >= 0 ? rightChannel : leftChannel, inputChannels.count - 1))

        let sinkNode = AVAudioSinkNode { (timestamp, frames, audioBufferList) -> OSStatus in
            //print("SINK: \(timestamp.pointee.mHostTime) - \(frames) - \(audioBufferList.pointee.mNumberBuffers)")
            guard
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: inputFormat, bufferListNoCopy: audioBufferList)
            else {
                Debug.warning("AVAudioPCMBuffer format mismatch")
                stream.close()  // new: added 2024.08.02, needs verifying if working
                return noErr
            }
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = AVAudioConverterInputStatus.haveData
                return buffer
            }
            let targetFrameCapacity =
                AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength
                / AVAudioFrameCount(buffer.format.sampleRate)
            if let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat, frameCapacity: targetFrameCapacity)
            {
                var error: NSError?
                let status = converter.convert(
                    to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                assert(status != .error)
                let audioData = [Float](
                    UnsafeBufferPointer(
                        start: convertedBuffer.floatChannelData?[0],
                        count: Int(convertedBuffer.frameLength) * convertedBuffer.stride))
                if stream.write(audioData, offset: 0, count: audioData.count) != audioData.count {
                    Debug.error("AudioDevice: input skipping, buffer full")
                }
            }
            return noErr
        }
        engine.attach(sinkNode)
        engine.connect(engine.inputNode, to: sinkNode, format: nil)
        engine.prepare()
        try engine.start()
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

public enum AudioError: Swift.Error {
    case audioUnitError
    case audioConverterError
    case channelError
}
