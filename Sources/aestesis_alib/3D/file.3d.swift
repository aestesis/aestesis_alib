//
//  file.3d.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 13/02/2024.
//

import Foundation

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct File3D : MeshProvider,MaterialProvider {
    public var defaultFactor: Int { return 1 }
    public func mesh(factor: Int=0, inverse: Bool = false) -> Mesh {
        return mesh
    }
    var materials:[String:Material] = [:]
    var mesh:Mesh
    public mutating func load(owner:NodeUI,path:String) {
        // https://en.wikipedia.org/wiki/Wavefront_.obj_file
        if path.contains(".obj") {
            Application.readText(path) { text in
                var lvert=[Vec3]()
                var lnorm=[Vec3]()
                var luv=[Point]()
                var mat = "default"
                mesh.faces[mat] = []
                func decodeVertice(_ s:String) -> Int {
                    let e=s.split("/")
                    switch e.count {
                    case 1:
                        if let iv=Int(s){
                            let v=Vertex(position:lvert[iv-1])
                            if let i = mesh.index(vertice:v) {
                                return i
                            } else {
                                mesh.vertices.append(v)
                                return mesh.vertices.count-1
                            }
                        } else {
                            Debug.error("corrupted obj file")
                        }
                    case 2:
                        if let iv=Int(e[0]), let iuv=Int(e[1]) {
                            let v=Vertex(position:lvert[iv-1],uv:luv[iuv-1])
                            if let i = mesh.index(vertice:v) {
                                return i
                            } else {
                                mesh.vertices.append(v)
                                return mesh.vertices.count-1
                            }
                        } else {
                            Debug.error("corrupted obj file")
                        }
                    case 3:
                        if let iv=Int(e[0]), let iuv=Int(e[1]), let inorm=Int(e[2]) {
                            let v=Vertex(position:lvert[iv-1],normal:lnorm[inorm-1],uv:luv[iuv-1])
                            if let i = mesh.index(vertice:v) {
                                return i
                            } else {
                                mesh.vertices.append(v)
                                return mesh.vertices.count-1
                            }
                        } else if let iv=Int(e[0]), let inorm=Int(e[2]) {
                            let v=Vertex(position:lvert[iv-1],normal:lnorm[inorm-1])
                            if let i = mesh.index(vertice:v) {
                                return i
                            } else {
                                mesh.vertices.append(v)
                                return mesh.vertices.count-1
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
                                // TODO:
                            } else if(cmd=="mtllib") {
                                let mtlfile = args    // fichier mtl
                                let p = path[0...path.lastIndexOf("/")!]+mtlfile[mtlfile.lastIndexOf("/")!+1..<mtlfile.length]
                                Application.readText(p) { reader in
                                    var skip = false
                                    var cmat:Material? = nil
                                    if let reader = reader {
                                        while let t = reader.readLine() {
                                            let p = t.splitByEach(" \t")
                                            let cmd = p[0]
                                            let args = t[cmd.length..<t.length].trim()
                                            if cmd == "newmtl" {
                                                if let cmat=cmat {
                                                    materials[mat] = cmat
                                                }
                                                mat=args
                                                if let m = materials[mat] {
                                                    skip = true
                                                    cmat = m
                                                } else {
                                                    skip = false
                                                    cmat = Material(name:mat)
                                                }
                                                mesh.faces[mat] = []
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
                                                    if owner["material.texture.\(pt)"] != nil {
                                                        owner["material.texture.\(pt)"] = Bitmap(parent:owner,path:pt)
                                                        cmat!.texture = "material.texture.\(pt)"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    if let cmat=cmat {
                                        materials[mat] = cmat
                                    }
                                }
                            } else if (cmd == "usemtl") {
                                mat = args
                            } else if (cmd == "s") {
                                //string v = p[1];      // smooth mode
                            } else if (cmd == "f") {
                                switch p.count-1 {
                                case 3: // triangle
                                    mesh.faces[mat]!.append(UInt32(decodeVertice(p[1])))
                                    mesh.faces[mat]!.append(UInt32(decodeVertice(p[2])))
                                    mesh.faces[mat]!.append(UInt32(decodeVertice(p[3])))
                                case 4: // quad
                                    let v0=UInt32(decodeVertice(p[1]))
                                    let v1=UInt32(decodeVertice(p[2]))
                                    let v2=UInt32(decodeVertice(p[3]))
                                    let v3=UInt32(decodeVertice(p[4]))
                                    mesh.faces[mat]!.append(v0)
                                    mesh.faces[mat]!.append(v1)
                                    mesh.faces[mat]!.append(v2)
                                    mesh.faces[mat]!.append(v2)
                                    mesh.faces[mat]!.append(v3)
                                    mesh.faces[mat]!.append(v0)
                                default:
                                    Debug.error("corrupted obj file")
                                }
                            }
                        }
                    }
                    if mesh.faces["default"]!.isEmpty {
                        mesh.faces.removeValue(forKey: "default")
                    } else if mat == "default", !materials.has(key: mat) {
                        materials[mat] = Material(name:"default")
                    }
                } else {
                    Debug.error("obj file not found: \(path)")
                }
                if lnorm.count == 0 {
                    mesh.computeNormals()
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
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
