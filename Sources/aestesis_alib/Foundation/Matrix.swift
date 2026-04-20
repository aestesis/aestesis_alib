//
//  Matrix.swift
//  Alib
//
//  Created by renan jegouzo on 25/02/2016.
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
import MetalKit
import Accelerate
import simd

#if true
public typealias Mat4 = simd_double4x4

public extension Mat4 {
    init(r0:Vec4,r1:Vec4,r2:Vec4,r3:Vec4) {
        self.init(rows: [r0,r1,r2,r3])
    }
    static func rotX(_ angle:Double) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4(r0:Vec4(x:1),r1:Vec4(x:0,y:c,z:s,w:0),r2:Vec4(x:0,y:-s,z:c,w:0),r3:Vec4(w:1))
    }
    static func rotY(_ angle:Double) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4(r0:Vec4(x:c,y:0,z:-s,w:0),r1:Vec4(y:1),r2:Vec4(x:s,y:0,z:c,w:0),r3:Vec4(w:1))
    }
    static func rotZ(_ angle:Double) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4(r0:Vec4(x:c,y:s,z:0,w:0),r1:Vec4(x:-s,y:c,z:0,w:0),r2:Vec4(z:1),r3:Vec4(w:1))
    }
    static func rotZ(_ angle:Double, origin:Vec3) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4.translation(-origin)*Mat4(r0:Vec4(x:c,y:s,z:0,w:0),r1:Vec4(x:-s,y:c,z:0,w:0),r2:Vec4(z:1),r3:Vec4(w:1))*Mat4.translation(origin)
    }
    static func scale(_ s: Vec3) -> Mat4 {
        return Mat4(r0:Vec4(x:s.x),r1:Vec4(y:s.y),r2:Vec4(z:s.z),r3:Vec4(w:1))
    }
    static func translation(_ t: Vec3) -> Mat4 {
        return Mat4(r0:Vec4(x:1),r1:Vec4(y:1),r2:Vec4(z:1),r3:Vec4(xyz:t,w:1))
    }
    static func rotation(axis:Vec3,angle:Double) -> Mat4 {
        let c=cos(-angle)
        let s=sin(-angle)
        let t=1-c
        let ta=axis.normalized
        return Mat4(r0:Vec4(x:t*ta.x*ta.x+c,y:t*ta.x*ta.y-s*ta.z,z:t*ta.x*ta.z+s*ta.y),r1:Vec4(x:t*ta.x*ta.y+s*ta.z,y:t*ta.y*ta.y+c,z:t*ta.y*ta.z-s*ta.x),r2:Vec4(x:t*ta.x*ta.z-s*ta.y,y:t*ta.y*ta.z+s*ta.x,z:t*ta.z*ta.z+c),r3:Vec4(w:1))
    }
    static func rotation(phi:Double,theta:Double) -> Mat4 {
        return Mat4.rotZ(phi)*Mat4.rotX(theta)
    }
    static var identity : Mat4 {
        return Mat4(r0:Vec4(x:1),r1:Vec4(y:1),r2:Vec4(z:1),r3:Vec4(w:1))
    }
    static func localPerspective(_ p:Double) -> Mat4 {
        return Mat4.scale(Vec3(x:138,y:138,z:0.05))*Mat4.translation(Vec3(x:0,y:0,z:-100))*Mat4.perspective(angleOfView:ß.π*0.6)
    }
    static func perspective(angleOfView:Double) -> Mat4 {
        let scale = 1 / tan(angleOfView*0.5)
        return Mat4(r0:Vec4(x:scale),r1:Vec4(y:scale),r2:Vec4(x:0,y:0,z:-1,w:-1),r3:Vec4(x:0,y:0,z:1,w:0))
    }
    static func perspective(view:Size,angleOfView:Double,near n:Double,far f:Double) -> Mat4 {
        let scale = 1 / tan(angleOfView*0.5)
        return Mat4(r0:Vec4(x:scale*view.ratio),r1:Vec4(y:scale),r2:Vec4(x:0,y:0,z:-f/(f-n),w:-1),r3:Vec4(x:0,y:0,z:-f*n/(f-n),w:0))
    }
    static func perspective(left:Double, right:Double, bottom:Double, top:Double, zNear:Double, zFar:Double) -> Mat4 {
        let x = (2.0 * zNear) / (right - left)
        let y = (2.0 * zNear) / (top - bottom)
        let ta = (right + left) / (right - left)
        let b = (top + bottom) / (top - bottom)
        let c = -(zFar + zNear) / (zFar - zNear)
        let d = -(2.0 * zFar * zNear) / (zFar - zNear)
        return Mat4(r0:Vec4(x:x),r1:Vec4(y:y),r2:Vec4(x:ta,y:b,z:c,w:-1),r3:Vec4(x:0,y:0,z:d,w:0))
    }
    static func gpu(size:Size) -> Mat4 {
        let x1 = 2 / size.width
        let y1 = 2 / size.height
        return Mat4.scale(Vec3(x:x1,y:-y1,z:0.001))*Mat4.translation(Vec3(x:-1,y:1,z:0.5))
    }
    static func lookAt(direction:Vec3) -> Mat4 { // auto compute up vector nearest Y axis
        let f = -direction.normalized
        let u = Vec3(x:-f.x*f.y,y:f.x*f.x+f.z*f.z,z:-f.y*f.z)
        let r = u ^ f
        return Mat4(r0:Vec4(xyz:r),r1:Vec4(xyz:u),r2:Vec4(xyz:f),r3:Vec4(w:1))
    }
    static func lookAt(eye:Vec3,target:Vec3,up:Vec3) -> Mat4
    {
        let z=(target-eye).normalized
        let x=(up^z).normalized
        let y=(z^x).normalized
        return Mat4(r0:Vec4(x:x.x,y:y.x,z:z.x),r1:Vec4(x:x.y,y:y.y,z:z.y),r2:Vec4(x:x.z,y:y.z,z:z.z),r3:Vec4(xyz:(-eye),w:1))
    }
    var r0:Vec4 {
        get {
            return Vec4(self.columns.0.x,self.columns.1.x,self.columns.2.x,self.columns.3.x)
        }
        set(v) {
            self.columns.0.x = v.x
            self.columns.1.x = v.y
            self.columns.2.x = v.z
            self.columns.3.x = v.w
        }
    }
    var r1:Vec4 {
        get {
            return Vec4(self.columns.0.y,self.columns.1.y,self.columns.2.y,self.columns.3.y)
        }
        set(v) {
            self.columns.0.y = v.x
            self.columns.1.y = v.y
            self.columns.2.y = v.z
            self.columns.3.y = v.w
        }
    }
    var r2:Vec4 {
        get {
            return Vec4(self.columns.0.z,self.columns.1.z,self.columns.2.z,self.columns.3.z)
        }
        set(v) {
            self.columns.0.z = v.x
            self.columns.1.z = v.y
            self.columns.2.z = v.z
            self.columns.3.z = v.w
        }
    }
    var r3:Vec4 {
        get {
            return Vec4(self.columns.0.w,self.columns.1.w,self.columns.2.w,self.columns.3.w)
        }
        set(v) {
            self.columns.0.w = v.x
            self.columns.1.w = v.y
            self.columns.2.w = v.z
            self.columns.3.w = v.w
        }
    }
    /*
    var inverted : Mat4 {
        return self.inverse
    }
     */
    var translation: Vec3 {
        get { return r3.xyz }
        set(t) { r3.xyz = t }
    }
    func transform(_ v:Vec3) -> Vec3 {
        return (self * Vec4(xyz:v,w:1)).xyz
    }
    func transform(_ v:Vec4) -> Vec4 {
        return self * v
    }
    var infloat4x4:float4x4 {
        return float4x4([r0.infloat4,r1.infloat4,r2.infloat4,r3.infloat4])  // rows -> columns, cause gpu translation in last column
    }
}
#else
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Mat4 : CustomStringConvertible,JsonConvertible {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var r0:Vec4
    public var r1:Vec4
    public var r2:Vec4
    public var r3:Vec4
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var infloat4x4:float4x4 {
        return float4x4([r0.infloat4,r1.infloat4,r2.infloat4,r3.infloat4])  // rows -> columns, cause gpu translation in last column
    }
    public var indouble4x4:double4x4 {
        return double4x4([r0,r1,r2,r3])
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var c0:Vec4 {
        get {
            return Vec4(x:r0.x,y:r1.x,z:r2.x,w:r3.x)
        }
        set(v) {
            r0.x=v.x
            r1.x=v.y
            r2.x=v.z
            r3.x=v.w
        }
    }
    public var c1:Vec4 {
        get {
            return Vec4(x:r0.y,y:r1.y,z:r2.y,w:r3.y)
        }
        set(v) {
            r0.y=v.x
            r1.y=v.y
            r2.y=v.z
            r3.y=v.w
        }
    }
    public var c2:Vec4 {
        get {
            return Vec4(x:r0.z,y:r1.z,z:r2.z,w:r3.z)
        }
        set(v) {
            r0.z=v.x
            r1.z=v.y
            r2.z=v.z
            r3.z=v.w
        }
    }
    public var c3:Vec4 {
        get {
            return Vec4(x:r0.w,y:r1.w,z:r2.w,w:r3.w)
        }
        set(v) {
            r0.w=v.x
            r1.w=v.y
            r2.w=v.z
            r3.w=v.w
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var description:String {
        return "{ r0:\(r0.description),r1:\(r1.description),r2:\(r2.description),r3:\(r3.description)}"
    }
    public var determinant:Double {
        return r0.x * r1.y * r2.z * r3.w - r0.x * r1.y * r2.w * r3.z + r0.x * r1.z * r2.w * r3.y - r0.x * r1.z * r2.y * r3.w
            + r0.x * r1.w * r2.y * r3.z - r0.x * r1.w * r2.z * r3.y - r0.y * r1.z * r2.w * r3.x + r0.y * r1.z * r2.x * r3.w
            - r0.y * r1.w * r2.x * r3.z + r0.y * r1.w * r2.z * r3.x - r0.y * r1.x * r2.z * r3.w + r0.y * r1.x * r2.w * r3.z
            + r0.z * r1.w * r2.x * r3.y - r0.z * r1.w * r2.y * r3.x + r0.z * r1.x * r2.y * r3.w - r0.z * r1.x * r2.w * r3.y
            + r0.z * r1.y * r2.w * r3.x - r0.z * r1.y * r2.x * r3.w - r0.w * r1.x * r2.y * r3.z + r0.w * r1.x * r2.z * r3.y
            - r0.w * r1.y * r2.z * r3.x + r0.w * r1.y * r2.x * r3.z - r0.w * r1.z * r2.x * r3.y + r0.w * r1.z * r2.y * r3.x
    }
    public var diagonale:Vec4 {
        get { return Vec4(x:r0.x,y:r1.y,z:r2.z,w:r3.w) }
        set(d) {
            r0.x=d.x
            r1.y=d.y
            r2.z=d.z
            r3.w=d.w
        }
    }
    public var inverted : Mat4 {
        var mat = self
        var N = __CLPK_integer(4)
        var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
        var workspace = [Double](repeating: 0.0, count: Int(N))
        var error : __CLPK_integer = 0
        withUnsafeMutablePointer(to: &N) { buf in
            dgetrf_(buf, buf, &mat.r0.x, buf, &pivots, &error)
            dgetri_(buf, &mat.r0.x, buf, &pivots, &workspace, buf, &error)
        }
        return mat
    }
    public var json : JSON {
        return JSON(parseJSON:description)
    }
    public var trace:Double {
        return diagonale.x+diagonale.y+diagonale.z+diagonale.w
    }
    public var translation: Vec3 {
        get { return r3.xyz }
        set(t) { r3.xyz=t }
    }
    public func transform(_ v:Vec3) -> Vec3 {
        return transform(Vec4(xyz:v,w:1)).xyz
    }
    public func transform(_ v:Vec4) -> Vec4 {
        return Vec4(x: v.x*r0.x + v.y*r1.x + v.z*r2.x + v.w*r3.x,
                    y: v.x*r0.y + v.y*r1.y + v.z*r2.y + v.w*r3.y,
                    z: v.x*r0.z + v.y*r1.z + v.z*r2.z + v.w*r3.z,
                    w: v.x*r0.w + v.y*r1.w + v.z*r2.w + v.w*r3.w)
    }
    public var transposed: Mat4 {
        return Mat4(r0:c0,r1:c1,r2:c2,r3:c3)
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public init(r0:Vec4,r1:Vec4,r2:Vec4,r3:Vec4) {
        self.r0=r0
        self.r1=r1
        self.r2=r2
        self.r3=r3
    }
    public init(c0:Vec4,c1:Vec4,c2:Vec4,c3:Vec4) {
        r0=Vec4(x:c0.x,y:c1.x,z:c2.x,w:c3.x)
        r1=Vec4(x:c0.y,y:c1.y,z:c2.y,w:c3.y)
        r2=Vec4(x:c0.z,y:c1.z,z:c2.z,w:c3.z)
        r3=Vec4(x:c0.w,y:c1.w,z:c2.w,w:c3.w)
    }
    public init(json:JSON) {
        self.r0=Vec4(json:json["r0"])
        self.r1=Vec4(json:json["r1"])
        self.r2=Vec4(json:json["r2"])
        self.r3=Vec4(json:json["r3"])
    }
    public init(_ m:float4x4) {
        self.init(r0:Vec4(m.columns.0),r1:Vec4(m.columns.1),r2:Vec4(m.columns.2),r3:Vec4(m.columns.3))
    }
    public init(_ m:float3x3) {
        self.init(r0:Vec4(xyz:Vec3(m.columns.0),w:0),r1:Vec4(xyz:Vec3(m.columns.1),w:0),r2:Vec4(xyz:Vec3(m.columns.2),w:0),r3:Vec4(xyz:Vec3.zero,w:1))
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public static var identity : Mat4 {
        return Mat4(r0:Vec4(x:1),r1:Vec4(y:1),r2:Vec4(z:1),r3:Vec4(w:1))
    }
    public static func lookAt(direction:Vec3) -> Mat4 { // auto compute up vector nearest Y axis
        let f = -direction.normalized
        let u = Vec3(x:-f.x*f.y,y:f.x*f.x+f.z*f.z,z:-f.y*f.z)
        let r = u ^ f
        return Mat4(r0:Vec4(xyz:r),r1:Vec4(xyz:u),r2:Vec4(xyz:f),r3:Vec4(w:1))
    }
    public static func lookAt(eye:Vec3,target:Vec3,up:Vec3) -> Mat4
    {
        let z=(target-eye).normalized
        let x=(up^z).normalized
        let y=(z^x).normalized
        return Mat4(r0:Vec4(x:x.x,y:y.x,z:z.x),r1:Vec4(x:x.y,y:y.y,z:z.y),r2:Vec4(x:x.z,y:y.z,z:z.z),r3:Vec4(xyz:(-eye),w:1))
    }
    public static func orthographic(_ left:Double, right:Double, bottom:Double, top:Double, zNear:Double, zFar:Double) -> Mat4
    {
        let ix = 1 / (right - left)
        let iy = 1 / (top - bottom)
        let iz = 1 / (zFar - zNear)
        return Mat4(r0:Vec4(x:2*ix),r1:Vec4(y:2*iy),r2:Vec4(z:-2*iz),r3:Vec4(x:-(right+left)*ix,y:-(top+bottom)*iy,z:-(zFar+zNear)*iz,w:1))
    }
    public static func gpu(size:Size) -> Mat4 { // good one
        let x1 = 2 / size.width
        let y1 = 2 / size.height
        return Mat4.scale(Vec3(x:x1,y:-y1,z:0.001))*Mat4.translation(Vec3(x:-1,y:1,z:0.5))
    }
    public static func localPerspective(_ p:Double) -> Mat4 {
        return Mat4.scale(Vec3(x:138,y:138,z:0.05))*Mat4.translation(Vec3(x:0,y:0,z:-100))*Mat4.perspective(angleOfView:ß.π*0.6)
    }
    public static func perspective(angleOfView:Double) -> Mat4 {
        let scale = 1 / tan(angleOfView*0.5)
        return Mat4(r0:Vec4(x:scale),r1:Vec4(y:scale),r2:Vec4(x:0,y:0,z:-1,w:-1),r3:Vec4(x:0,y:0,z:1,w:0))
    }
    public static func perspective(view:Size,angleOfView:Double,near n:Double,far f:Double) -> Mat4 {
        let scale = 1 / tan(angleOfView*0.5)
        return Mat4(r0:Vec4(x:scale*view.ratio),r1:Vec4(y:scale),r2:Vec4(x:0,y:0,z:-f/(f-n),w:-1),r3:Vec4(x:0,y:0,z:-f*n/(f-n),w:0))
    }
    public static func perspective(left:Double, right:Double, bottom:Double, top:Double, zNear:Double, zFar:Double) -> Mat4 {
        let x = (2.0 * zNear) / (right - left)
        let y = (2.0 * zNear) / (top - bottom)
        let ta = (right + left) / (right - left)
        let b = (top + bottom) / (top - bottom)
        let c = -(zFar + zNear) / (zFar - zNear)
        let d = -(2.0 * zFar * zNear) / (zFar - zNear)
        return Mat4(r0:Vec4(x:x),r1:Vec4(y:y),r2:Vec4(x:ta,y:b,z:c,w:-1),r3:Vec4(x:0,y:0,z:d,w:0)) 
    }
    public static func rotX(_ angle:Double) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4(r0:Vec4(x:1),r1:Vec4(x:0,y:c,z:s,w:0),r2:Vec4(x:0,y:-s,z:c,w:0),r3:Vec4(w:1))
    }
    public static func rotY(_ angle:Double) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4(r0:Vec4(x:c,y:0,z:-s,w:0),r1:Vec4(y:1),r2:Vec4(x:s,y:0,z:c,w:0),r3:Vec4(w:1))
    }
    public static func rotZ(_ angle:Double) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4(r0:Vec4(x:c,y:s,z:0,w:0),r1:Vec4(x:-s,y:c,z:0,w:0),r2:Vec4(z:1),r3:Vec4(w:1))
    }
    public static func rotZ(_ angle:Double, origin:Vec3) -> Mat4 {
        let c=cos(angle)
        let s=sin(angle)
        return Mat4.translation(-origin)*Mat4(r0:Vec4(x:c,y:s,z:0,w:0),r1:Vec4(x:-s,y:c,z:0,w:0),r2:Vec4(z:1),r3:Vec4(w:1))*Mat4.translation(origin)
    }
    public static func rotation(_ axis:Vec3,angle:Double) -> Mat4 {
        let c=cos(-angle)
        let s=sin(-angle)
        let t=1-c
        let ta=axis.normalized
        return Mat4(r0:Vec4(x:t*ta.x*ta.x+c,y:t*ta.x*ta.y-s*ta.z,z:t*ta.x*ta.z+s*ta.y),r1:Vec4(x:t*ta.x*ta.y+s*ta.z,y:t*ta.y*ta.y+c,z:t*ta.y*ta.z-s*ta.x),r2:Vec4(x:t*ta.x*ta.z-s*ta.y,y:t*ta.y*ta.z+s*ta.x,z:t*ta.z*ta.z+c),r3:Vec4(w:1))
    }
    public static func scale(_ s: Vec3) -> Mat4 {
        return Mat4(r0:Vec4(x:s.x),r1:Vec4(y:s.y),r2:Vec4(z:s.z),r3:Vec4(w:1))
    }
    public static func translation(_ t: Vec3) -> Mat4 {
        return Mat4(r0:Vec4(x:1),r1:Vec4(y:1),r2:Vec4(z:1),r3:Vec4(xyz:t,w:1))
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public subscript(col: Int, row: Int) -> Double {
        get {
            switch row {
            case 1:
                return r1[col]
            case 2:
                return r2[col]
            case 3:
                return r3[col]
            default:
                return r0[col]
            }
        }
        set(v) {
            switch row {
            case 1:
                r1[col]=v
            case 2:
                r2[col]=v
            case 3:
                r3[col]=v
            default:
                r0[col]=v
            }
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public func ==(ta: Mat4, b: Mat4) -> Bool {
    return ta.r0==b.r0&&ta.r1==b.r1&&ta.r2==b.r2&&ta.r3==b.r3
}
public func +(ta:Mat4,b:Mat4)->Mat4 {
    return Mat4(r0:ta.r0+b.r0,r1:ta.r1+b.r1,r2:ta.r2+b.r2,r3:ta.r3+b.r3)
}
public func -(ta:Mat4,b:Mat4)->Mat4 {
    return Mat4(r0:ta.r0-b.r0,r1:ta.r1-b.r1,r2:ta.r2-b.r2,r3:ta.r3-b.r3)
}
public func *(lhs:Mat4, rhs:Mat4) -> Mat4 {  // TODO: use directly lhs, rhs without copying
    var l = lhs
    var r = rhs
    var result = Mat4.identity
    withUnsafePointer(to: &l) { ul in
        ul.withMemoryRebound(to: Double.self, capacity: 16) { ta in
            withUnsafePointer(to: &r) { ur in
                ur.withMemoryRebound(to: Double.self, capacity: 16) { b in
                    withUnsafeMutablePointer(to: &result) { ures in
                        ures.withMemoryRebound(to: Double.self, capacity: 16) { c in
                            vDSP_mmulD(ta, 1, b, 1, c, 1, 4, 4, 4)
                        }
                    }
                }
            }
        }
    }
    return result
}
public func *(lhs:Mat4, rhs:Vec4) -> Vec4 {
    return lhs.transform(rhs)
}
public func *(lhs:Mat4, rhs:Vec3) -> Vec3 {
    return lhs.transform(rhs)
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
#endif
