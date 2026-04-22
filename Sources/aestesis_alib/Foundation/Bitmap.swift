//
//  Bitmap.swift
//  Alib
//
//  Created by renan jegouzo on 15/03/2016.
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

import Foundation
import Metal
//import MetalKit
import MetalPerformanceShaders

// OSX, iOS, watchOS, tvOS, Linux
#if os(OSX)
    import AppKit
#else
    import UIKit
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class SharedBitmap: Bitmap, @unchecked Sendable {
    var generandom: Double
    public func updated() {
        generandom = ß.rnd
    }
    public init(
        parent: NodeUI, size: Size, scale: Size = Size(1, 1), border: Size = Size.zero,
        format: Format = .bgra, file: String = #file, line: Int = #line
    ) {
        generandom = ß.rnd
        super.init(
            parent: parent, size: size, scale: scale, border: border, format: format, shared: true,
            file: file, line: line)
    }
    override public init(
        parent: NodeUI, pixelBuffer: CVPixelBuffer, file: String = #file, line: Int = #line
    ) {
        generandom = ß.rnd
        super.init(parent: parent, pixelBuffer: pixelBuffer, file: file, line: line)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class Bitmap: Texture2D, @unchecked Sendable {
    public var size: Size {
        return display
    }
    public var bounds: Rect {
        return Rect(x: 0, y: 0, w: size.w, h: size.h)
    }
    public func blur(
        _ sigma: Double, sampler smp: String = "sampler.clamp", _ fn: @escaping () -> Void
    ) {
        if self.size.width <= 0 || self.size.height <= 0 {
            return
        }
        bg { [weak self] in
            guard let self = self, self.attached else { return }
            let b = Bitmap(parent: self, size: self.size)
            let g = Graphics(image: b)
            g.blurHorizontal(b.bounds, source: self, sigma: sigma, sampler: smp)
            g.onDone { [weak self] _ in
                guard let self = self, self.attached else { return }
                self.bg { [weak self] in
                    guard let self = self, self.attached else { return }
                    let g0 = Graphics(image: self)
                    g0.blurVertical(b.bounds, source: b, sigma: sigma, sampler: smp)
                    g0.onDone { [weak self] _ in
                        guard let self = self else { return }
                        self.bg { [weak self] in
                            guard let self = self, self.attached else { return }
                            fn()
                        }
                        b.detach()
                    }
                }
            }
        }
    }
    public func blurFrom(
        destination rect: Rect? = nil, source: Bitmap, sigma: Double,
        sampler smp: String = "sampler.clamp", _ f: String = #file, _ l: Int = #line,
        _ fn: @escaping () -> Void
    ) {
        guard attached else { return }
        let r = rect ?? self.bounds
        bg { [weak self] in
            guard let self = self, self.attached, source.attached else { return }
            let b = Bitmap(parent: self, size: source.size)
            let g = Graphics(image: b)
            g.blurHorizontal(b.bounds, source: source, sigma: sigma, sampler: smp)
            g.onDone { [weak self] ok in
                guard let self = self, self.attached, source.attached else { return }
                switch ok {
                case .success:
                    self.bg { [weak self] in
                        guard let self = self, self.attached else { return }
                        let g0 = Graphics(image: self)
                        g0.blurVertical(r, source: b, sigma: sigma, sampler: smp)
                        g0.onDone { [weak self] _ in
                            guard let self = self, self.attached else { return }
                            fn()
                            b.detach()
                        }
                    }
                    return
                case .error(let message):
                    Debug.error("Bitmap.blurFrom(), GPU process error \(message)")
                    fallthrough
                default:
                    b.detach()
                }
            }
        }
    }

    public func gaussianBlur(sigma: Double) {
        guard let gpu = viewport?.gpu, var dt = texture, let cb = gpu.queue.makeCommandBuffer()
        else {
            return
        }
        let gaussian = MPSImageGaussianBlur(device: viewport!.gpu.device!, sigma: Float(sigma))
        gaussian.encode(commandBuffer: cb, inPlaceTexture: &dt)
        cb.commit()
        cb.waitUntilCompleted()
        if let e = cb.error {
            Debug.info(e.localizedDescription)
        }
    }
    public func gaussianBlur(source: Bitmap, sigma: Double) {
        guard let gpu = viewport?.gpu, let st = source.texture, let dt = texture,
            let cb = gpu.queue.makeCommandBuffer()
        else {
            return
        }
        let gaussian = MPSImageGaussianBlur(device: viewport!.gpu.device!, sigma: Float(sigma))
        gaussian.encode(commandBuffer: cb, sourceTexture: st, destinationTexture: dt)
        cb.commit()
        cb.waitUntilCompleted()
    }

    public func copy(source: Bitmap) {
        guard size == source.size else {
            fatalError("Bitmap.copy() no size match")
        }
        guard let gpu = viewport?.gpu, let st = source.texture, let dt = texture,
            let cb = gpu.queue.makeCommandBuffer()
        else {
            return
        }
        let blitCommandEncoder = cb.makeBlitCommandEncoder()!
        blitCommandEncoder.copy(
            from: st,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOriginMake(0, 0, 0),
            sourceSize: MTLSizeMake(st.width, st.height, 1),
            to: dt,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOriginMake(0, 0, 0))
        blitCommandEncoder.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
    }

    public func copy() -> Bitmap {
        let b = Bitmap(parent: parent as! NodeUI, size: size)
        b.copy(source: self)
        return b
    }

}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
 custom kernel

 final class Adjustments {

     var temperature: Float = .zero
     var tint: Float = .zero
     private var deviceSupportsNonuniformThreadgroups: Bool
     private let pipelineState: MTLComputePipelineState

     init(library: MTLLibrary) throws {
         self.deviceSupportsNonuniformThreadgroups = library.device.supportsFeatureSet(.iOS_GPUFamily4_v1)
         let constantValues = MTLFunctionConstantValues()
         constantValues.setConstantValue(&self.deviceSupportsNonuniformThreadgroups,
                                         type: .bool,
                                         index: 0)
         let function = try library.makeFunction(name: "adjustments",
                                                 constantValues: constantValues)
         self.pipelineState = try library.device.makeComputePipelineState(function: function)
     }

     func encode(source: MTLTexture,
                 destination: MTLTexture,
                 in commandBuffer: MTLCommandBuffer) {
         guard let encoder = commandBuffer.makeComputeCommandEncoder()
         else { return }

         encoder.setTexture(source,
                            index: 0)
         encoder.setTexture(destination,
                            index: 1)

         encoder.setBytes(&self.temperature,
                          length: MemoryLayout<Float>.stride,
                          index: 0)
         encoder.setBytes(&self.tint,
                          length: MemoryLayout<Float>.stride,
                          index: 1)

         let gridSize = MTLSize(width: source.width,
                                height: source.height,
                                depth: 1)
         let threadGroupWidth = self.pipelineState.threadExecutionWidth
         let threadGroupHeight = self.pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
         let threadGroupSize = MTLSize(width: threadGroupWidth,
                                       height: threadGroupHeight,
                                       depth: 1)

         encoder.setComputePipelineState(self.pipelineState)

         if self.deviceSupportsNonuniformThreadgroups {
             encoder.dispatchThreads(gridSize,
                                     threadsPerThreadgroup: threadGroupSize)
         } else {
             let threadGroupCount = MTLSize(width: (gridSize.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                            height: (gridSize.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                            depth: 1)
             encoder.dispatchThreadgroups(threadGroupCount,
                                          threadsPerThreadgroup: threadGroupSize)
         }

         encoder.endEncoding()
     }

 }

 */
