//
//  primitives.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 12/02/2024.
//

import Foundation
import simd
import Metal

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
typealias Cube=Box
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public protocol MeshProvider {
    var defaultFactor:Int { get }
    func mesh(factor:Int,inverse:Bool) -> Mesh
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
protocol MaterialProvider {
    var materials:[String:Material] { get }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
typealias MeshMaterialProvider=MeshProvider & MaterialProvider
//protocol MeshMaterialProvider : MeshProvider,MaterialProvider {}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Vertex {
    public var position:Vec3
    public var normal:Vec3
    public var uv:Point
    public var color:Color
    public init(position:Vec3=Vec3.zero,normal:Vec3=Vec3.zero,uv:Point=Point.zero,color:Color=Color.white) {
        self.position=position
        self.normal=normal
        self.uv=uv
        self.color=color
    }
    public static func ==(l:Vertex, r: Vertex) -> Bool {
        return l.position == r.position && l.normal == r.normal && l.uv == r.uv && l.color == r.color
    }
    public static func !=(l:Vertex, r: Vertex) -> Bool {
        return l.position != r.position || l.normal != r.normal || l.uv != r.uv || l.color != r.color
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public enum CullMode {
    case none
    case front
    case back
    var system: MTLCullMode {
        switch self {
        case .none:
            return MTLCullMode.none
        case .front:
            return MTLCullMode.front
        case .back:
            return MTLCullMode.back
        }
    }
}
public enum Winding {
    case clockwise
    case counterClockwise
    var system: MTLWinding {
        switch self {
        case .clockwise:
            return MTLWinding.clockwise
        case .counterClockwise:
            return MTLWinding.counterClockwise
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Mesh {
    public var name:String
    public var vertices:[Vertex]=[]
    public var faces:[String:[UInt32]]=[:]
    public var cullMode:CullMode = .front
    public var winding:Winding = .clockwise
    public mutating func appendFace(material:String,v0:UInt32,v1:UInt32,v2:UInt32)  {
        faces[material]!.append(v0)
        faces[material]!.append(v1)
        faces[material]!.append(v2)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Mesh {
    public var boundingBox:Box {
        guard vertices.count<=0 else { return Box.zero }
        var b = Box(o:vertices[0].position,s:Vec3.zero)
        for v in vertices {
            b = b.union(v.position)
        }
        return b
    }
    public var boundingSphere : Sphere {
        return Sphere(bounding:boundingBox)
    }
    public mutating func appendVertice(position:Vec3,normal:Vec3,uv:Point) -> Int32 {
        let i = Int32(vertices.count)
        vertices.append(Vertex(position:position,normal:normal,uv:uv))
        return i
    }
    public func index(vertice:Vertex) -> Int? {
        var i = 0
        for v in vertices {
            if v == vertice {
                return i
            }
            i += 1
        }
        return nil
    }
    public mutating func computeNormals(inverse:Bool = false) {
        var verticesFaces = [UInt32:[(v1:UInt32,v2:UInt32)]]()
        for m in faces.keys {
            if let f = faces[m] {
                var i = 0
                while i<f.count {
                    let v0 = f[i]
                    i += 1
                    let v1 = f[i]
                    i += 1
                    let v2 = f[i]
                    i += 1
                    if verticesFaces[v0] == nil {
                        verticesFaces[v0] = [(v1:UInt32,v2:UInt32)]()
                    }
                    if verticesFaces[v1] == nil {
                        verticesFaces[v1] = [(v1:UInt32,v2:UInt32)]()
                    }
                    if verticesFaces[v2] == nil {
                        verticesFaces[v2] = [(v1:UInt32,v2:UInt32)]()
                    }
                    verticesFaces[v0]!.append((v1:v1,v2:v2))
                    verticesFaces[v1]!.append((v1:v2,v2:v0))
                    verticesFaces[v2]!.append((v1:v0,v2:v1))
                }
            }
        }
        let sign:Double = inverse ? -1 : 1
        for i in verticesFaces.keys {
            if let fl = verticesFaces[i] {
                let v0 = vertices[Int(i)].position
                var n = Vec3.zero
                for f in fl {
                    n = n + ((vertices[Int(f.v1)].position-v0) ^ (vertices[Int(f.v2)].position-v0)).normalized
                }
                let normal = (n/Double(fl.count))
                vertices[Int(i)].normal = sign * normal
            }
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Sphere {
    public var center:Vec3
    public var radius:Double
    public init(bounding box:Box) {
        self.center = box.origin.lerp(vector:box.opposite,coef:0.5)
        self.radius = (box.opposite-box.origin).length*0.5
    }
    public init(center:Vec3=Vec3.zero,radius:Double=1) {
        self.center = center
        self.radius = radius
    }
    public static var unity : Sphere {
        return Sphere()
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Sphere : MaterialProvider {
    var materials: [String : Material] {
        return ["default":Material(name:"default")]
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Sphere : MeshProvider {
    public var defaultFactor: Int { return 16 }
    public func mesh(factor:Int = 16,inverse:Bool = false)->Mesh {
        var mesh=Mesh(name:"Sphere.\(factor)",winding: inverse ? .clockwise : .counterClockwise)
        let dn:Double = inverse ? -1 : 1
        for j in 0...factor {
            let theta = ß.π*Double(j)/Double(factor)
            let stheta = sin(theta)
            let ctheta = cos(theta)
            for i in 0..<factor {
                let phi = 2*ß.π*Double(i)/Double(factor)
                let p = center+Vec3(x:stheta*cos(phi),y:stheta*sin(phi),z:ctheta)*radius
                mesh.vertices.append(Vertex(position:p,normal:p.normalized*dn,uv:Point(x:Double(i)/Double(factor),y:Double(j)/Double(factor))))
            }
        }
        let mat = "default"
        mesh.faces[mat] = [UInt32]()
        for j in 0..<factor {
            for i in 0..<factor-1 {
                let first = j*factor + i
                let second = first + factor
                let first1 = first+1
                let second1 = second+1
                mesh.faces[mat]!.append(UInt32(first))
                mesh.faces[mat]!.append(UInt32(second))
                mesh.faces[mat]!.append(UInt32(first1))
                mesh.faces[mat]!.append(UInt32(second))
                mesh.faces[mat]!.append(UInt32(second1))
                mesh.faces[mat]!.append(UInt32(first1))
            }
            let first = j*factor + factor - 1
            let second = first + factor
            let first1 = j*factor
            let second1 = first1 + factor
            mesh.faces[mat]!.append(UInt32(first))
            mesh.faces[mat]!.append(UInt32(second))
            mesh.faces[mat]!.append(UInt32(first1))
            mesh.faces[mat]!.append(UInt32(second))
            mesh.faces[mat]!.append(UInt32(second1))
            mesh.faces[mat]!.append(UInt32(first1))
        }
        return mesh
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Cylinder {
    public var center:Vec3
    public var direction:Vec3
    public var radius:Double
    public init(center:Vec3=Vec3.zero,direction:Vec3=Vec3(y:1),radius:Double=1) {
        self.center = center
        self.direction = direction
        self.radius = radius
    }
    public static var unity : Cylinder {
        return Cylinder()
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Cylinder : MaterialProvider {
    var materials: [String : Material] {
        return ["default":Material(name:"default")]
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Cylinder:MeshProvider {
    public var defaultFactor: Int { return 16 }
    public func mesh(factor: Int=16,inverse:Bool = false) -> Mesh {
        var mesh=Mesh(name:"Cylinder.\(factor)",winding: inverse ? .counterClockwise : .clockwise)
        let mat = "default"
        let dn:Double = inverse ? -1 : 1
        // only generate on Y axis, need to update
        // maybe check https://github.com/mattatz/unity-tubular/blob/master/Assets/Packages/Tubular/Scripts/Tubular.cs
        assert(direction.x == 0 && direction.z == 0)
        
        mesh.faces[mat]=[UInt32]()
        var y = center - direction*0.5
        let dy = direction
        for _ in 0...1 {
            for ai in 0..<factor {
                let a = ß.π * 2 * Double(ai) / Double(factor)
                let n = Vec3(x:cos(a),y:0,z:sin(a))
                let p = y + n * radius
                mesh.vertices.append(Vertex(position:p,normal:dn*n))
            }
            y += dy
        }
        for ai in 0..<factor {
            let p0 = ai
            let p3 = ai + factor
            let p1 = (ai<factor-1) ? p0+1 : p0 - (factor - 1)
            let p2 = (ai<factor-1) ? p3+1 : p3 - (factor - 1)
            mesh.faces[mat]!.append(UInt32(p0))
            mesh.faces[mat]!.append(UInt32(p1))
            mesh.faces[mat]!.append(UInt32(p2))
            mesh.faces[mat]!.append(UInt32(p2))
            mesh.faces[mat]!.append(UInt32(p3))
            mesh.faces[mat]!.append(UInt32(p0))
        }
        y = center - direction*0.5
        var n = Vec3(y:-1)
        for _ in 0...1 {
            for ai in 0..<factor {
                let a = ß.π * 2 * Double(ai) / Double(factor)
                // TODO: transform around direction cos, sin, etc..
                //  The plane perpendicular to (𝑎,𝑏,𝑐) and passing through (𝑥0,𝑦0,𝑧0) is
                //  𝑎(𝑥−𝑥0)+𝑏(𝑦−𝑦0)+𝑐(𝑧−𝑧0)=0 .
                let p = y + Vec3(x:cos(a),y:0,z:sin(a)) * radius
                mesh.vertices.append(Vertex(position:p,normal:dn*n))
            }
            y += dy
            n = Vec3(y:1)
        }
        let s0 = factor * 2
        let s1 = factor * 3
        let c0 =  mesh.vertices.count
        mesh.vertices.append(Vertex(position:center - direction*0.5,normal:dn*Vec3(y:-1)))
        let c1 = mesh.vertices.count
        mesh.vertices.append(Vertex(position:center + direction*0.5,normal:dn*Vec3(y:1)))
        for i in 0..<factor {
            mesh.faces[mat]!.append(UInt32(c0))
            if i < factor-1 {
                mesh.faces[mat]!.append(UInt32(s0+i+1))
            } else {
                mesh.faces[mat]!.append(UInt32(s0))
            }
            mesh.faces[mat]!.append(UInt32(s0+i))
            mesh.faces[mat]!.append(UInt32(c1))
            mesh.faces[mat]!.append(UInt32(s1+i))
            if i < factor-1 {
                mesh.faces[mat]!.append(UInt32(s1+i+1))
            } else {
                mesh.faces[mat]!.append(UInt32(s1))
            }
        }
        return mesh
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Box {
    public var origin : Vec3
    public var size: Vec3
    public var x: Double {
        get { return origin.x }
        set(x){ origin.x=x }
    }
    public var y: Double {
        get { return origin.y }
        set(y){ origin.y=y }
    }
    public var z: Double {
        get { return origin.z }
        set(z){ origin.z=z }
    }
    public var w: Double {
        get { return size.x }
        set(width){ size.x=width }
    }
    public var h: Double {
        get { return size.y }
        set(height){ size.y=height }
    }
    public var d: Double {
        get { return size.z }
        set(depth){ size.z=depth }
    }
    public var width: Double {
        get { return size.x }
        set(width){ size.x=width }
    }
    public var height: Double {
        get { return size.y }
        set(height){ size.y=height }
    }
    public var depth: Double {
        get { return size.z }
        set(depth){ size.z=depth }
    }
    public var left: Double {
        get { return x }
        set(l) { w+=x-l; x=l }
    }
    public var right: Double {
        get { return x+width }
        set(r) { width=r-x }
    }
    public var top: Double {
        get { return y }
        set(t) { h+=y-t; y=t }
    }
    public var bottom: Double {
        get { return y+h }
        set(b) { h=b-y }
    }
    public var front: Double {
        get { return z }
        set(t) { d+=z-t; z=t }
    }
    public var back: Double {
        get { return z+d }
        set(t) { depth=t-z }
    }
    public var opposite : Vec3 {
        return origin+size
    }
    public var center : Vec3 {
        return origin + size * 0.5
    }
    public func point(_ px:Double,_ py:Double,_ pz:Double) -> Vec3 {
        return Vec3(x:x+width*px,y:y+height*py,z:z+depth*pz)
    }
    public var diagonale : Double {
        return sqrt(width*width+height*height+depth*depth)
    }
    public var random : Vec3 {
        return Vec3(x:x+width*ß.rnd,y:y+height*ß.rnd,z:z+depth*ß.rnd)
    }
    public func union(_ r:Box) -> Box {
        if self == Box.zero {
            return r
        } else if r == Box.zero {
            return self
        } else {
            var rr = Box.zero
            rr.left = min(self.left,r.left)
            rr.right = max(self.right,r.right)
            rr.top = min(self.top,r.top)
            rr.bottom = max(self.bottom,r.bottom)
            rr.front = min(self.front,r.front)
            rr.back = max(self.back,r.back)
            return rr
        }
    }
    public func union(_ o:Vec3,_ s:Vec3=Vec3.zero) -> Box {
        return self.union(Box(o:o,s:s))
    }
    public func wrap(_ p:Vec3) -> Vec3 {
        return Vec3(x:ß.modulo(p.x-left,width)+left,y:ß.modulo(p.y-top,height)+top,z:ß.modulo(p.z-front,depth)+front)
    }
    public init(center:Vec3 = .zero,size:Vec3 = .unity) {
        self.origin=center-size*0.5
        self.size=size
    }
    public init(origin:Vec3,size:Vec3=Vec3.unity) {
        self.origin=origin
        self.size=size
    }
    public init(o:Vec3,s:Vec3) {
        self.origin=o
        self.size=s
    }
    public init(x:Double,y:Double,z:Double,w:Double,h:Double,d:Double)
    {
        origin=Vec3(x:x,y:y,z:z)
        size=Vec3(x:w,y:h,z:d)
    }
    public static var zero: Box {
        return Box(o:Vec3.zero,s:Vec3.zero)
    }
    public static var infinity: Box {
        return Box(o:-Vec3.infinity,s:Vec3.infinity)
    }
    public static var unity: Box {
        return Box(o:Vec3.zero,s:Vec3(x:1,y:1,z:1))
    }
    public static func ==(lhs: Box, rhs: Box) -> Bool {
        return (lhs.origin==rhs.origin)&&(lhs.size==rhs.size)
    }
    public static func !=(lhs: Box, rhs: Box) -> Bool {
        return (lhs.origin != rhs.origin)||(lhs.size != rhs.size)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Box : MaterialProvider {
    var materials: [String : Material] {
        return ["default":Material(name:"default")]
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Box:MeshProvider {
    public var defaultFactor: Int { return 1 }
    public func mesh(factor: Int = 1,inverse:Bool=false) -> Mesh {
        var mesh=Mesh(name:"Box.1",winding: inverse ? .clockwise : .counterClockwise)
        let mat = "default"
        mesh.faces[mat]=[UInt32]()
        let addfaces : ((Int,Int,Int,Int,Bool)->()) = { v0,v1,v2,v3,invers in
            if !invers {
                mesh.faces[mat]!.append(UInt32(v0))
                mesh.faces[mat]!.append(UInt32(v1))
                mesh.faces[mat]!.append(UInt32(v2))
                mesh.faces[mat]!.append(UInt32(v2))
                mesh.faces[mat]!.append(UInt32(v3))
                mesh.faces[mat]!.append(UInt32(v0))
            } else {
                mesh.faces[mat]!.append(UInt32(v2))
                mesh.faces[mat]!.append(UInt32(v1))
                mesh.faces[mat]!.append(UInt32(v0))
                mesh.faces[mat]!.append(UInt32(v0))
                mesh.faces[mat]!.append(UInt32(v3))
                mesh.faces[mat]!.append(UInt32(v2))
            }
        }
        for x in 0...1 {
            let dx = x*2 - 1
            let n = inverse ? Vec3(x:Double(-dx),y:0,z:0) : Vec3(x:Double(dx),y:0,z:0)
            let v0 = mesh.vertices.appendIndex(Vertex(position:point(Double(x),0,0),normal:n,color:.white))
            let v1 = mesh.vertices.appendIndex(Vertex(position:point(Double(x),1,0),normal:n,color:.white))
            let v2 = mesh.vertices.appendIndex(Vertex(position:point(Double(x),1,1),normal:n,color:.white))
            let v3 = mesh.vertices.appendIndex(Vertex(position:point(Double(x),0,1),normal:n,color:.white))
            addfaces(v0,v1,v2,v3,x==0)
        }
        for y in 0...1 {
            let dy = y*2 - 1
            let n = inverse ? Vec3(x:0,y:Double(-dy),z:0) : Vec3(x:0,y:Double(dy),z:0)
            let v0 = mesh.vertices.appendIndex(Vertex(position:point(0,Double(y),0),normal:n,color:.white))
            let v1 = mesh.vertices.appendIndex(Vertex(position:point(1,Double(y),0),normal:n,color:.white))
            let v2 = mesh.vertices.appendIndex(Vertex(position:point(1,Double(y),1),normal:n,color:.white))
            let v3 = mesh.vertices.appendIndex(Vertex(position:point(0,Double(y),1),normal:n,color:.white))
            addfaces(v0,v1,v2,v3,y==1)
        }
        for z in 0...1 {
            let dz = z*2 - 1
            let n = inverse ? Vec3(x:0,y:0,z:Double(-dz)) : Vec3(x:0,y:0,z:Double(dz))
            let v0 = mesh.vertices.appendIndex(Vertex(position:point(0,0,Double(z)),normal:n,color:.white))
            let v1 = mesh.vertices.appendIndex(Vertex(position:point(1,0,Double(z)),normal:n,color:.white))
            let v2 = mesh.vertices.appendIndex(Vertex(position:point(1,1,Double(z)),normal:n,color:.white))
            let v3 = mesh.vertices.appendIndex(Vertex(position:point(0,1,Double(z)),normal:n,color:.white))
            addfaces(v0,v1,v2,v3,z==0)
        }
        return mesh
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct Land {
    var origin:Vec3
    var size:Size
    init(origin:Vec3,size:Size = .unity) {
        self.origin = origin
        self.size = size
    }
    init(center:Vec3 = .zero,size:Size = .unity) {
        self.origin = center + Vec3(x:size.w,y:size.h, z:0) * 0.5
        self.size = size
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Land : MaterialProvider {
    var materials: [String : Material] {
        return ["default":Material(name:"default")]
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Land:MeshProvider {
    public var defaultFactor: Int { return 1 }
    public func mesh(factor factor0: Int = 1,inverse:Bool=false) -> Mesh {
        let factor = factor0 + 1
        var mesh = Mesh(name:"Plan.\(factor)",winding: .counterClockwise)
        let d = 1 / Double(factor)
        let n = Vec3(x: 0, y: 0, z: 1).normalized
        var vertices = [Vertex](
            repeating: Vertex(position: .zero, normal: .zero, uv: .zero, color: .black),
            count: factor * factor)
        var nv = 0
        var y = 0.0
        let sz = Vec3(size.w,size.h,1)
        let invN:Double = inverse ? -1 : 1
        for yi in 0..<factor {
            var x = (yi & 1) == 0 ? 0 : d * 0.5
            for _ in 0..<factor {
                let p = Vec3(x: (x - 0.5) * 2, y: (y - 0.5) * 2, z: 0)
                vertices[nv] = Vertex(position: p*sz+origin, normal: invN*n, uv: Point(x: x, y: y))
                nv += 1
                x += d
            }
            y += d
        }
        mesh.vertices = vertices
        let mat = "default"
        var f = [UInt32](repeating: 0, count: (factor - 1) * (factor - 1) * 2 * 3)
        var nf = 0
        let addFace: (UInt32, UInt32, UInt32) -> Void = { v0, v1, v2 in
            f[nf] = v0
            nf += 1
            f[nf] = v1
            nf += 1
            f[nf] = v2
            nf += 1
        }
        for yi in 0..<factor - 1 {
            let ypair = (yi & 1) == 0
            var x = yi * factor
            var nx = x + factor
            for _ in 0..<factor - 1 {
                if ypair {
                    addFace(UInt32(x), UInt32(x + 1), UInt32(nx))
                    addFace(UInt32(x + 1), UInt32(nx + 1), UInt32(nx))
                } else {
                    addFace(UInt32(x), UInt32(nx + 1), UInt32(nx))
                    addFace(UInt32(x), UInt32(x + 1), UInt32(nx + 1))
                }
                x += 1
                nx += 1
            }
        }
        mesh.faces[mat] = f
        return mesh
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
