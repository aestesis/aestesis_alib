//
//  object.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 12/02/2024.
//

import Foundation
import simd

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class ObjectOld : Node3D {
    public var meshMatrix:Mat4 = Mat4.identity
    public let onInitialized = Event<Void>()
    public private(set) var mesh:String
    override open func detach() {
        onInitialized.removeAll()
        super.detach()
    }
    func dispatchInit() {
        if let m=self[mesh] as? MeshOld {
            if m.initialized {
                self.ui {
                    self.onInitialized.dispatch(())
                }
            } else {
                m.onInitialized.once { _ in
                    self.onInitialized.dispatch(())
                }
            }
        }
    }
    public init(parent:Node3D,matrix:Mat4,path:String) {
        self.mesh = "mesh.\(path)"
        super.init(parent:parent,matrix:matrix)
        if self[mesh] is MeshOld {
            dispatchInit()
        } else if let db = self.db {
            db[mesh] = MeshOld(parent:db,path:path)
            dispatchInit()
        }
    }
    public init(parent:Node3D,matrix:Mat4,mesh:String,material:String="material.default") {
        self.mesh = mesh
        super.init(parent:parent,matrix:matrix)
        dispatchInit()
        if material != "material.default" {
            self["material.default"] = material
        }
    }
    public init(parent:Node3D,sphere:Sphere,material:String="material.default") {
        self.mesh = "mesh.sphere"
        self.meshMatrix = Mat4.scale(Vec3(x:sphere.radius,y:sphere.radius,z:sphere.radius))
        super.init(parent:parent,matrix:Mat4.translation(sphere.center))
        if self[mesh] is MeshOld {
            dispatchInit()
        } else if let db = self.db {
            db[mesh] = MeshOld(parent:db,sphere:Sphere.unity,factor:16)
            dispatchInit()
        }
        if material != "material.default" {
            self["material.default"] = material
        }
    }
    public init(parent:Node3D,cylinder:Cylinder,material:String="material.default") {
        self.mesh = "mesh.cylinder"
        self.meshMatrix = Mat4.scale(Vec3(x:cylinder.radius,y:cylinder.direction.length,z:cylinder.radius))*Mat4.rotation(axis:cylinder.direction,angle:0)
        super.init(parent:parent,matrix:Mat4.translation(cylinder.center))
        if self[mesh] is MeshOld {
            dispatchInit()
        } else if let db = self.db {
            db[mesh] = MeshOld(parent:db,cylinder:Cylinder(radius:cylinder.radius/cylinder.direction.length),factor:16)
            dispatchInit()
        }
        if material != "material.default" {
            self["material.default"] = material
        }
    }
    public init(parent:Node3D,box:Box,material:String="material.default",inversNormals:Bool = false) {
        self.mesh = "mesh.box"
        self.meshMatrix = Mat4.scale(Vec3(x:box.w,y:box.h,z:box.d))
        super.init(parent:parent,matrix:Mat4.translation(box.center))
        if self[mesh] is MeshOld {
            dispatchInit()
        } else if let db = self.db {
            db[mesh] = MeshOld(parent:db,box:Box(x:-0.5,y:-0.5,z:-0.5,w:1,h:1,d:1),inversNormals: inversNormals)
            dispatchInit()
        }
        if material != "material.default" {
            self["material.default"] = material
        }
    }
    open override func render(to g0:Graphics,world:Mat4,opaque:Bool) -> Bool {
        var m = mesh
        while let n = self[m] as? String {
            m = n
        }
        if let mesh = self[m] as? MeshOld {
            let g = Graphics(parent:g0,matrix:self.meshMatrix)
            return mesh.render(to:g,world:self.meshMatrix*world,library:self,opaque:opaque)
        }
        return false
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
