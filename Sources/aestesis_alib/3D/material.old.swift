//
//  material.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 12/02/2024.
//

import Foundation

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class MaterialOld: NodeRenderer, @unchecked Sendable {
    var transparent: Bool { return blend != .opaque }
    public private(set) var blend: BlendMode
    var needsUpdate = true
    var ambient: Color {
        didSet {
            needsUpdate = true
        }
    }
    var diffuse: Color {
        didSet {
            needsUpdate = true
        }
    }
    var specular: Color {
        didSet {
            needsUpdate = true
        }
    }
    var shininess: Double {
        didSet {
            needsUpdate = true
        }
    }
    public private(set) var cull: CullMode
    public private(set) var material: Buffer?
    public private(set) var texture: Texture2D?
    public let name: String
    public init(
        parent: NodeUI, name: String, blend: BlendMode = BlendMode.opaque,
        cull: CullMode = CullMode.front, ambient: Color = Color(a: 1, l: 0.05),
        diffuse: Color = Color(a: 1, l: 0.8), specular: Color = Color.white, shininess: Double = 40,
        texture: String = ""
    ) {
        self.name = name
        self.blend = blend
        self.cull = cull
        self.ambient = ambient
        self.diffuse = diffuse
        self.specular = specular
        self.shininess = shininess
        super.init(parent: parent)
        self.material = self.persitentBuffer(MemoryLayout<GPUmaterial>.stride)
        if texture.length > 0 {
            self.io {
                self.texture = Bitmap(parent: self, path: texture)
            }
        }
    }
    public init(
        parent: NodeUI, name: String, blend: BlendMode = BlendMode.opaque,
        cull: CullMode = CullMode.front, ambient: Color = Color(a: 1, l: 0.05),
        diffuse: Color = Color(a: 1, l: 0.8), specular: Color = Color.white, shininess: Double = 40,
        texture: Size
    ) {
        self.name = name
        self.blend = blend
        self.cull = cull
        self.ambient = ambient
        self.diffuse = diffuse
        self.specular = specular
        self.shininess = shininess
        super.init(parent: parent)
        self.material = self.persitentBuffer(MemoryLayout<GPUmaterial>.stride)
        self.texture = Bitmap(parent: self, size: texture)
    }
    override open func detach() {
        if let m = material {
            m.detach()
            material = nil
        }
        if let t = texture {
            t.detach()
            texture = nil
        }
        super.detach()
    }
    public func setTexture(path: String) {
        self.io {
            if let o = self.texture {
                self.ui {
                    o.detach()
                }
            }
            self.texture = Bitmap(parent: self, path: path)
        }
    }
    open func render(to g: Graphics, world: Mat4, vertices: Buffer, faces: Buffer, count: Int) {
        if let material = material, let renderer = self.renderer, let camera = renderer.camera {
            self.updateBuffer()
            let prog = "program.3d.\(renderer.lightsProgram)"
            if let texture = texture, texture.ready {
                g.program("\(prog)texture", blend: blend)
                g.render.use(texture: texture)
            } else {
                g.program("\(prog)basic", blend: blend)
            }
            g.uniforms(view: g.matrix, world: world, eye: camera.worldMatrix.translation)
            self.lights(g: g, startIndex: 2)
            g.render.use(fragmentBuffer: material, atIndex: 0)
            g.render.use(vertexBuffer: vertices, atIndex: 0)
            if blend == .opaque {
                g.depthStencil(state: "3d.depth.lesser")
            } else {
                g.depthStencil(state: "3d.depth.lesser.nowrite")
            }
            g.render.set(cull: self.cull)
            g.render.set(front: .counterClockwise)
            g.render.draw(triangle: count, index: faces)
            g.render.set(cull: .none)
            g.depthStencil(state: "3d.depth.all")
        }
    }
    open func render(to g: Graphics, world: Mat4, particles: Buffer, count: Int) {
        if let material = material, let renderer = self.renderer, let camera = renderer.camera {
            self.updateBuffer()
            let prog = "program.point.3d.\(renderer.lightsProgram)"
            if let texture = texture, texture.ready {
                g.program("\(prog)texture", blend: blend)
                g.render.use(texture: texture)
            } else {
                g.program("\(prog)basic", blend: blend)
            }
            g.uniforms(view: g.matrix, world: world, eye: camera.worldMatrix.translation)
            self.lights(g: g, startIndex: 2)
            g.render.use(fragmentBuffer: material, atIndex: 0)
            g.render.use(vertexBuffer: particles, atIndex: 0)
            g.depthStencil(state: "3d.depth.lesser.nowrite")
            g.render.draw(sprite: count)
            g.depthStencil(state: "3d.depth.all")
        }
    }
    public func updateBuffer() {
        if let material = material, needsUpdate {
            needsUpdate = false
            let gpu = GPUmaterial(
                ambient: ambient.infloat4, diffuse: diffuse.infloat4, specular: specular.infloat4,
                shininess: Float32(shininess))
            let ptr = material.ptr.assumingMemoryBound(to: GPUmaterial.self)
            ptr[0] = gpu
        }
    }
    public func lights(g: Graphics, startIndex index: Int) {
        if let renderer = self.renderer {
            var i = index
            for l in renderer.lights {
                l.use(g: g, atIndex: i)
                i += 1
            }
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class MaterialHeightMap: MaterialOld, @unchecked Sendable {
    struct GPUheight {
        var width: Float32
        var height: Float32
        var scale: Float32
        var adjustNormals: Float32
    }
    public private(set) var height: Texture2D? = nil
    var adjustNormals: Double
    var buffer: Buffer?
    public init(
        parent: NodeUI, name: String, blend: BlendMode = BlendMode.opaque,
        cull: CullMode = CullMode.front, ambient: Color = Color(a: 1, l: 0.05),
        diffuse: Color = Color(a: 1, l: 0.8), specular: Color = Color.white, shininess: Double = 40,
        size: Size, scale: Double, adjustNormals: Double = 1.0
    ) {
        self.adjustNormals = adjustNormals
        super.init(
            parent: parent, name: name, blend: blend, cull: cull, ambient: ambient,
            diffuse: diffuse, specular: specular, shininess: shininess, texture: size)
        self.height = Bitmap(parent: self, size: size)
        self.setBuffer(size: size, scale: scale, adjustNormals: adjustNormals)
    }
    public init(
        parent: NodeUI, name: String, blend: BlendMode = BlendMode.opaque,
        cull: CullMode = CullMode.front, ambient: Color = Color(a: 1, l: 0.05),
        diffuse: Color = Color(a: 1, l: 0.8), specular: Color = Color.white, shininess: Double = 40,
        textureSize: Size, heightSize: Size, heightFormat: Texture2D.Format = Texture2D.Format.bgra,
        scale: Double, adjustNormals: Double = 1.0
    ) {
        self.adjustNormals = adjustNormals
        super.init(
            parent: parent, name: name, blend: blend, cull: cull, ambient: ambient,
            diffuse: diffuse, specular: specular, shininess: shininess, texture: textureSize)
        self.height = Bitmap(parent: self, size: heightSize, format: heightFormat)
        self.setBuffer(size: heightSize, scale: scale, adjustNormals: adjustNormals)
    }
    func setBuffer(size: Size, scale: Double, adjustNormals: Double) {
        let gpu = GPUheight(
            width: Float32(size.width), height: Float32(size.height), scale: Float32(scale),
            adjustNormals: Float32(adjustNormals))
        let buffer = self.persitentBuffer(MemoryLayout<GPUheight>.stride)
        let b = buffer.ptr.assumingMemoryBound(to: GPUheight.self)
        b[0] = gpu
        self.buffer = buffer
    }
    override public func detach() {
        height?.detach()
        height = nil
        buffer?.detach()
        buffer = nil
        super.detach()
    }
    open override func render(
        to g: Graphics, world: Mat4, vertices: Buffer, faces: Buffer, count: Int
    ) {
        if let material = material, let renderer = self.renderer, let camera = renderer.camera {
            let prog = "program.3d.\(renderer.lightsProgram)"
            if let texture = texture, texture.ready, let height = height, height.ready,
                let buffer = self.buffer
            {
                if height.pixels.length < texture.pixels.length {
                    g.program("\(prog)height.texture", blend: blend)
                    g.render.use(vertexTexture: height)
                    g.render.use(texture: texture)
                    g.sampler("sampler.clamp")
                } else {
                    g.program("\(prog)height", blend: blend)
                    g.render.use(vertexTexture: texture)
                    g.render.use(vertexTexture: height, atIndex: 1)
                }
                g.uniforms(buffer: buffer, atIndex: 2)
            } else {
                g.program("\(prog)basic", blend: blend)
            }
            self.updateBuffer()
            g.uniforms(view: g.matrix, world: world, eye: camera.worldMatrix.translation)
            self.lights(g: g, startIndex: 2)
            g.render.use(fragmentBuffer: material, atIndex: 0)
            g.render.use(vertexBuffer: vertices, atIndex: 0)
            if blend == .opaque {
                g.depthStencil(state: "3d.depth.lesser")
            } else {
                g.depthStencil(state: "3d.depth.lesser.nowrite")
            }
            //g.render.set(fill: false)   // 4debug
            g.render.set(cull: self.cull)
            g.render.set(front: .counterClockwise)
            g.render.draw(triangle: count, index: faces)
            g.render.set(cull: .none)
            g.depthStencil(state: "3d.depth.all")
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
