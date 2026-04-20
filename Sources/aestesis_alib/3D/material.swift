//
//  material.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 13/02/2024.
//

import Foundation

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct Material {
    var name:String
    var blend:BlendMode = .opaque
    var ambient:Color = Color(a: 1, l: 0.3)
    var diffuse:Color = Color(a: 1, l: 0.3)
    var specular:Color = .white
    var shininess:Double = 2
    var texture:String?
    var transparent : Bool { return blend != .opaque }
    init(name:String = "default", blend:BlendMode = .opaque, ambient:Color = Color(a:1,l:0.25), diffuse:Color = Color(a:1,l:0.3), specular:Color = Color(a:1,l:0.6), shininess: Double = 2, texture:String? = nil) {
        self.name = name
        self.blend = blend
        self.ambient = ambient
        self.diffuse = diffuse
        self.specular = specular
        self.shininess = shininess
        self.texture = texture
    }
    static func dictionnary(materials:[Material]) -> [String:Material] {
        var mat:[String:Material] = [:]
        for m in materials {
            mat[m.name] = m
        }
        return mat
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

