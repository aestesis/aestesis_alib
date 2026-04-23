//
//  AudioAnalyzer.swift
//  Alib
//
//  Created by renan jegouzo on 19/05/2016.
//  Copyright © 2016 aestesis. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Accelerate
import Foundation

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// https://www.ee.columbia.edu/~dpwe/pubs/Ellis07-beattrack.pdf

// FFT: https://developer.apple.com/documentation/accelerate/discrete_fourier_transforms

public class AudioAnalyzer: Atom, @unchecked Sendable {
    static let samplesCount = 4096
    public var maxAmp: Float = 2.0
    var fftProcessor = FFT(count: samplesCount)
    var coamp: Float = 0.5
    var impact: Float = 0.5
    var timestamp: Int = samplesCount
    var peak: Float = 0
    var current = EQ()
    var eqPeak = EQ()
    var correction = EQ()
    var samples = [Float](repeating: 0, count: samplesCount)
    var bass = [Float](repeating: 0, count: samplesCount)
    var medium = [Float](repeating: 0, count: samplesCount)
    var treeble = [Float](repeating: 0, count: samplesCount)
    let lock = Lock()
    var envelope: Double = 0
    var fft: FFT.Result = FFT.Result(count: samplesCount / 2)
    var maxe: Double = 0
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func feed(_ buffer: [Float], offset: Int = 0, count: Int = 0) {
        let lenght = (count > 0) ? count : buffer.count - offset
        let cmedium: Float = max(min(1.0, coamp * 10.0), 0.5)
        let ctreeble: Float = max(min(1.0, coamp * 20.0), 0.5)
        nonisolated(unsafe) var b: Float = 0
        nonisolated(unsafe) var m: Float = 0
        nonisolated(unsafe) var t: Float = 0
        nonisolated(unsafe) var samples = self.samples
        nonisolated(unsafe) var bass = self.bass
        nonisolated(unsafe) var medium = self.medium
        nonisolated(unsafe) var treeble = self.treeble
        nonisolated(unsafe) var ma: Float = 0
        assert(samples.count == AudioAnalyzer.samplesCount)
        assert(bass.count == AudioAnalyzer.samplesCount)
        assert(medium.count == AudioAnalyzer.samplesCount)
        assert(treeble.count == AudioAnalyzer.samplesCount)
        for i in 0..<lenght {
            let vs = buffer[offset + i]
            let vcs = vs * coamp
            let va = abs(vs)
            let vca = va * coamp
            samples.append(vcs)
            ma = max(ma, vca)
            current.low = current.low * 0.9 + vcs * 0.1
            current.medium = current.medium * 0.7 + (vcs - current.low) * 0.3
            current.high = vcs - current.medium - current.low
            bass.append(current.low)
            medium.append(current.medium * cmedium)
            treeble.append(current.high * ctreeble)
            b = max(b, abs(current.low))
            m = max(m, abs(current.medium * cmedium))
            t = max(t, abs(current.high * ctreeble))
        }
        samples = Array(samples[samples.count - AudioAnalyzer.samplesCount..<samples.count])
        bass = Array(bass[bass.count - AudioAnalyzer.samplesCount..<bass.count])
        medium = Array(medium[medium.count - AudioAnalyzer.samplesCount..<medium.count])
        treeble = Array(treeble[treeble.count - AudioAnalyzer.samplesCount..<treeble.count])
        nonisolated(unsafe) let fft =
            fftProcessor.transform(samples: samples)
            ?? FFT.Result(count: AudioAnalyzer.samplesCount / 2)
        nonisolated(unsafe) var enveloppe: Double = 0
        for e in fft.amplitude {
            enveloppe += Double(e)
        }
        enveloppe /= Double(fft.amplitude.count)
        lock.async { [weak self] in
            guard let self = self else { return }
            self.timestamp += lenght
            if ma > 0 {
                self.coamp = min(self.coamp * 0.99 + (self.impact / ma) * 0.01, self.maxAmp)
            }
            self.peak = ma
            self.eqPeak.low = b
            self.eqPeak.medium = m
            self.eqPeak.high = t
            self.samples = samples
            self.bass = bass
            self.medium = medium
            self.treeble = treeble
            self.fft = fft
            self.envelope = 256 * enveloppe
            self.maxe = max(self.maxe, self.envelope)
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func clear() {
        lock.sync {
            self.peak = 0
            self.current = EQ()
            self.eqPeak = EQ()
            self.samples = [Float](repeating: 0, count: AudioAnalyzer.samplesCount)
            self.bass = [Float](repeating: 0, count: AudioAnalyzer.samplesCount)
            self.medium = [Float](repeating: 0, count: AudioAnalyzer.samplesCount)
            self.treeble = [Float](repeating: 0, count: AudioAnalyzer.samplesCount)
            self.envelope = 0.0
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var info: Info {
        var i: Info? = nil
        lock.sync {
            i = Info(analyzer: self)
        }
        return i!
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public init(correction: EQ = EQ(low: 1, medium: 7, high: 15)) {
        super.init()
        self.correction = correction
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public struct Info {
        public let timestamp: Int
        public let peak: Float
        public let eq: EQ
        public let samples: [Float]
        public let bass: [Float]
        public let medium: [Float]
        public let treeble: [Float]
        public let amplification: Float
        public let envelope: Double
        public let fft: FFT.Result
        init(frames: Int) {
            timestamp = 0
            peak = 0
            eq = EQ()
            samples = [Float](repeating: 0, count: frames)
            bass = [Float](repeating: 0, count: frames)
            medium = [Float](repeating: 0, count: frames)
            treeble = [Float](repeating: 0, count: frames)
            amplification = 0
            envelope = 0
            fft = FFT.Result(count: frames / 2)
        }
        init(analyzer a: AudioAnalyzer) {
            timestamp = a.timestamp - a.samples.count
            peak = a.peak
            eq = a.eqPeak
            samples = Array(a.samples)
            bass = Array(a.bass)
            medium = Array(a.medium)
            treeble = Array(a.treeble)
            amplification = a.coamp
            envelope = a.envelope
            fft = a.fft
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class FFT {
    var dsp: vDSP.DiscreteFourierTransform<Float>?
    var imaginary: [Float]?
    init(count: Int) {
        do {
            dsp = try vDSP.DiscreteFourierTransform(
                count: count, direction: .forward, transformType: .complexComplex,
                ofType: Float.self)
            imaginary = [Float](repeating: 0, count: count)
        } catch {
            Debug.error("error initializing FFT DSP \(error)")
        }
    }
    func transform(samples: [Float]) -> Result? {
        guard let dsp = dsp, let imaginary = imaginary else { return nil }
        let normalized = samples.map { $0 / Float(samples.count) }
        let result = dsp.transform(real: normalized, imaginary: imaginary)
        var amp: [Float] = []
        var pha: [Float] = []
        for i in 0..<(result.real.count >> 1) {
            let x = result.real[i]
            let y = result.imaginary[i]
            amp.append(sqrt(x * x + y * y))
            pha.append(atan2(y, x))
        }
        return Result(amplitude: amp, phase: pha)
    }
    public struct Result {
        public let amplitude: [Float]
        public let phase: [Float]
        init(amplitude: [Float] = [], phase: [Float] = []) {
            self.amplitude = amplitude
            self.phase = phase
        }
        init(count: Int) {
            amplitude = [Float](repeating: 0, count: count)
            phase = [Float](repeating: 0, count: count)
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct EQH {
    public var low: Double = 0
    public var medium: Double = 0
    public var high: Double = 0
    public init(low: Double = 0, medium: Double = 0, high: Double = 0) {
        self.low = low
        self.medium = medium
        self.high = high
    }
    public init(_ eq: EQ) {
        self.low = Double(eq.low)
        self.medium = Double(eq.medium)
        self.high = Double(eq.high)
    }
    public init() {
    }
}
public func == (l: EQH, r: EQH) -> Bool {
    return l.high == r.high && l.medium == r.medium && l.low == r.low
}
public func != (l: EQH, r: EQH) -> Bool {
    return l.high != r.high || l.medium != r.medium || l.low != r.low
}
public func += (left: inout EQH, right: EQH) {
    left = left + right
}
public func -= (left: inout EQH, right: EQH) {
    left = left - right
}
public func + (l: EQH, r: EQH) -> EQH {
    return EQH(low: l.low + r.low, medium: l.medium + r.medium, high: l.high + r.high)
}
public func + (l: EQH, r: Double) -> EQH {
    return EQH(low: l.low + r, medium: l.medium + r, high: l.high + r)
}
public func - (l: EQH, r: EQH) -> EQH {
    return EQH(low: l.low - r.low, medium: l.medium - r.medium, high: l.high - r.high)
}
public func - (l: EQH, r: Double) -> EQH {
    return EQH(low: l.low - r, medium: l.medium - r, high: l.high - r)
}
public func * (l: EQH, r: EQH) -> EQH {
    return EQH(low: l.low * r.low, medium: l.medium * r.medium, high: l.high * r.high)
}
public func * (l: EQH, r: Double) -> EQH {
    return EQH(low: l.low * r, medium: l.medium * r, high: l.high * r)
}
public func / (l: EQH, r: EQH) -> EQH {
    return EQH(low: l.low / r.low, medium: l.medium / r.medium, high: l.high / r.high)
}
public func / (l: EQH, r: Double) -> EQH {
    return EQH(low: l.low / r, medium: l.medium / r, high: l.high / r)
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct EQ {
    public var low: Float = 0
    public var medium: Float = 0
    public var high: Float = 0
    public init(low: Float = 0, medium: Float = 0, high: Float = 0) {
        self.low = low
        self.medium = medium
        self.high = high
    }
    public init() {
    }
}
public func == (l: EQ, r: EQ) -> Bool {
    return l.high == r.high && l.medium == r.medium && l.low == r.low
}
public func != (l: EQ, r: EQ) -> Bool {
    return l.high != r.high || l.medium != r.medium || l.low != r.low
}
public func += (left: inout EQ, right: EQ) {
    left = left + right
}
public func -= (left: inout EQ, right: EQ) {
    left = left - right
}
public func + (l: EQ, r: EQ) -> EQ {
    return EQ(low: l.low + r.low, medium: l.medium + r.medium, high: l.high + r.high)
}
public func + (l: EQ, r: Float) -> EQ {
    return EQ(low: l.low + r, medium: l.medium + r, high: l.high + r)
}
public func - (l: EQ, r: EQ) -> EQ {
    return EQ(low: l.low - r.low, medium: l.medium - r.medium, high: l.high - r.high)
}
public func - (l: EQ, r: Float) -> EQ {
    return EQ(low: l.low - r, medium: l.medium - r, high: l.high - r)
}
public func * (l: EQ, r: EQ) -> EQ {
    return EQ(low: l.low * r.low, medium: l.medium * r.medium, high: l.high * r.high)
}
public func * (l: EQ, r: Float) -> EQ {
    return EQ(low: l.low * r, medium: l.medium * r, high: l.high * r)
}
public func / (l: EQ, r: EQ) -> EQ {
    return EQ(low: l.low / r.low, medium: l.medium / r.medium, high: l.high / r.high)
}
public func / (l: EQ, r: Float) -> EQ {
    return EQ(low: l.low / r, medium: l.medium / r, high: l.high / r)
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
