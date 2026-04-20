//
//  LUT.swift
//  Alib
//
//  Created by renan jegouzo on 09/11/2017.
//  Copyright © 2017 aestesis. All rights reserved.
//

import Foundation

// kernel opti
// swift: https://gist.github.com/wakita/f4915757c6c6c128c05c8680cd859e1a
// hsl kernel: https://stackoverflow.com/questions/52627082/color-conversion-rgb-to-hsl-using-core-image-kernel-language

// idea: keep a lut of normal HSB values
// and pass it to a kernel to add decal and convert to rgb

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class LUT : JsonConvertible {
    public var title:String
    public var colors:[Color]
    public private(set) var size:Int
    public init(size:Int) {
        self.title = "default"
        self.size = size
        self.colors = [Color](repeating:.black,count:size*size*size)
        var c = 0
        for bi in 0..<size {
            let b = Double(bi)/Double(size-1)
            for gi in 0..<size {
                let g = Double(gi)/Double(size-1)
                for ri in 0..<size {
                    let r = Double(ri)/Double(size-1)
                    self.colors[c] = Color(a:0,r:r,g:g,b:b)
                    c += 1
                }
            }
        }
    }
    public init(title:String="lut",size:Int,decal:HSLA) {
        self.title = title
        self.size = size
        self.colors = [Color](repeating:.black,count:size*size*size)
        var c = 0
        for bi in 0..<size {
            let b = Double(bi)/Double(size-1)
            for gi in 0..<size {
                let g = Double(gi)/Double(size-1)
                for ri in 0..<size {
                    let r = Double(ri)/Double(size-1)
                    let hsla = Color(a:0,r:r,g:g,b:b).hsla
                    self.colors[c] = Color(hsla:(hsla+decal).saturated)
                    c += 1
                }
            }
        }
    }
    public init(title:String="lut",size:Int,decal:HSBA) {
        self.title = title
        self.size = size
        self.colors = [Color](repeating:.black,count:size*size*size)
        var c = 0
        for bi in 0..<size {
            let b = Double(bi)/Double(size-1)
            for gi in 0..<size {
                let g = Double(gi)/Double(size-1)
                for ri in 0..<size {
                    let r = Double(ri)/Double(size-1)
                    let hsba = Color(a:0,r:r,g:g,b:b).hsba
                    self.colors[c] = Color(hsba:(hsba+decal).saturated)
                    c += 1
                }
            }
        }
    }
    public init(title:String="lut",size:Int) {
        self.title = title
        self.size = size
        self.colors = [Color](repeating:.black,count:size*size*size)
        var c = 0
        for bi in 0..<size {
            let b = Double(bi)/Double(size-1)
            for gi in 0..<size {
                let g = Double(gi)/Double(size-1)
                for ri in 0..<size {
                    let r = Double(ri)/Double(size-1)
                    self.colors[c] = Color(a:1,r:r,g:g,b:b)
                    c += 1
                }
            }
        }
    }
    public init?(url:URL) {
        // https://forum.blackmagicdesign.com/viewtopic.php?f=21&t=40284
        guard url.isFileURL else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        self.title = "lut"
        self.size = 0
        self.colors = [Color]()
        do {
            let data:String = try String(contentsOfFile: url.path, encoding: .utf8)
            for li in data.split("\n") {
                let l = li.replacingOccurrences(of: "\r", with: "")
                if l.length>0 && l[0] != "#" {
                    let w = l.split(" ")
                    let cmd = w[0]
                    if cmd == "TITLE" {
                        self.title = w[1].replacingOccurrences(of: "\"", with: "")
                    } else if cmd == "LUT_3D_SIZE" {
                        self.size = Int(w[1])!
                    } else if cmd == "LUT_3D_INPUT_RANGE" {
                        Debug.info("invalid lut file \(url), not implemented")
                        return nil
                    } else if cmd == "LUT_1D_SIZE" {
                        Debug.error("invalid lut file \(url), not implemented")
                        return nil
                    } else if cmd == "LUT_1D_INPUT_RANGE" {
                    } else if w.count>2, let r = Double(w[0]), let g = Double(w[1]), let b = Double(w[2]) {
                        self.colors.append(Color(a:1,r:r,g:g,b:b).saturated)
                    }
                }
            }
        } catch {
            Debug.warning(error.localizedDescription)
        }
    }
    public func save(as:String) {
        Debug.notImplemented()
    }
    public func createTexture2D(parent:NodeUI) -> Texture2D {
        let b = Texture2D(parent:parent,size:Size(Double(self.size),Double(self.size*self.size)))
        var data = [UInt32](repeating:0,count:colors.count)
        var i = 0
        for c in colors {
            data[i] = c.bgra
            i += 1
        }
        b.set(pixels:data)
        return b
    }
    public func createTexture3D(parent:NodeUI) -> Texture3D {
        var data = [UInt32](repeating:0,count:colors.count)
        var i = 0
        for c in colors {
            data[i] = c.bgra
            i += 1
        }
        return Texture3D(parent:parent,size:size,pixels:data)
    }
    public var data:[UInt32] {
        return colors.map { $0.bgra }
    }
    public func transform(color c:Color) -> Color {
        let sz = Double(size - 1)
        let r = c.r * sz
        let g = c.g * sz
        let b = c.b * sz
        let ri = Int(r)
        let gi = Int(g)
        let bi = Int(b)
        let dr = r - Double(ri)
        let dg = g - Double(gi)
        let db = b - Double(bi)
        var color = Color.black
        if dr == 0 {
            color = color + self[ri,gi,bi]
        } else {
            color = color + self[ri,gi,bi] * (1-dr) + self[ri+1,gi,bi] * dr
        }
        if dg == 0 {
            color = color + self[ri,gi,bi]
        } else {
            color = color + self[ri,gi,bi] * (1-dg) + self[ri,gi+1,bi] * dg
        }
        if db == 0 {
            color = color + self[ri,gi,bi]
        } else {
            color = color + self[ri,gi,bi] * (1-db) + self[ri,gi,bi+1] * db
        }
        return Color(a:1, rgb:color * 1.0/3.0)
    }
    public subscript(r:Int,g:Int,b:Int) -> Color {
        get {
            return colors[b*size*size+g*size+r]
        }
        set(v) {
            colors[b*size*size+g*size+r] = v
        }
    }
    public subscript(r:Double,g:Double,b:Double) -> Color {
        get {
            let sz = Double(size)-0.0001
            return self[Int(r*sz),Int(g*sz),Int(b*sz)]
        }
    }
    public var json:JSON {
        return JSON([
            "title":title,
            "size":size,
            "colors":colors.map { $0.json }
        ])
    }
    public required init(json:JSON) {
        title = json["title"].string ?? "lut"
        size = json["size"].int ?? 0
        colors = json["colors"].arrayValue.map { Color(json:$0) }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class FastLUT {
    let size:Int
    var data:[UInt32]
    init(size:Int,data:[UInt32]) {
        self.size = size
        self.data = data
        if data.count != size*size*size {
            Debug.error("wrong data size \(data.count) for lut \(size)x\(size)x\(size)")
        }
    }
    init(size:Int,identity:Bool) {
        self.size = size
        data = [UInt32](repeating:0,count:size*size*size)
        if identity {
            var c = 0
            for bi in 0..<size {
                let b = Double(bi)/Double(size-1)
                for gi in 0..<size {
                    let g = Double(gi)/Double(size-1)
                    for ri in 0..<size {
                        let r = Double(ri)/Double(size-1)
                        self.data[c] = Color(a:0,r:r,g:g,b:b).bgra
                        c += 1
                    }
                }
            }
        }
    }
    init(lut:LUT) {
        size = lut.size
        data = lut.data
    }
    public subscript(r:Int,g:Int,b:Int) -> Color {
        get {
            return Color(bgra:data[b*size*size+g*size+r])
        }
        set(v) {
            data[b*size*size+g*size+r] = v.bgra
        }
    }
    public func createTexture3D(parent:NodeUI) -> Texture3D {
        return Texture3D(parent:parent,size:size,pixels:data)
    }
    public func createBitmap(parent:NodeUI) -> Bitmap {
        let t = Bitmap(parent:parent,size:Size(size*size,size))
        t.set(pixels: data)
        return t
    }
    static func generate(viewport:Viewport,size:Int,decal:HSBA,fn:@escaping (FastLUT?)->())  {
        let destination = Bitmap(parent:viewport,size:Size(Double(size*size),Double(size)))
        let g = Graphics(image:destination)
        g.generateLut(destination.bounds, lutSize: size, hsvDecal: decal.hsb)
        g.onDone { ok in
            switch ok {
            case .success:
                guard let data = destination.get() else {
                    Debug.error("FastLUT.generate() no data")
                    fn(nil)
                    destination.detach()
                    return
                }
                let lut = FastLUT(size:size,data:data)
                fn(lut)
            case .error(let message):
                Debug.error("FastLut.generate() \(message)")
                fn(nil)
            default:
                Debug.warning("FastLut.generate() discarded")
                fn(nil)
            }
        }
        destination.detach()
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
