// Copyright © 2014-2019 the Surge contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Accelerate
import Foundation

// MARK: - Fast Fourier Transform

// TODO: import surge with cocoa https://github.com/Jounce/Surge
/*
public func fft(_ input: [Float]) -> [Float] {
    var real = [Float](input)
    var imaginary = [Float](repeating: 0.0, count: input.count)

    return real.withUnsafeMutableBufferPointer { realBuffer in
        imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
            var splitComplex = DSPSplitComplex(
                realp: realBuffer.baseAddress!,
                imagp: imaginaryBuffer.baseAddress!
            )

            let length = vDSP_Length(floor(log2(Float(input.count))))
            let radix = FFTRadix(kFFTRadix2)
            let weights = vDSP_create_fftsetup(length, radix)
            withUnsafeMutablePointer(to: &splitComplex) { splitComplex in
                vDSP_fft_zip(weights!, splitComplex, 1, length, FFTDirection(FFT_FORWARD))
            }

            var magnitudes = [Float](repeating: 0.0, count: input.count)
            withUnsafePointer(to: &splitComplex) { splitComplex in
                magnitudes.withUnsafeMutableBufferPointer { magnitudes in
                    vDSP_zvmags(splitComplex, 1, magnitudes.baseAddress!, 1, vDSP_Length(input.count))
                }
            }

            var normalizedMagnitudes = [Float](repeating: 0.0, count: input.count)
            normalizedMagnitudes.withUnsafeMutableBufferPointer { normalizedMagnitudes in
                vDSP_vsmul(sqrt(magnitudes), 1, [2.0 / Float(input.count)], normalizedMagnitudes.baseAddress!, 1, vDSP_Length(input.count))
            }

            vDSP_destroy_fftsetup(weights)

            return normalizedMagnitudes
        }
    }
}

public func fft(_ input: [Double]) -> [Double] {
    var real = [Double](input)
    var imaginary = [Double](repeating: 0.0, count: input.count)

    return real.withUnsafeMutableBufferPointer { realBuffer in
        imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
            var splitComplex = DSPDoubleSplitComplex(
                realp: realBuffer.baseAddress!,
                imagp: imaginaryBuffer.baseAddress!
            )

            let length = vDSP_Length(floor(log2(Float(input.count))))
            let radix = FFTRadix(kFFTRadix2)
            let weights = vDSP_create_fftsetupD(length, radix)
            withUnsafeMutablePointer(to: &splitComplex) { splitComplex in
                vDSP_fft_zipD(weights!, splitComplex, 1, length, FFTDirection(FFT_FORWARD))
            }

            var magnitudes = [Double](repeating: 0.0, count: input.count)
            withUnsafePointer(to: &splitComplex) { splitComplex in
                magnitudes.withUnsafeMutableBufferPointer { magnitudes in
                    vDSP_zvmagsD(splitComplex, 1, magnitudes.baseAddress!, 1, vDSP_Length(input.count))
                }
            }

            var normalizedMagnitudes = [Double](repeating: 0.0, count: input.count)
            normalizedMagnitudes.withUnsafeMutableBufferPointer { normalizedMagnitudes in
                vDSP_vsmulD(sqrt(magnitudes), 1, [2.0 / Double(input.count)], normalizedMagnitudes.baseAddress!, 1, vDSP_Length(input.count))
            }

            vDSP_destroy_fftsetupD(weights)

            return normalizedMagnitudes
        }
    }
}

// MARK: - Square Root
/// Elemen-wise square root.
///
/// - Warning: does not support memory stride (assumes stride is 1).
public func sqrt<L>(_ lhs: L) -> [Float] where L: UnsafeMemoryAccessible, L.Element == Float {
    return withArray(from: lhs) { sqrtInPlace(&$0) }
}

/// Elemen-wise square root.
///
/// - Warning: does not support memory stride (assumes stride is 1).
public func sqrt<L>(_ lhs: L) -> [Double] where L: UnsafeMemoryAccessible, L.Element == Double {
    return withArray(from: lhs) { sqrtInPlace(&$0) }
}

/// Elemen-wise square root with custom output storage.
///
/// - Warning: does not support memory stride (assumes stride is 1).
public func sqrt<MI: UnsafeMemoryAccessible, MO>(_ lhs: MI, into results: inout MO) where MO: UnsafeMutableMemoryAccessible, MI.Element == Float, MO.Element == Float {
    return lhs.withUnsafeMemory { lm in
        results.withUnsafeMutableMemory { rm in
            precondition(lm.stride == 1 && rm.stride == 1, "sqrt doesn't support step values other than 1")
            precondition(rm.count >= lm.count, "`results` doesnt have enough capacity to store the results")
            vvsqrtf(rm.pointer, lm.pointer, [numericCast(lm.count)])
        }
    }
}

/// Elemen-wise square root with custom output storage.
///
/// - Warning: does not support memory stride (assumes stride is 1).
public func sqrt<MI: UnsafeMemoryAccessible, MO>(_ lhs: MI, into results: inout MO) where MO: UnsafeMutableMemoryAccessible, MI.Element == Double, MO.Element == Double {
    return lhs.withUnsafeMemory { lm in
        results.withUnsafeMutableMemory { rm in
            precondition(lm.stride == 1 && rm.stride == 1, "sqrt doesn't support step values other than 1")
            precondition(rm.count >= lm.count, "`results` doesnt have enough capacity to store the results")
            vvsqrt(rm.pointer, lm.pointer, [numericCast(lm.count)])
        }
    }
}

// MARK: - Square Root: In Place
/// Elemen-wise square root.
///
/// - Warning: does not support memory stride (assumes stride is 1).
func sqrtInPlace<L>(_ lhs: inout L) where L: UnsafeMutableMemoryAccessible, L.Element == Float {
    var elementCount: Int32 = numericCast(lhs.count)
    lhs.withUnsafeMutableMemory { lm in
        precondition(lm.stride == 1, "\(#function) doesn't support step values other than 1")
        vvsqrtf(lm.pointer, lm.pointer, &elementCount)
    }
}

/// Elemen-wise square root.
///
/// - Warning: does not support memory stride (assumes stride is 1).
func sqrtInPlace<L>(_ lhs: inout L) where L: UnsafeMutableMemoryAccessible, L.Element == Double {
    var elementCount: Int32 = numericCast(lhs.count)
    lhs.withUnsafeMutableMemory { lm in
        precondition(lm.stride == 1, "\(#function) doesn't support step values other than 1")
        vvsqrt(lm.pointer, lm.pointer, &elementCount)
    }
}

/// Memory region.
public struct UnsafeMemory<Element>: Sequence {
    /// Pointer to the first element
    public var pointer: UnsafePointer<Element>

    /// Pointer stride between elements
    public var stride: Int

    /// Number of elements
    public var count: Int

    public init(pointer: UnsafePointer<Element>, stride: Int = 1, count: Int) {
        self.pointer = pointer
        self.stride = stride
        self.count = count
    }

    public func makeIterator() -> UnsafeMemoryIterator<Element> {
        return UnsafeMemoryIterator(self)
    }
}

public struct UnsafeMemoryIterator<Element>: IteratorProtocol {
    let base: UnsafeMemory<Element>
    var index: Int?

    public init(_ base: UnsafeMemory<Element>) {
        self.base = base
    }

    public mutating func next() -> Element? {
        let newIndex: Int
        if let index = index {
            newIndex = index + 1
        } else {
            newIndex = 0
        }

        if newIndex >= base.count {
            return nil
        }

        self.index = newIndex
        return base.pointer[newIndex * base.stride]
    }
}

/// Protocol for collections that can be accessed via `UnsafeMemory`
public protocol UnsafeMemoryAccessible: Collection {
    func withUnsafeMemory<Result>(_ body: (UnsafeMemory<Element>) throws -> Result) rethrows -> Result
}

public func withUnsafeMemory<L, Result>(_ lhs: L, _ body: (UnsafeMemory<L.Element>) throws -> Result) rethrows -> Result where L: UnsafeMemoryAccessible {
    return try lhs.withUnsafeMemory(body)
}

public func withUnsafeMemory<L, R, Result>(_ lhs: L, _ rhs: R, _ body: (UnsafeMemory<L.Element>, UnsafeMemory<R.Element>) throws -> Result) rethrows -> Result where L: UnsafeMemoryAccessible, R: UnsafeMemoryAccessible {
    return try lhs.withUnsafeMemory { lhsMemory in
        try rhs.withUnsafeMemory { rhsMemory in
            try body(lhsMemory, rhsMemory)
        }
    }
}
*/
