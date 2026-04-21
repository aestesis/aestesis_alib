//
//  Texture2D.swift
//  Alib
//
//  Created by renan jegouzo on 01/03/2016.
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

import CoreGraphics
import Foundation
import Metal

// OSX, iOS, watchOS, tvOS, Linux
#if os(OSX)
    import AppKit
#else
    import UIKit
#endif

// camera: http://stackoverflow.com/questions/37445052/how-to-create-a-mtltexture-backed-by-a-cvpixelbuffer
// hdr: https://github.com/Hi-Rez/Satin/blob/70f576550ecb7a8df8f3121a6a1a4c8939e9c4d8/Source/Utilities/Textures.swift#L114

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class TextureCache {
    var cache: CVMetalTextureCache
    init(device: MTLDevice) {
        var cvmt: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cvmt)
        if result != kCVReturnSuccess {
            fatalError("CVMetalTextureCacheCreate() error: \(result)")
        }
        cache = cvmt!
    }
    func flush() {
        CVMetalTextureCacheFlush(cache, 0)
    }
    func createTexture(pixelBuffer: CVPixelBuffer) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvmt: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, pixelBuffer, nil, MTLPixelFormat.bgra8Unorm, width, height,
            0, &cvmt)
        return cvmt
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class Texture2D: NodeUI {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public enum Format {
        case alpha
        case height
        case bgra
        case rgba16
        case float
        case float2
        var program: Program.Format {
            switch self {
            case .alpha:
                return .alpha
            case .bgra:
                return .bgra
            case .rgba16:
                return .rgba16
            case .height:
                return .height
            case .float:
                return .float
            case .float2:
                return .float2
            }
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public private(set) var texture: MTLTexture?
    public private(set) var pixelBuffer: CVPixelBuffer?
    public private(set) var cvMetalTexture: CVMetalTexture?
    public private(set) var pixels: Size = Size.zero
    public private(set) var pixel: Size = Size.unity
    public private(set) var border: Size = Size.zero
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var ready: Bool {
        return texture != nil
    }
    public var display: Size {
        return Size(
            (pixels.width - border.width * 2) * pixel.width,
            (pixels.height - border.height) * pixel.height)
    }
    public var scale: Size {
        get { return Size.unity / pixel }
        set(s) { pixel = Size.unity / s }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    internal func initialize(from cg: CGImage) {
        if cg.alphaInfo != .premultipliedLast {
            do {
                try self.texture = viewport!.gpu.loader!.newTexture(
                    cgImage: cg, options: [.SRGB: false])
                pixels.width = Double(texture!.width)
                pixels.height = Double(texture!.height)
                return
            } catch {
                Debug.error("can't create texture from CGImage", #file, #line)
            }
        }
        let pixfmt = MTLPixelFormat.bgra8Unorm
        self.pixels = Size(Double(cg.width), Double(cg.height))
        let d = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixfmt, width: cg.width, height: cg.height, mipmapped: false)
        d.usage = .shaderRead
        self.texture = viewport!.gpu.device?.makeTexture(descriptor: d)
        let isize = cg.width * cg.height
        if let data = cg.dataProvider?.data {
            let len = CFDataGetLength(data)
            if len >= isize * 4 {
                //let ptr = UnsafeMutableRawPointer(mutating:buf).assumingMemoryBound(to: UInt8.self)
                let bytes = CFDataGetBytePtr(data)
                switch cg.alphaInfo {
                case .noneSkipLast, .last:
                    //self.set(raw:bytes!)
                    var buf = [UInt8](repeating: 0, count: len)
                    var s = bytes!
                    var d = 0
                    for _ in 0..<isize {
                        let r: Int = Int(s[0])
                        let g: Int = Int(s[1])
                        let b: Int = Int(s[2])
                        let a: Int = Int(s[3])
                        buf[d] = UInt8(b)
                        d += 1
                        buf[d] = UInt8(g)
                        d += 1
                        buf[d] = UInt8(r)
                        d += 1
                        buf[d] = UInt8(a)
                        d += 1
                        s = s.advanced(by: 4)
                    }
                    buf.withUnsafeBytes { bytes in
                        self.set(raw: bytes.baseAddress!)
                    }
                case .premultipliedLast:
                    var buf = [UInt8](repeating: 0, count: len)
                    var s = bytes!
                    var d = 0
                    for _ in 0..<isize {
                        let r: Int = Int(s[0])
                        let g: Int = Int(s[1])
                        let b: Int = Int(s[2])
                        let a: Int = Int(s[3])
                        if a > 0 {
                            buf[d] = UInt8(min(b * 255 / a, 255))
                            d += 1
                            buf[d] = UInt8(min(g * 255 / a, 255))
                            d += 1
                            buf[d] = UInt8(min(r * 255 / a, 255))
                            d += 1
                            buf[d] = UInt8(a)
                            d += 1
                        } else {
                            buf[d] = UInt8(b)
                            d += 1
                            buf[d] = UInt8(g)
                            d += 1
                            buf[d] = UInt8(r)
                            d += 1
                            buf[d] = UInt8(a)
                            d += 1
                        }
                        s = s.advanced(by: 4)
                    }
                    buf.withUnsafeBytes { bytes in
                        self.set(raw: bytes.baseAddress!)
                    }
                default:
                    Debug.notImplemented(#file, #line)
                }
            } else if len == isize {  // 8 bits
                let bytes = CFDataGetBytePtr(data)
                var buf = [UInt8](repeating: 0, count: len * 4)
                var s = bytes!
                var d = 0
                for _ in 0..<isize {
                    let v: UInt8 = s[0]
                    buf[d] = v
                    d += 1
                    buf[d] = v
                    d += 1
                    buf[d] = v
                    buf[d] = v
                    d += 1
                    buf[d] = 255
                    d += 1
                    s = s.advanced(by: 1)
                }
                buf.withUnsafeBytes { bytes in
                    self.set(raw: bytes.baseAddress!)
                }
            } else {
                Debug.error(
                    "image source error: expected \(isize*4) or \(isize) and got \(len) bytes")
            }
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    internal func load(_ filename: String, bundle: Bundle = Bundle.main) {
        #if os(iOS) || os(tvOS)
            if let ui = UIImage(contentsOfFile: Application.resourcePath(filename, bundle: bundle)),
                let cg = ui.cgImage
            {
                if viewport != nil && ui.size.width != 0 && ui.size.height != 0 {
                    initialize(from: cg)
                } else if viewport == nil {
                    Debug.error(
                        "can't load texture: \(filename), Texture already detached (no viewport)",
                        #file, #line)
                } else {
                    Debug.error("can't load texture: \(filename), file not found)", #file, #line)
                }
            } else {
                Debug.error("can't load texture: \(filename), file not found)", #file, #line)
            }
        #else
            if let ns = NSImage(contentsOfFile: Application.resourcePath(filename, bundle: bundle)),
                let cg = ns.cgImage(forProposedRect: nil, context: nil, hints: nil)
            {
                if viewport != nil && ns.size.width != 0 && ns.size.height != 0 {
                    initialize(from: cg)
                } else if viewport == nil {
                    Debug.error(
                        "can't load texture: \(filename), Texture detached (no viewport)", #file,
                        #line)
                } else {
                    Debug.error("can't load texture: \(filename), file not found)", #file, #line)
                }
            } else {
                Debug.error("can't load texture: \(filename), file not found)", #file, #line)
            }
        #endif
        // decode displaysize&scale from filename eg:  filename.134x68.png -> display=Size(134,68)
        let m = filename.split(".")
        var n = 2
        while m.count > n {
            let s = m[m.count - n]
            //Debug.info(s)
            let ss = s.split("x")
            if ss.count == 2 {
                if let w = Int(ss[0]), let h = Int(ss[1]) {
                    pixel.width = Double(w) / pixels.width
                    pixel.height = Double(h) / pixels.height
                }
            }
            n += 1
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    internal func load(_ data: Foundation.Data) {
        // https://developer.apple.com/reference/coregraphics/cgimage/1455149-init load image without premutiplied alpha
        #if os(iOS) || os(tvOS)
            if let ui = UIImage(data: data), let cg = ui.cgImage {
                if viewport != nil {
                    initialize(from: cg)
                } else {
                    Debug.error("can't load texture: Texture detached (no viewport)", #file, #line)
                }
            } else {
                Debug.error("can't load texture: wrong data", #file, #line)
            }
        #else
            if let ns = NSImage(data: data),
                let cg = ns.cgImage(forProposedRect: nil, context: nil, hints: nil)
            {
                if viewport != nil {
                    initialize(from: cg)
                } else {
                    Debug.error("can't load texture: Texture detached (no viewport)", #file, #line)
                }
            } else {
                Debug.error("can't load texture: wrong data", #file, #line)
            }
        #endif
    }

    public var cgImage: CGImage? {
        guard let texture = texture else { return nil }
        guard let image = CIImage(mtlTexture: texture, options: nil) else { return nil }
        let flipped = image.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
        return CIContext().createCGImage(
            flipped,
            from: flipped.extent,
            format: CIFormat.RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!)
    }

    #if os(iOS) || os(tvOS)
        public var system: UIImage? {
            if let cg = self.cgImage {
                return UIImage(cgImage: cg)
            }
            return nil
        }
    #elseif os(OSX)
        public var system: NSImage? {
            if let cg = self.cgImage {
                return NSImage(
                    cgImage: cg, size: NSSize(width: CGFloat(cg.width), height: CGFloat(cg.height)))
            }
            return nil
        }
    #endif
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    #if DEBUG
        let dbgInfo: String
        override public var debugDescription: String {
            return dbgInfo
        }
    #endif
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    static func metal(format: Format) -> MTLPixelFormat {
        switch format {
        case .alpha:
            return MTLPixelFormat.r8Unorm
        case .bgra:
            return MTLPixelFormat.bgra8Unorm
        case .height:
            return MTLPixelFormat.r16Unorm
        case .rgba16:
            return MTLPixelFormat.rgba16Unorm
        case .float:
            return MTLPixelFormat.r32Float
        case .float2:
            return MTLPixelFormat.rg32Float
        }
    }
    public var format: Format {
        if let t = texture {
            switch t.pixelFormat {
            case .r8Unorm:
                return .alpha
            case .r16Unorm:
                return .height
            case .bgra8Unorm, .bgra8Unorm_srgb:
                return .bgra
            case .r32Float:
                return .float
            case .rg32Float:
                return .float2
            case .rgba16Unorm:
                return .rgba16
            default:
                fatalError("unknow format")
            }
        }
        return .bgra
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public init(parent: NodeUI, pixelBuffer: CVPixelBuffer, file: String = #file, line: Int = #line)
    {
        #if DEBUG
            self.dbgInfo = "Texture.init(file:'\(file)',line:\(line))"
        #endif
        super.init(parent: parent)
        guard let textureCache = textureCache else {
            fatalError("no texture cache")
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let cvmt = textureCache.createTexture(pixelBuffer: pixelBuffer)
        guard let cvmt = cvmt, let mt = CVMetalTextureGetTexture(cvmt) else {
            fatalError("CVMetalTextureCacheCreateTextureFromImage error")
        }
        self.texture = mt
        self.pixelBuffer = pixelBuffer
        self.cvMetalTexture = cvmt
        self.pixels = Size(width, height)
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public init(parent: NodeUI, texture: Texture2D, file: String = #file, line: Int = #line) {
        #if DEBUG
            self.dbgInfo = "Texture.init(file:'\(file)',line:\(line))"
        #endif
        self.pixels = texture.pixels
        if texture.texture == nil {
            Debug.error("Texture2D from texture, nil value")
        }
        self.texture = texture.texture
        self.pixelBuffer = texture.pixelBuffer
        super.init(parent: parent)
        self.scale = texture.scale
        for p in texture.prop {
            prop[p.key] = p.value
        }
    }
    public init(
        parent: NodeUI, size: Size, scale: Size = Size(1, 1), texture: MTLTexture,
        file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
            self.dbgInfo = "Texture.init(file:'\(file)',line:\(line))"
        #endif
        self.pixels = size * scale
        self.texture = texture
        super.init(parent: parent)
        self.scale = scale
    }
    public init(
        parent: NodeUI, size: Size, scale: Size = Size(1, 1), border: Size = Size.zero,
        format: Format = .bgra, shared: Bool = false, file: String = #file, line: Int = #line
    ) {
        #if DEBUG
            self.dbgInfo = "Texture.init(file:'\(file)',line:\(line))"
        #endif
        let pixfmt = Texture2D.metal(format: format)
        self.pixels = size * scale
        super.init(parent: parent)
        self.scale = scale
        let d = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixfmt, width: Int(self.pixels.width), height: Int(self.pixels.height),
            mipmapped: false)
        //d.textureType = .Type2DMultisample // TODO: implement multisampled texture http://stackoverflow.com/questions/36227209/multi-sampling-jagged-edges-in-metalios
        d.usage = [.shaderRead, .renderTarget, .shaderWrite]
        if shared {
            if format != .bgra {
                fatalError("unimplemented format")
            }
            guard
                let ioSurface = IOSurfaceCreate(
                    [
                        kIOSurfaceWidth: Int(pixels.width),
                        kIOSurfaceHeight: Int(pixels.height),
                        kIOSurfaceBytesPerElement: 4,
                        kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA,
                    ] as [CFString: Any] as CFDictionary)
            else {
                fatalError("IOSurfaceCreate error.")
            }

            var pixelBuf: Unmanaged<CVPixelBuffer>?
            guard
                CVPixelBufferCreateWithIOSurface(
                    kCFAllocatorDefault,
                    ioSurface,
                    [kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary,
                    &pixelBuf) == kCVReturnSuccess
            else {
                fatalError("CVPixelBufferCreateWithIOSurface create CVPixelBuffer error")
            }
            pixelBuffer = pixelBuf?.takeUnretainedValue()
            var cvmt: CVMetalTexture?
            guard let textureCache = textureCache else { return }
            guard
                CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    textureCache.cache,
                    pixelBuf!.takeUnretainedValue(),
                    nil,
                    .bgra8Unorm,
                    Int(pixels.width),
                    Int(pixels.height),
                    0,
                    &cvmt) == kCVReturnSuccess
            else {
                fatalError(
                    "CVMetalTextureCacheCreateTextureFromImage bind CVPixelBuffer to CVMetalTexture error"
                )
            }
            guard let cvmt = cvmt, let mt = CVMetalTextureGetTexture(cvmt) else {
                fatalError("CVMetalTextureGetTexture bind CVMetalTexture to MTLTexture error")
            }
            self.cvMetalTexture = cvmt
            self.texture = mt
        } else {
            self.texture = viewport!.gpu.device?.makeTexture(descriptor: d)
        }
    }
    public init(
        parent: NodeUI, path: String, border: Size = Size.zero, bundle: Bundle = Bundle.main,
        file: String = #file, line: Int = #line
    ) {
        #if DEBUG
            self.dbgInfo = "Texture.init(file:'\(file)',line:\(line))"
        #endif
        self.border = border
        super.init(parent: parent)
        load(path, bundle: bundle)
    }
    public init(
        parent: NodeUI, cg: CGImage, scale: Size = Size(1, 1), file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
            self.dbgInfo = "Texture.init(file:'\(file)',line:\(line))"
        #endif
        super.init(parent: parent)
        //self.initialize(from:cg)
        do {
            try self.texture = viewport!.gpu.loader!.newTexture(cgImage: cg, options: nil)
            pixels.width = Double(texture!.width)
            pixels.height = Double(texture!.height)
            self.scale = scale
        } catch {
            Debug.error("can't create texture from CGImage", #file, #line)
        }
    }
    public init(parent: NodeUI, data: [UInt8], file: String = #file, line: Int = #line) {
        #if DEBUG
            self.dbgInfo = "Texture.init(file:'\(file)',line:\(line))"
        #endif
        super.init(parent: parent)
        var d = data
        d.withUnsafeMutableBytes { bytes in
            let d = Data(
                bytesNoCopy: bytes.baseAddress!, count: bytes.count,
                deallocator: Data.Deallocator.none)
            load(d)
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    override open func detach() {
        texture = nil
        pixelBuffer = nil
        cvMetalTexture = nil
        textureCache?.flush()
        super.detach()
    }
    /*
#if DEBUG
    deinit {
        if parent != nil {
            Debug.warning(">>> undetached Texture2D >>> \(dbgInfo) \(dbgdesc ?? "")")
        }
    }
#endif
     */
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func get<T>() -> [T]? where T: SIMD {
        if let t = texture {
            var data = [T](repeating: T(), count: t.width * t.height)
            data.withUnsafeMutableBytes { bytes in
                t.getBytes(
                    bytes.baseAddress!, bytesPerRow: t.width * MemoryLayout<T>.stride,
                    from: MTLRegion(
                        origin: MTLOrigin(x: 0, y: 0, z: 0),
                        size: MTLSize(width: t.width, height: t.height, depth: 1)), mipmapLevel: 0)
            }
            return data
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
        return nil
    }
    public func get() -> [UInt32]? {
        if let t = texture {
            var data = [UInt32](repeating: 0, count: t.width * t.height)
            data.withUnsafeMutableBytes { bytes in
                t.getBytes(
                    bytes.baseAddress!, bytesPerRow: t.width * 4,
                    from: MTLRegion(
                        origin: MTLOrigin(x: 0, y: 0, z: 0),
                        size: MTLSize(width: t.width, height: t.height, depth: 1)), mipmapLevel: 0)
            }
            return data
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
        return nil
    }
    public func get(pixel p: Point) -> Color {
        if let t = texture {
            var data = [UInt32](repeating: 0, count: 1)
            data.withUnsafeMutableBytes { bytes in
                t.getBytes(
                    bytes.baseAddress!, bytesPerRow: t.width * 4,
                    from: MTLRegion(
                        origin: MTLOrigin(x: Int(p.x), y: Int(p.y), z: 0),
                        size: MTLSize(width: 1, height: 1, depth: 1)), mipmapLevel: 0)
            }
            return Color(bgra: data[0])
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
        return Color.transparent
    }
    public func set<T>(pixels data: [T]) where T: SIMD {
        if let t = texture {
            assert(data.count == t.width * t.height)
            switch self.format {
            case .float2:
                data.withUnsafeBytes { bytes in
                    t.replace(
                        region: MTLRegion(
                            origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: t.width, height: t.height, depth: 1)),
                        mipmapLevel: 0,
                        withBytes: bytes.baseAddress!, bytesPerRow: t.width * MemoryLayout<T>.stride
                    )
                }
            default:
                Debug.error("invalid texture format", #file, #line)
            }
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
    }
    public func set(pixels data: [Float32]) {
        if let t = texture {
            switch self.format {
            case .float2:
                assert(data.count == t.width * t.height * 2)
                data.withUnsafeBytes { bytes in
                    t.replace(
                        region: MTLRegion(
                            origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: t.width, height: t.height, depth: 1)),
                        mipmapLevel: 0,
                        withBytes: bytes.baseAddress!,
                        bytesPerRow: t.width * MemoryLayout<Float32>.stride * 2)
                }
            case .float:
                assert(data.count == t.width * t.height)
                data.withUnsafeBytes { bytes in
                    t.replace(
                        region: MTLRegion(
                            origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: t.width, height: t.height, depth: 1)),
                        mipmapLevel: 0,
                        withBytes: bytes.baseAddress!,
                        bytesPerRow: t.width * MemoryLayout<Float32>.stride)
                }
            default:
                Debug.error("invalid texture format", #file, #line)
            }
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
    }
    public func set(pixels data: [UInt32]) {
        if let t = texture {
            if self.format == .bgra {
                assert(data.count == t.width * t.height)
                data.withUnsafeBytes { bytes in
                    t.replace(
                        region: MTLRegion(
                            origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: t.width, height: t.height, depth: 1)),
                        mipmapLevel: 0,
                        withBytes: bytes.baseAddress!, bytesPerRow: t.width * 4)
                }
            } else {
                Debug.error("invalid texture format")
            }
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
    }
    public func set(pixels data: [UInt16]) {
        if let t = texture {
            if self.format == .height {
                assert(data.count == t.width * t.height)
                data.withUnsafeBytes { bytes in
                    t.replace(
                        region: MTLRegion(
                            origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: t.width, height: t.height, depth: 1)),
                        mipmapLevel: 0,
                        withBytes: bytes.baseAddress!, bytesPerRow: t.width * 2)
                }
            } else {
                Debug.error("invalid texture format", #file, #line)
            }
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
    }
    public func set(pixels data: [UInt8]) {
        if let t = texture {
            if self.format == .alpha {
                assert(data.count == t.width * t.height)
                data.withUnsafeBytes { bytes in
                    t.replace(
                        region: MTLRegion(
                            origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: t.width, height: t.height, depth: 1)),
                        mipmapLevel: 0,
                        withBytes: bytes.baseAddress!, bytesPerRow: t.width)
                }
            } else {
                Debug.error("invalid texture format", #file, #line)
            }
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
    }
    public func set(raw data: UnsafeRawPointer) {
        if let t = texture {
            if t.pixelFormat == .bgra8Unorm {
                t.replace(
                    region: MTLRegion(
                        origin: MTLOrigin(x: 0, y: 0, z: 0),
                        size: MTLSize(width: t.width, height: t.height, depth: 1)), mipmapLevel: 0,
                    withBytes: data, bytesPerRow: t.width * 4)
            } else if t.pixelFormat == .a8Unorm {
                t.replace(
                    region: MTLRegion(
                        origin: MTLOrigin(x: 0, y: 0, z: 0),
                        size: MTLSize(width: t.width, height: t.height, depth: 1)), mipmapLevel: 0,
                    withBytes: data, bytesPerRow: t.width)
            } else {
                Debug.error("invalid texture format", #file, #line)
            }
        } else {
            Debug.error(Error("no texture", #file, #line))
        }
    }
    public func set(
        from texture: Texture2D, completion: @escaping (RenderPass.Result) -> Void = { _ in }
    ) {
        if pixels == texture.pixels, let mt = texture.texture {
            let cb = viewport!.gpu.queue.makeCommandBuffer()
            let blit = cb?.makeBlitCommandEncoder()
            blit?.copy(from: mt, to: self.texture!)
            blit?.endEncoding()
            cb?.addCompletedHandler { cb in
                if cb.status == .error {
                    if cb.error!.localizedDescription.lowercased().contains("discarded") {
                        completion(.discarded)
                    } else {
                        completion(.error(message: cb.error!.localizedDescription.lowercased()))
                    }
                } else {
                    completion(.success)
                }
            }
            cb?.commit()
        } else {
            Debug.error(Error("mismatch texture size", #file, #line))
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func pngData() -> Data {
        guard let cgImage = cgImage else {
            fatalError("Texture2D.cgImage returned nil")
        }
        return cgImage.pngData()
    }
    public func jpegData() -> Data {
        guard let cgImage = cgImage else {
            fatalError("Texture2D.cgImage returned nil")
        }
        return cgImage.jpegData()
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
