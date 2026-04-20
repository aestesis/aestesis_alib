//
//  light.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 12/02/2024.
//

import Foundation
import simd

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// https://www.raywenderlich.com/146420/metal-tutorial-swift-3-part-4-lighting
public class Light : Node3D {
    var buffer:Buffer?
    var needsUpdate = true
    public init(parent:Node3D,position:Vec3) {
        super.init(parent:parent,matrix:Mat4.translation(position))
    }
    override public func detach() {
        if let b=buffer {
            b.detach()
            buffer=nil
        }
        super.detach()
    }
    public func use(g:Graphics,atIndex index:Int) {
        Debug.notImplemented()
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class PointLight : Light {
    struct GPU {
        var color:SIMD4<Float>
        var attenuationConstant:Float32
        var attenuationLinear:Float32
        var attenuationQuadratic:Float32
        var position:SIMD3<Float>
    }
    public var color:Color {
        didSet {
            self.needsUpdate = true
        }
    }
    public var attenuation:Attenuation {
        didSet {
            self.needsUpdate = true
        }
    }
    public override var matrix: Mat4 {
        didSet {
            self.needsUpdate = true
        }
    }
    public init(parent:Node3D,position:Vec3,color:Color=Color.white,attenuation:Attenuation=Attenuation()) {
        self.color=color
        self.attenuation=attenuation
        super.init(parent:parent,position:position)
        self.buffer = self.persitentBuffer(MemoryLayout<GPU>.stride)
        viewport?.pulse.alive(self) {
            self.needsUpdate=true
        }
    }
    public override func use(g:Graphics,atIndex index:Int) {
        if let b=buffer {
            if needsUpdate {
                needsUpdate=false
                let gpu = GPU(color:color.infloat4,attenuationConstant:Float32(attenuation.constant),attenuationLinear:Float32(attenuation.linear),attenuationQuadratic:Float32(attenuation.quadratic),position:self.worldMatrix.translation.infloat3)
                let ptr = b.ptr.assumingMemoryBound(to: GPU.self)
                ptr[0] = gpu
            }
            g.render.use(fragmentBuffer:b,atIndex:index)
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class DirectionalLight : Light {
    struct GPU {
        var color:SIMD4<Float>
        var intensity:Float32
        var direction:SIMD3<Float>
    }
    public var color:Color {
        didSet {
            needsUpdate = true
        }
    }
    public var intensity:Double {
        didSet {
            needsUpdate = true
        }
    }
    public var direction:Vec3 {
        didSet {
            needsUpdate = true
        }
    }
    public init(parent:Node3D,direction:Vec3=Vec3(z:1),color:Color,intensity:Double) {
        self.color=color
        self.intensity=intensity
        self.direction=direction
        super.init(parent:parent,position:Vec3.zero)
        self.buffer = self.persitentBuffer(MemoryLayout<GPU>.stride)
    }
    override public func detach() {
        if let b=buffer {
            b.detach()
            buffer=nil
        }
        super.detach()
    }
    public override func use(g:Graphics,atIndex index:Int) {
        if let b=buffer {
            if needsUpdate {
                needsUpdate=false
                let gpu = GPU(color:color.infloat4,intensity:Float32(intensity),direction:direction.infloat3)
                let ptr = b.ptr.assumingMemoryBound(to: GPU.self)
                ptr[0] = gpu
            }
            g.render.use(fragmentBuffer:b,atIndex:index)
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Bone : Node3D {
    public var mesh:MeshOld? {
        return self.ancestor() as MeshOld?
    }
    public var name:String
    public init(name:String,parent:NodeUI,matrix:Mat4=Mat4.identity) {
        self.name=name
        super.init(parent:parent,matrix:matrix)
        if parent is MeshOld {
            mesh?.bones.append(self)
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
