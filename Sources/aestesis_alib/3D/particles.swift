//
//  Extensions.swift
//  Alib
//
//  Created by renan jegouzo on 13/07/2017.
//  Copyright © 2017 aestesis. All rights reserved.
//

import Foundation
import Metal
import MetalKit

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class Particles: Node3D, @unchecked Sendable {
    public var box: Box
    public var direction = Vec3.zero
    var particles = [Particle]()
    var bufferParticles: Buffer?
    public init(parent: Node3D, matrix: Mat4, box: Box, count: Int = 100, material: String) {
        self.box = box
        super.init(parent: parent, matrix: matrix)
        self.createParticles(count: count)
        if material != "material.default" {
            self["material.default"] = material
        }
    }
    override open func detach() {
        if let bp = bufferParticles {
            bp.detach()
            bufferParticles = nil
        }
        super.detach()
    }
    func createParticles(count: Int) {
        for _ in 0..<count {
            particles.append(
                Particle(position: box.random, size: box.diagonale * 0.001, color: .white))
        }
    }
    open override func render(to g0: Graphics, world: Mat4, opaque: Bool) -> Bool {
        if !opaque {
            if direction != .zero {
                for i in 0..<particles.count {
                    particles[i].position = box.wrap(particles[i].position + direction)
                }
            }
            if bufferParticles == nil {
                bufferParticles = self.persitentBuffer(
                    MemoryLayout<GPUparticle>.stride * particles.count)
            }
            if let bp = bufferParticles {
                let pp = bp.ptr.assumingMemoryBound(to: GPUparticle.self)
                for i in 0..<particles.count {
                    let p = particles[i]
                    pp[i] = GPUparticle(
                        position: p.position.infloat3, size: Float32(p.size),
                        color: p.color.infloat4)
                }
                var m = "material.default"
                while let n = self[m] as? String {
                    m = n
                }
                if let material = self[m] as? MaterialOld {
                    material.render(to: g0, world: world, particles: bp, count: particles.count)
                }
            }
        }
        return true
    }
    struct Particle {
        var position: Vec3
        var size: Double
        var color: Color
    }
    struct GPUparticle {
        var position: SIMD3<Float>
        var size: Float32
        var color: SIMD4<Float>
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
