//
//  mesh.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 12/02/2024.
//

import Foundation
import simd

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class MeshOld : NodeRenderer {
    public let onInitialized = Event<Void>()
    var initialized=false
    var needsVerticesUpdate=true
    var bufferVertices:Buffer?
    var needsFacesUpdate=true
    var bufferFaces=[String:Buffer]()
    public var vertices=[Vertex]() {
        didSet {
            needsVerticesUpdate = true
        }
    }
    public var faces=[String:[Int32]]() {
        didSet {
            needsFacesUpdate = true
        }
    }
    var bones = [Bone]()
    public var facesCount : Int {
        var n = 0
        for m in faces.keys {
            if let f=faces[m] {
                n += f.count/3
            }
        }
        return n
    }
    public var verticesCount : Int {
        return vertices.count
    }
    override open func detach() {
        if let b=bufferVertices {
            b.detach()
            bufferVertices=nil
        }
        for m in bufferFaces.keys {
            if let b=bufferFaces[m] {
                b.detach()
            }
        }
        bufferFaces.removeAll()
        onInitialized.removeAll()
        super.detach()
    }
    public func appendFace(material:String,v0:Int32,v1:Int32,v2:Int32)  {
        faces[material]!.append(v0)
        faces[material]!.append(v1)
        faces[material]!.append(v2)
    }
    public func appendVertice(position:Vec3,normal:Vec3,uv:Point) -> Int32 {
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
    public func dispatchInitialized() {
        self.initialized=true
        self.onInitialized.dispatch(())
    }
    public override init(parent:NodeUI) {
        super.init(parent:parent)
    }
    public init(parent:NodeUI,path:String) {
        super.init(parent:parent)
        self.io {
            if path.contains(".obj") {  // https://en.wikipedia.org/wiki/Wavefront_.obj_file
                Application.readText(path) { text in
                    var lvert=[Vec3]()
                    var lnorm=[Vec3]()
                    var luv=[Point]()
                    var mat = "alib.default"
                    self.faces[mat] = [Int32]()
                    let decodeVertice:((String)->(Int)) = { s in
                        let e=s.split("/")
                        switch e.count {
                        case 1:
                            if let iv=Int(s){
                                let v=Vertex(position:lvert[iv-1])
                                if let i = self.index(vertice:v) {
                                    return i
                                } else {
                                    self.vertices.append(v)
                                    return self.vertices.count-1
                                }
                            } else {
                                Debug.error("corrupted obj file")
                            }
                        case 2:
                            if let iv=Int(e[0]), let iuv=Int(e[1]) {
                                let v=Vertex(position:lvert[iv-1],uv:luv[iuv-1])
                                if let i = self.index(vertice:v) {
                                    return i
                                } else {
                                    self.vertices.append(v)
                                    return self.vertices.count-1
                                }
                            } else {
                                Debug.error("corrupted obj file")
                            }
                        case 3:
                            if let iv=Int(e[0]), let iuv=Int(e[1]), let inorm=Int(e[2]) {
                                let v=Vertex(position:lvert[iv-1],normal:lnorm[inorm-1],uv:luv[iuv-1])
                                if let i = self.index(vertice:v) {
                                    return i
                                } else {
                                    self.vertices.append(v)
                                    return self.vertices.count-1
                                }
                            } else if let iv=Int(e[0]), let inorm=Int(e[2]) {
                                let v=Vertex(position:lvert[iv-1],normal:lnorm[inorm-1])
                                if let i = self.index(vertice:v) {
                                    return i
                                } else {
                                    self.vertices.append(v)
                                    return self.vertices.count-1
                                }
                            } else {
                                Debug.error("corrupted obj file")
                            }
                        default:
                            Debug.error("corrupted obj file")
                        }
                        return 0
                    }
                    if let text=text {
                        while let t=text.readLine() {
                            if t.length>0 && t[0] != "#" {
                                let p = t.splitByEach(" \t")
                                let cmd = p[0]
                                let args = t[cmd.length..<t.length].trim()
                                if (cmd == "v") {
                                    if let x=Double(p[1]), let y=Double(p[2]), let z=Double(p[3]) {
                                        lvert.append(Vec3(x:x,y:y,z:z))
                                    } else {
                                        Debug.error("corrupted obj file")
                                        lvert.append(Vec3())
                                    }
                                } else if (cmd == "vn") {
                                    if let x=Double(p[1]), let y=Double(p[2]), let z=Double(p[3]) {
                                        lnorm.append(Vec3(x:x,y:y,z:z))
                                    } else {
                                        Debug.error("corrupted obj file")
                                        lnorm.append(Vec3())
                                    }
                                } else if (cmd == "vt") {
                                    if let x=Double(p[1]), let y=Double(p[2]) {
                                        luv.append(Point(x:x,y:y))
                                    } else {
                                        Debug.error("corrupted obj file")
                                        luv.append(Point.zero)
                                    }
                                } else if (cmd == "g") {
                                    //string gname = p[1];    // group
                                } else if(cmd=="mtllib") {
                                    let mtlfile = args    // fichier mtl
                                    let p = path[0...path.lastIndexOf("/")!]+mtlfile[mtlfile.lastIndexOf("/")!+1..<mtlfile.length]
                                    Application.readText(p) { reader in
                                        var skip = false
                                        var cmat:MaterialOld? = nil
                                        if let reader = reader {
                                            while let t = reader.readLine() {
                                                let p = t.splitByEach(" \t")
                                                let cmd = p[0]
                                                let args = t[cmd.length..<t.length].trim()
                                                if cmd == "newmtl" {
                                                    let name=args
                                                    mat = "material.\(path).\(name)"
                                                    if let m = self[mat] as? MaterialOld {
                                                        skip = true
                                                        cmat = m
                                                    } else {
                                                        skip = false
                                                        if let db = self.db {
                                                            cmat = MaterialOld(parent:db,name:"\(path).\(name)")
                                                            db[mat] = cmat
                                                        }
                                                    }
                                                    self.faces[mat] = [Int32]()
                                                } else if !skip {
                                                    if cmd == "Ka" {
                                                        cmat!.ambient = Color(a:1,rgb:Color(a:1,r:Double(p[1])!,g:Double(p[2])!,b:Double(p[3])!))
                                                    } else if cmd == "Kd" {
                                                        cmat!.diffuse = Color(a:1,r:Double(p[1])!,g:Double(p[2])!,b:Double(p[3])!)
                                                        cmat!.ambient = cmat!.diffuse * cmat!.ambient * 0.4
                                                        //Debug.info("material color: \(mat.diffuse)")
                                                    } else if cmd == "Ks" {
                                                        cmat!.specular = Color(a:1,r:Double(p[1])!,g:Double(p[2])!,b:Double(p[3])!)
                                                    } else if cmd == "Ns" {
                                                        cmat!.shininess = Double(p[1])!
                                                    } else if cmd == "map_Kd" {
                                                        var pt = args
                                                        if args.contains("/") {
                                                            pt = path[0...path.lastIndexOf("/")!]+args[mtlfile.lastIndexOf("/")!+1..<mtlfile.length]
                                                        } else {
                                                            pt = path[0...path.lastIndexOf("/")!]+args
                                                        }
                                                        cmat!.setTexture(path:pt)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else if (cmd == "usemtl") {
                                    mat = "material.\(path).\(args)"
                                } else if (cmd == "s") {
                                    //string v = p[1];      // smooth mode
                                } else if (cmd == "f") {
                                    switch p.count-1 {
                                    case 3: // triangle
                                        self.faces[mat]!.append(Int32(decodeVertice(p[1])))
                                        self.faces[mat]!.append(Int32(decodeVertice(p[2])))
                                        self.faces[mat]!.append(Int32(decodeVertice(p[3])))
                                    case 4: // quad
                                        let v0=Int32(decodeVertice(p[1]))
                                        let v1=Int32(decodeVertice(p[2]))
                                        let v2=Int32(decodeVertice(p[3]))
                                        let v3=Int32(decodeVertice(p[4]))
                                        self.faces[mat]!.append(v0)
                                        self.faces[mat]!.append(v1)
                                        self.faces[mat]!.append(v2)
                                        self.faces[mat]!.append(v2)
                                        self.faces[mat]!.append(v3)
                                        self.faces[mat]!.append(v0)
                                    default:
                                        Debug.error("corrupted obj file")
                                    }
                                }
                            }
                        }
                    } else {
                        Debug.error("obj file not found: \(path)")
                    }
                    if lnorm.count == 0 {
                        self.computeNormals()
                    }
                    Debug.info("obj \(path) initialized")
                }
            } else if path.contains(".md3") {   // https://www.icculus.org/homepages/phaethon/q3a/formats/md3format.html
                // TODO:
                Debug.notImplemented()
            } else if path.contains(".iqm") {   // http://sauerbraten.org/iqm/iqm.txt
                // TODO:
                Debug.notImplemented()
            } else {
                Debug.error("unknow 3d file format \(path)")
            }
        }
    }
    public init(parent:NodeUI,sphere:Sphere,factor:Int=16) {
        super.init(parent:parent)
        self.zz {
            for j in 0...factor {
                let theta = ß.π*Double(j)/Double(factor)
                let stheta = sin(theta)
                let ctheta = cos(theta)
                for i in 0..<factor {
                    let phi = 2*ß.π*Double(i)/Double(factor)
                    let p = Vec3(x:stheta*cos(phi),y:stheta*sin(phi),z:ctheta)
                    self.vertices.append(Vertex(position:p,normal:p.normalized,uv:Point(x:Double(i)/Double(factor),y:Double(j)/Double(factor))))
                }
            }
            let mat = "material.default"
            self.faces[mat] = [Int32]()
            for j in 0..<factor {
                for i in 0..<factor-1 {
                    let first = j*factor + i
                    let second = first + factor
                    let first1 = first+1
                    let second1 = second+1
                    self.faces[mat]!.append(Int32(first))
                    self.faces[mat]!.append(Int32(second))
                    self.faces[mat]!.append(Int32(first1))
                    self.faces[mat]!.append(Int32(second))
                    self.faces[mat]!.append(Int32(second1))
                    self.faces[mat]!.append(Int32(first1))
                }
                let first = j*factor + factor - 1
                let second = first + factor
                let first1 = j*factor
                let second1 = first1 + factor
                self.faces[mat]!.append(Int32(first))
                self.faces[mat]!.append(Int32(second))
                self.faces[mat]!.append(Int32(first1))
                self.faces[mat]!.append(Int32(second))
                self.faces[mat]!.append(Int32(second1))
                self.faces[mat]!.append(Int32(first1))
            }
            self.dispatchInitialized()
        }
    }
    public init(parent:NodeUI,cylinder:Cylinder,factor:Int=20) {
        super.init(parent:parent)
        self.zz {
            let mat = "material.default"
            self.faces[mat]=[Int32]()
            if cylinder.direction != Vec3(y:1) {
                Debug.notImplemented()
            }
            var y = cylinder.center - cylinder.direction*0.5
            let dy = cylinder.direction
            for _ in 0...1 {
                for ai in 0..<factor {
                    let a = ß.π * 2 * Double(ai) / Double(factor)
                    let n = Vec3(x:cos(a),y:0,z:sin(a))
                    let p = y + n * cylinder.radius
                    self.vertices.append(Vertex(position:p,normal:n))
                }
                y += dy
            }
            for ai in 0..<factor {
                let p0 = ai
                let p3 = ai + factor
                let p1 = (ai<factor-1) ? p0+1 : p0 - (factor - 1)
                let p2 = (ai<factor-1) ? p3+1 : p3 - (factor - 1)
                self.faces[mat]!.append(Int32(p0))
                self.faces[mat]!.append(Int32(p1))
                self.faces[mat]!.append(Int32(p2))
                self.faces[mat]!.append(Int32(p2))
                self.faces[mat]!.append(Int32(p3))
                self.faces[mat]!.append(Int32(p0))
            }
            y = cylinder.center - cylinder.direction*0.5
            var n = Vec3(y:-1)
            for _ in 0...1 {
                for ai in 0..<factor {
                    let a = ß.π * 2 * Double(ai) / Double(factor)
                    let p = y + Vec3(x:cos(a),y:0,z:sin(a)) * cylinder.radius
                    self.vertices.append(Vertex(position:p,normal:n))
                }
                y += dy
                n = Vec3(y:1)
            }
            let s0 = factor * 2
            let s1 = factor * 3
            let c0 = self.vertices.count
            self.vertices.append(Vertex(position:cylinder.center - cylinder.direction*0.5,normal:Vec3(y:-1)))
            let c1 = self.vertices.count
            self.vertices.append(Vertex(position:cylinder.center + cylinder.direction*0.5,normal:Vec3(y:1)))
            for i in 0..<factor {
                self.faces[mat]!.append(Int32(c0))
                self.faces[mat]!.append(Int32(s0+i))
                if i < factor-1 {
                    self.faces[mat]!.append(Int32(s0+i+1))
                } else {
                    self.faces[mat]!.append(Int32(s0))
                }
                self.faces[mat]!.append(Int32(c1))
                if i < factor-1 {
                    self.faces[mat]!.append(Int32(s1+i+1))
                } else {
                    self.faces[mat]!.append(Int32(s1))
                }
                self.faces[mat]!.append(Int32(s1+i))
            }
            self.dispatchInitialized()
        }
    }
    public init(parent:NodeUI,box:Box,inversNormals:Bool) {
        super.init(parent:parent)
        self.zz {
            let mat = "material.default"
            self.faces[mat]=[Int32]()
            let addfaces : ((Int,Int,Int,Int,Bool)->()) = { v0,v1,v2,v3,invers in
                if !invers {
                    self.faces[mat]!.append(Int32(v0))
                    self.faces[mat]!.append(Int32(v1))
                    self.faces[mat]!.append(Int32(v2))
                    self.faces[mat]!.append(Int32(v2))
                    self.faces[mat]!.append(Int32(v3))
                    self.faces[mat]!.append(Int32(v0))
                } else {
                    self.faces[mat]!.append(Int32(v2))
                    self.faces[mat]!.append(Int32(v1))
                    self.faces[mat]!.append(Int32(v0))
                    self.faces[mat]!.append(Int32(v0))
                    self.faces[mat]!.append(Int32(v3))
                    self.faces[mat]!.append(Int32(v2))
                }
            }
            for x in 0...1 {
                let dx = x*2 - 1
                let n = inversNormals ? Vec3(x:Double(-dx),y:0,z:0) : Vec3(x:Double(dx),y:0,z:0)
                let v0 = self.vertices.appendIndex(Vertex(position:box.point(Double(x),0,0),normal:n,color:.white))
                let v1 = self.vertices.appendIndex(Vertex(position:box.point(Double(x),1,0),normal:n,color:.white))
                let v2 = self.vertices.appendIndex(Vertex(position:box.point(Double(x),1,1),normal:n,color:.white))
                let v3 = self.vertices.appendIndex(Vertex(position:box.point(Double(x),0,1),normal:n,color:.white))
                addfaces(v0,v1,v2,v3,x==0)
            }
            for y in 0...1 {
                let dy = y*2 - 1
                let n = inversNormals ? Vec3(x:0,y:Double(-dy),z:0) : Vec3(x:0,y:Double(dy),z:0)
                let v0 = self.vertices.appendIndex(Vertex(position:box.point(0,Double(y),0),normal:n,color:.white))
                let v1 = self.vertices.appendIndex(Vertex(position:box.point(1,Double(y),0),normal:n,color:.white))
                let v2 = self.vertices.appendIndex(Vertex(position:box.point(1,Double(y),1),normal:n,color:.white))
                let v3 = self.vertices.appendIndex(Vertex(position:box.point(0,Double(y),1),normal:n,color:.white))
                addfaces(v0,v1,v2,v3,y==1)
            }
            for z in 0...1 {
                let dz = z*2 - 1
                let n = inversNormals ? Vec3(x:0,y:0,z:Double(-dz)) : Vec3(x:0,y:0,z:Double(dz))
                let v0 = self.vertices.appendIndex(Vertex(position:box.point(0,0,Double(z)),normal:n,color:.white))
                let v1 = self.vertices.appendIndex(Vertex(position:box.point(1,0,Double(z)),normal:n,color:.white))
                let v2 = self.vertices.appendIndex(Vertex(position:box.point(1,1,Double(z)),normal:n,color:.white))
                let v3 = self.vertices.appendIndex(Vertex(position:box.point(0,1,Double(z)),normal:n,color:.white))
                addfaces(v0,v1,v2,v3,z==0)
            }
            self.dispatchInitialized()
        }
    }
    public func computeNormals() {
        var lfaces = [Int32:[(v1:Int32,v2:Int32)]]()
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
                    if lfaces[v0] == nil {
                        lfaces[v0] = [(v1:Int32,v2:Int32)]()
                    }
                    if lfaces[v1] == nil {
                        lfaces[v1] = [(v1:Int32,v2:Int32)]()
                    }
                    if lfaces[v2] == nil {
                        lfaces[v2] = [(v1:Int32,v2:Int32)]()
                    }
                    lfaces[v0]!.append((v1:v1,v2:v2))
                    lfaces[v1]!.append((v1:v2,v2:v0))
                    lfaces[v2]!.append((v1:v0,v2:v1))
                }
            }
        }
        for i in lfaces.keys {
            let v0 = vertices[Int(i)].position
            if let fl = lfaces[i] {
                var n = Vec3.zero
                for f in fl {
                    n = n + (vertices[Int(f.v1)].position-v0) ^ (vertices[Int(f.v2)].position-v0).normalized
                }
                let normal = (n/Double(fl.count)).normalized
                vertices[Int(i)].normal = normal
            }
        }
    }
    public func update() {
        if needsVerticesUpdate {
            needsVerticesUpdate=false
            if bufferVertices == nil {
                bufferVertices = self.persitentBuffer(MemoryLayout<GPUvertice>.stride*vertices.count)
            }
            if let bv=bufferVertices {
                let pv = bv.ptr.assumingMemoryBound(to: GPUvertice.self)
                for i in 0..<vertices.count {
                    let v = vertices[i]
                    pv[i] = GPUvertice(position:v.position.infloat3,color:v.color.infloat4,uv:v.uv.infloat2,normal:v.normal.infloat3)
                }
            }
            boundingBox = _boundingBox
        }
        if needsFacesUpdate {
            needsFacesUpdate=false
            for m in faces.keys {
                if let f=faces[m] {
                    if bufferFaces[m] == nil {
                        bufferFaces[m] = self.persitentBuffer(MemoryLayout<Float32>.stride*f.count)
                    }
                    if let bf = bufferFaces[m] {
                        let pv = bf.ptr.assumingMemoryBound(to: Float32.self)
                        memcpy(pv,f,MemoryLayout<Float32>.stride*f.count)
                    }
                }
            }
        }
    }
    public func render(to g:Graphics,world:Mat4,library:NodeUI,opaque:Bool) -> Bool {
        var transparency = false
        guard initialized else { return transparency }
        self.update()
        for kmat in faces.keys {
            var material = kmat
            while let m = library[material] as? String {
                material = m
            }
            if let mat = library[material] as? MaterialOld {
                if mat.transparent != opaque, let f=faces[kmat], let bv=bufferVertices, let bf=bufferFaces[kmat], f.count>0 {
                    mat.render(to:g,world:world,vertices:bv,faces:bf,count:f.count)
                }
                transparency = transparency || mat.transparent
            } else  {
                Debug.error("material \(material) not found. origin: \(kmat)")
            }
        }
        return transparency
    }
    public var boundingBox = Box.zero
    var _boundingBox : Box {
        guard vertices.count<=0 else { return Box.zero }
        var b = Box(o:vertices[0].position,s:Vec3.zero)
        for v in vertices {
            b = b.union(v.position)
        }
        return b
    }
    public var boundingSphere : Sphere {
        return Sphere(bounding:self.boundingBox)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
