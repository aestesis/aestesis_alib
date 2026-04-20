//
//  Texture3D.swift
//  Alib
//
//  Created by renan jegouzo on 09/11/2017.
//  Copyright © 2017 aestesis. All rights reserved.
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

#if os(OSX)
import Metal
import CoreGraphics
import AppKit
#elseif os(iOS) || os(tvOS)
import Metal
import CoreGraphics
import UIKit
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Texture3D : NodeUI {
    public private(set) var texture:MTLTexture?
    public private(set) var size : Vec3
    public init(parent:NodeUI,size:Int,pixels:[UInt32]? = nil) {
        self.size = Vec3(Double(size),Double(size),Double(size))
        super.init(parent: parent)
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = size
        textureDescriptor.height = size
        textureDescriptor.depth = size
        textureDescriptor.usage = .shaderRead
        self.texture=viewport?.gpu.device?.makeTexture(descriptor:textureDescriptor)
        if let texture=texture, let pixels = pixels {
            pixels.withUnsafeBytes { bytes in
                texture.replace(region: MTLRegionMake3D(0, 0, 0, size, size, size),
                                mipmapLevel:0,
                                slice:0,
                                withBytes:bytes.baseAddress!,
                                bytesPerRow:size * MemoryLayout<UInt32>.size,
                                bytesPerImage:size * size * MemoryLayout<UInt32>.size)
            }
        }
    }
    override public func detach() {
        self.texture = nil
        super.detach()
    }
    public func get() -> [UInt32]? {
        if let t=texture {
            var data=[UInt32](repeating:0,count:Int(size.x*size.y*size.z))
            data.withUnsafeMutableBytes { bytes in
                t.getBytes(bytes.baseAddress!,bytesPerRow:Int(size.x)*4,from: MTLRegion(origin:MTLOrigin(x:0,y:0,z:0),size:MTLSize(width:Int(size.x),height:Int(size.y),depth:Int(size.z))),mipmapLevel:0)
            }
            return data
        } else {
            Debug.error(Error("no texture"))
        }
        return nil
    }
    public func set(pixels:[UInt32]) {
        if let texture=texture {
            pixels.withUnsafeBytes { bytes in
                texture.replace(region:MTLRegion(origin:MTLOrigin(x:0,y:0,z:0),size:MTLSize(width:Int(size.x),height:Int(size.y),depth:Int(size.z))),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:Int(size.x)*4)
            }
        }
    }
    public func set(pixels:[UInt32],depth:Int) {
        if let texture=texture {
            pixels.withUnsafeBytes { bytes in
                texture.replace(region:MTLRegion(origin:MTLOrigin(x:0,y:0,z:depth),size:MTLSize(width:Int(size.x),height:Int(size.y),depth:Int(1))),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:Int(size.x)*4)
            }
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

