import Foundation
@preconcurrency import Metal
import MetalKit
import simd

#if os(iOS)
    import UIKit
#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class ComputePass: NodeUI, @unchecked Sendable {
    public enum Result {
        case error(message: String)
        case discarded
        case success
    }
    public private(set) var onDone = Event<Result>()
    let cb: MTLCommandBuffer
    let encoder: MTLComputeCommandEncoder
    override public func detach() {
        onDone.removeAll()
        super.detach()
    }
    init(parent: NodeUI) {
        cb = parent.viewport!.gpu.queue.makeCommandBuffer()!
        encoder = cb.makeComputeCommandEncoder()!
        super.init(parent: parent.viewport)
        cb.addCompletedHandler({ (cb: MTLCommandBuffer) in
            if cb.status == .error {
                if cb.error!.localizedDescription.lowercased().contains("discarded") {
                    self.onDone.dispatch(.discarded)
                } else {
                    self.onDone.dispatch(
                        .error(message: cb.error!.localizedDescription.lowercased()))
                }
            } else {
                self.onDone.dispatch(.success)
            }
            self.detach()
        })
    }
    public func commit() {
        encoder.endEncoding()
        cb.commit()
    }
    public func use(size: MTLSize, threads block: MTLSize) {
        let groups = MTLSizeMake(
            size.width / block.width,
            size.height / block.height,
            size.depth / block.depth)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: block)
    }
    public func use(texture: Texture2D, atIndex index: Int = 0) {
        encoder.setTexture(texture.texture, index: index)
    }
    public func use(texture: Texture3D, atIndex index: Int = 0) {
        encoder.setTexture(texture.texture, index: index)
    }
    public func use(buffer: Buffer, atIndex index: Int = 0) {
        encoder.setBuffer(buffer.b, offset: 0, index: index)
    }
    public func use(bytes: UnsafeRawPointer, lenght: Int, atIndex index: Int = 0) {
        encoder.setBytes(bytes, length: lenght, index: index)
    }
    public func use(kernel: ComputeKernel) {
        encoder.setComputePipelineState(kernel.pipeline)
    }
    public func use(kernel: String) throws {
        if let k = viewport!.gpu.library["kernel.\(kernel)"] as? ComputeKernel {
            use(kernel: k)
        } else {
            let k = try ComputeKernel(viewport: viewport!, kernel: kernel)
            use(kernel: k)
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class ComputeKernel: NodeUI, @unchecked Sendable {
    let function: MTLFunction
    let pipeline: MTLComputePipelineState
    public convenience init(viewport: Viewport, kernel: String) throws {
        try self.init(device: viewport.gpu.device, library: viewport.gpu.library, kernel: kernel)
    }
    public init(device: MTLDevice, library: ProgramLibrary, kernel: String) throws {
        function = library.lib!.makeFunction(name: kernel)!
        pipeline = try device.makeComputePipelineState(function: function)
        super.init(parent: library)
        library["kernel.\(kernel)"] = self
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
