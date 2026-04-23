//
//  VideoWriter.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 26/10/2023.
//

import AVFoundation
import Foundation

// doc https://developer.apple.com/documentation/avfoundation/avassetwriter
// example https://gist.github.com/yusuke024/b5cd3909d9d7f9e919291491f6b381f0
// example2: https://gist.github.com/xaphod/de83379cc982108a5b38115957a247f9

/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public class VideoWriter : @unchecked Sendable {
    let queue: DispatchQueue = DispatchQueue(label: "VideoWriter", qos: .utility)
    let onChanged = Event<Status>()
    enum Option {
        case audio,video
    }
    let url: URL
    let fps: Double
    
    let writer: AVAssetWriter
    var audioInput: AVAssetWriterInput?
    var videoInput: AVAssetWriterInput?
    
    let timeScale:Int32 = 1000
    var startTime:Double?
    var videoFrames:Int = 0
    var audioSamples:Int = 0
    var currentTime:Double {
        guard let startTime = startTime else { return 0 }
        return ß.time - startTime
    }
    
    public var status:Status {
        return Status.fromWriter(writer: writer)
    }
    
    var audioStreamBasicDescription : AudioStreamBasicDescription {
        let nchan = 2
        let bytesPerChannel=MemoryLayout<Float>.size
        let bytesPerPacket=nchan*bytesPerChannel
        return AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM , mFormatFlags: kLinearPCMFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian, mBytesPerPacket: UInt32(bytesPerPacket), mFramesPerPacket: 1, mBytesPerFrame: UInt32(bytesPerPacket), mChannelsPerFrame: UInt32(nchan), mBitsPerChannel: UInt32(bytesPerChannel*8), mReserved: 0)
    }
    
    var isBigEndian : Bool {
        let number: UInt32 = 0x12345678
        return  number == number.bigEndian
    }
    
    public init(url: URL, size: Size = .zero, fps: Double = 0, options:[Option] = [] ) throws {
        if options.isEmpty {
            throw Error.noOptions
        }
        self.url = url
        self.fps = fps
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        self.writer = writer
        
        // presets: AVOutputSettingsAssistant
        
        if options.contains(element: .audio) {
            audioInput = try AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVNumberOfChannelsKey: audioStreamBasicDescription.mChannelsPerFrame,
                    AVSampleRateKey: audioStreamBasicDescription.mSampleRate,
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMIsBigEndianKey: isBigEndian,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsNonInterleaved: false
                ],sourceFormatHint: CMFormatDescription(audioStreamBasicDescription: audioStreamBasicDescription))
            audioInput!.expectsMediaDataInRealTime = true
            guard writer.canAdd(audioInput!) else {
                Debug.error("VideoWriter can't add audio input")
                throw Error.audioInputError
            }
            writer.add(audioInput!)
        }
        
        if options.contains(element: .video) {
            videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: size.width,
                    AVVideoHeightKey: size.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: size.surface * fps * 0.11,    // ~ 11% of the surface = 13.5MB/s at 1080p 60fps
                        AVVideoExpectedSourceFrameRateKey: fps,
                        AVVideoMaxKeyFrameIntervalKey: fps,
                    ],
                ])
            videoInput!.mediaTimeScale = timeScale
            videoInput!.expectsMediaDataInRealTime = true
            guard writer.canAdd(videoInput!) else {
                Debug.error("VideoWriter can't add video input")
                throw Error.videoInputError
            }
            writer.add(videoInput!)
        }
        onChanged.dispatch(self.status)
    }
    
    func start() -> Bool {
        var r:Bool = false
        queue.sync {
            startTime = nil
            r = writer.startWriting()
            onChanged.dispatch(self.status)
        }
        return r
    }
    
    deinit {
        Debug.info("VideoWriter released")
    }
    
    public func stop() {
        queue.sync {
            let lock = DispatchGroup()
            lock.enter()
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            self.writer.finishWriting {
                lock.leave()
            }
            lock.wait()
            self.onChanged.dispatch(self.status)
        }
    }
    
    public func close() {
        self.onChanged.removeAll()
    }
    
    private func startSession() {
        self.writer.startSession(atSourceTime: CMTime(seconds: 0, preferredTimescale: self.timeScale))
        self.startTime = ß.time
        self.videoFrames = 0
        self.audioSamples = 0
        self.onChanged.dispatch(self.status)
    }
    
    public func write(pixels:CVPixelBuffer) {
        queue.async { [weak self] in
            self?.queuedWrite(pixels: pixels)
        }
    }
    private func queuedWrite(pixels:CVPixelBuffer) {
        if startTime == nil {
            startSession()
        }
        guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData else { return }
        do {
            let time = CMTime(value: Int64(Double(timeScale)*Double(videoFrames)/fps), timescale: timeScale)
            let duration = CMTime(value: Int64(Double(timeScale)/fps), timescale: timeScale)
            let timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: time, decodeTimeStamp: time)
            // https://forums.developer.apple.com/forums/thread/92020
            let videoBuffer = try videoSampleBuffer(timing: timing, pixels: pixels)
            videoInput.append(videoBuffer)
            if status != .writing {
                Debug.error("ViewWriter videoSample error \(status)")
                onChanged.dispatch(self.status)
            }
            videoFrames += 1
        } catch {
            Debug.error("VideoWriter videoSample error: \(error)")
            onChanged.dispatch(self.status)
        }
    }
    
    private func videoSampleBuffer(timing: CMSampleTimingInfo, pixels:CVPixelBuffer) throws -> CMSampleBuffer {
        let format = try CMVideoFormatDescription(imageBuffer: pixels)
        let buffer = try CMSampleBuffer(imageBuffer: pixels, formatDescription: format, sampleTiming: timing)
        return buffer
    }
    
    public func write(pcm: [Float]) {
        queue.async { [weak self] in
            self?.queudWrite(pcm: pcm)
        }
    }
    private func queudWrite(pcm: [Float]) {
        if startTime == nil {
            startSession()
        }
        guard audioInput?.isReadyForMoreMediaData ?? false else { return }
        do {
            let nsamples = pcm.count / 2
            let time = CMTime(value: Int64(Int(timeScale)*audioSamples/44100), timescale: timeScale)
            let duration = CMTime(value: Int64(Int(timeScale)*nsamples/44100), timescale: timeScale)
            let timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: time, decodeTimeStamp: time)
            let audioBuffer = try audioSampleBuffer(timing: timing, pcm: pcm)
            audioInput?.append(audioBuffer)
            if status != .writing {
                Debug.error("ViewWriter audioSample error \(status)")
                onChanged.dispatch(self.status)
            }
            audioSamples += nsamples
        } catch {
            Debug.error("VideoWriter audioSample error: \(error)")
            onChanged.dispatch(self.status)
        }
    }
    private func audioSampleBuffer(timing: CMSampleTimingInfo, pcm: [Float]) throws -> CMSampleBuffer {
        let format = try CMFormatDescription(audioStreamBasicDescription: audioStreamBasicDescription)
        // https://developer.apple.com/documentation/coremedia/cmblockbuffer
        // TODO: check https://gist.github.com/aibo-cora/c57d1a4125e145e586ecb61ebecff47c
        let byteCount = pcm.count*MemoryLayout<Float>.stride
        let ptr = UnsafeMutableRawBufferPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<Float>.alignment)
        ptr.baseAddress!.copyMemory(from: pcm, byteCount: byteCount)
        let block = try CMBlockBuffer(buffer: ptr, allocator: kCFAllocatorDefault)
        let buffer = try CMSampleBuffer(dataBuffer: block, formatDescription: format, numSamples: 1, sampleTimings: [timing], sampleSizes: [pcm.count])
        return buffer
    }
    
    public enum Error : Swift.Error {
        case noOptions,videoInputError,audioInputError
    }
    public enum Status : CustomStringConvertible, Equatable {
        static func == (lhs: VideoWriter.Status, rhs: VideoWriter.Status) -> Bool {
            return lhs.description == rhs.description
        }
        case unknown,writing,completed,cancelled
        case failed(error:Swift.Error)
        public var description: String {
            switch self {
            case .writing:
                return "Writing"
            case .completed:
                return "Completed"
            case .failed(let error):
                return "Failed \(error)"
            case .cancelled:
                return "Cancelled"
            default:
                return "Unknown"
            }
        }
        static func fromWriter(writer:AVAssetWriter) -> Status {
            switch writer.status {
            case .writing:
                return .writing
            case .completed:
                return .completed
            case .failed:
                return .failed(error:writer.error!)
            case .cancelled:
                return .cancelled
            default:
                return .unknown
            }
        }
    }
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
