//
//  object.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 13/02/2024.
//

import Foundation

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class Object: Node3D, @unchecked Sendable {
    var mesh: Mesh {
        didSet {
            needsBufferUpdate = true
        }
    }
    var materials: [String: Material] {
        didSet {
            needsBufferUpdate = true
        }
    }
    var needsBufferUpdate: Bool = true
    var bufferVertices: Buffer?
    var bufferFaces: [String: Buffer] = [:]
    var bufferMaterials: [String: Buffer] = [:]
    var bounds: Box { return mesh.boundingBox }

    public init(parent: NodeUI, matrix: Mat4 = Mat4.identity, mesh: Mesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = Material.dictionnary(materials: materials)
        super.init(parent: parent, matrix: matrix)
    }
    public init(
        parent: NodeUI, matrix: Mat4 = Mat4.identity, mesh: Mesh, materials: [String: Material]
    ) {
        self.mesh = mesh
        self.materials = materials
        super.init(parent: parent, matrix: matrix)
    }
    public func updateBuffers() {
        guard needsBufferUpdate else { return }
        if bufferVertices == nil {
            bufferVertices = self.persitentBuffer(
                MemoryLayout<GPUvertice>.stride * mesh.vertices.count)
        }
        if let bv = bufferVertices {
            let pv = bv.ptr.assumingMemoryBound(to: GPUvertice.self)
            for i in 0..<mesh.vertices.count {
                let v = mesh.vertices[i]
                pv[i] = GPUvertice(
                    position: v.position.infloat3, color: v.color.infloat4, uv: v.uv.infloat2,
                    normal: v.normal.infloat3)
            }
        }
        for m in mesh.faces.keys {
            if let f = mesh.faces[m] {
                if bufferFaces[m] == nil {
                    bufferFaces[m] = self.persitentBuffer(MemoryLayout<UInt32>.stride * f.count)
                }
                if let bf = bufferFaces[m] {
                    let pv = bf.ptr.assumingMemoryBound(to: UInt32.self)
                    memcpy(pv, f, MemoryLayout<Float32>.stride * f.count)
                }
            }
        }
        for m in materials.values {
            if bufferMaterials[m.name] == nil {
                bufferMaterials[m.name] = self.persitentBuffer(MemoryLayout<GPUmaterial>.stride)
            }
            let ptr = bufferMaterials[m.name]!.ptr.assumingMemoryBound(to: GPUmaterial.self)
            ptr[0] = GPUmaterial(
                ambient: m.ambient.infloat4, diffuse: m.diffuse.infloat4,
                specular: m.specular.infloat4, shininess: Float32(m.shininess))
        }
        needsBufferUpdate = false
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
    override public func render(to g: Graphics, world: Mat4, opaque: Bool) -> Bool {
        var transparency = false
        updateBuffers()
        for kmat in mesh.faces.keys {
            if let mat = materials[kmat] {
                if mat.transparent != opaque {
                    render(to: g, world: world, material: mat)
                }
                transparency = transparency || mat.transparent
            } else {
                Debug.error("material \(kmat) not found")
            }
        }
        return transparency
    }
    func render(to g: Graphics, world: Mat4, material: Material) {
        guard let renderer = renderer, let camera = renderer.camera,
            let f = mesh.faces[material.name], f.count > 0, let bv = bufferVertices,
            let bf = bufferFaces[material.name], let bm = bufferMaterials[material.name]
        else { return }
        let prog = "program.3d.\(renderer.lightsProgram)"
        if let ktexture = material.texture, let texture = self[ktexture] as? Texture2D,
            texture.ready
        {
            g.program("\(prog)texture", blend: material.blend)
            g.render.use(texture: texture)
        } else {
            g.program("\(prog)basic", blend: material.blend)
        }
        g.uniforms(view: g.matrix, world: world, eye: camera.worldMatrix.translation)
        self.lights(g: g, startIndex: 2)
        g.render.use(fragmentBuffer: bm, atIndex: 0)
        g.render.use(vertexBuffer: bv, atIndex: 0)
        if material.blend == .opaque {
            g.depthStencil(state: "3d.depth.lesser")
        } else {
            g.depthStencil(state: "3d.depth.lesser.nowrite")
        }
        g.render.set(cull: mesh.cullMode)
        g.render.set(front: mesh.winding)
        g.render.draw(triangle: f.count, index: bf)
        g.render.set(cull: .none)
        g.depthStencil(state: "3d.depth.all")
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Instance {
    public var matrix: Mat4
    public var color: Color
    init(matrix: Mat4 = .identity, color: Color = .white) {
        self.matrix = matrix
        self.color = color
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class ObjectCollection: Object, @unchecked Sendable {
    var bufferInstances: Buffer?
    var instances: [Instance] = [] {
        didSet {
            needsInstancesUpdate = true
        }
    }
    var needsInstancesUpdate = true
    func updateInstancesBuffer() {
        guard needsInstancesUpdate else { return }
        needsInstancesUpdate = false
        let size = MemoryLayout<GPUinstance>.stride * instances.count
        if bufferInstances == nil || bufferInstances!.size != size {
            bufferInstances = self.persitentBuffer(size)
        }
        if let b = bufferInstances {
            let ptr = b.ptr.assumingMemoryBound(to: GPUinstance.self)
            var index = 0
            for i in instances {
                ptr[index] = GPUinstance(matrix: i.matrix.infloat4x4, color: i.color.infloat4)
                index += 1
            }
        }
    }
    override func render(to g: Graphics, world: Mat4, material: Material) {
        guard !instances.isEmpty else { return }
        guard let renderer = renderer else { return }
        guard let camera = renderer.camera else { return }
        guard let f = mesh.faces[material.name] else { return }
        guard !f.isEmpty else { return }
        guard let bv = bufferVertices else { return }
        guard let bf = bufferFaces[material.name] else { return }
        guard let bm = bufferMaterials[material.name] else { return }
        updateInstancesBuffer()
        guard let bi = bufferInstances else { return }
        let prog = "program.3d.instance.\(renderer.lightsProgram)"
        if let ktexture = material.texture, let texture = self[ktexture] as? Texture2D,
            texture.ready
        {
            g.program("\(prog)texture", blend: material.blend)
            g.render.use(texture: texture)
        } else {
            g.program("\(prog)basic", blend: material.blend)
        }
        g.uniforms(view: g.matrix, world: world, eye: camera.worldMatrix.translation)
        self.lights(g: g, startIndex: 2)
        g.render.use(fragmentBuffer: bm, atIndex: 0)
        g.render.use(vertexBuffer: bv, atIndex: 0)
        g.render.use(vertexBuffer: bi, atIndex: 2)
        if material.blend == .opaque {
            g.depthStencil(state: "3d.depth.lesser")
        } else {
            g.depthStencil(state: "3d.depth.lesser.nowrite")
        }
        g.render.set(cull: mesh.cullMode)
        g.render.set(front: mesh.winding)
        g.render.draw(triangle: f.count, index: bf, instanceCount: instances.count)
        g.render.set(cull: .none)
        g.depthStencil(state: "3d.depth.all")
    }

    func addInstances(count: Int) {
        instances.append(contentsOf: [Instance](repeating: Instance(), count: count))
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
