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
    public init(parent: NodeUI) {
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
    public func wait(fence:MTLFence) {
        encoder.waitForFence(fence)
    }
    public func update() -> MTLFence? {
        let fence = viewport?.gpu.device.makeFence()
        if let fence = fence {
            encoder.updateFence(fence)
        }
        return fence
    }
    public func dispatch(size: MTLSize, threads block: MTLSize) {
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
    public func use(kernel: String, library: ProgramLibrary? = nil) throws {
        let l = library ?? viewport!.gpu.library
        let k = try ComputePass.register(kernel: kernel, library: l)
        use(kernel: k)
    }

    public static func register(kernel: String, library: ProgramLibrary) throws -> ComputeKernel {
        guard let viewport = library.viewport else {
            throw ComputePassError.detached
        }
        let key = "kernel.\(library.key).\(kernel)"
        if let k = library[key] as? ComputeKernel {
            return k
        }
        let k = try ComputeKernel(viewport: viewport, library: library, kernel: kernel)
        viewport[key] = k
        return k
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class ComputeKernel: NodeUI, @unchecked Sendable {
    let function: MTLFunction
    let pipeline: MTLComputePipelineState
    public init(viewport: Viewport, library: ProgramLibrary? = nil, kernel: String) throws {
        function = (library ?? viewport.gpu.library).lib!.makeFunction(name: kernel)!
        pipeline = try viewport.gpu.device.makeComputePipelineState(function: function)
        super.init(parent: library)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
enum ComputePassError: Error {
    case detached
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
