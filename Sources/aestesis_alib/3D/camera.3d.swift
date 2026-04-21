//
//  camera.3d.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 12/02/2024.
//

import Foundation
import simd

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// http://ksimek.github.io/2012/08/22/extrinsic/
public class Camera3D: Node3D, @unchecked Sendable {
    public var direction: Vec3
    public var up: Vec3
    public init(
        parent: Node3D, position: Vec3 = Vec3(z: -2), direction: Vec3 = Vec3(z: 1),
        up: Vec3 = Vec3.zero
    ) {
        self.direction = direction
        self.up = up
        super.init(parent: parent, matrix: Mat4.translation(position))
    }
    public func lookAt(node: Node3D) {
        self.direction = node.worldMatrix.translation - self.worldMatrix.translation
    }
    var viewMatrix: Mat4 {
        if up == .zero {
            return (Mat4.lookAt(direction: direction) * self.worldMatrix).inverse
        }
        return (Mat4.lookAt(eye: .zero, target: direction, up: up) * self.worldMatrix).inverse
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
