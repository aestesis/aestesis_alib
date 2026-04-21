//
//  node.3d.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 12/02/2024.
//

import Foundation
import simd

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class NodeRenderer: NodeUI, @unchecked Sendable {
    public var renderer: Renderer? {
        return (self.ancestor() as RendererProtocol?)?.renderer
    }
    public var db: NodeUI? {
        return (self.ancestor() as RendererProtocol?) as? NodeUI
    }
    public func persitentBuffer(_ size: Int) -> Buffer {
        return viewport!.gpu.buffers!.get(size, persistent: true)
    }
    public init(parent: NodeUI) {
        super.init(parent: parent)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
open class Node3D: NodeRenderer, @unchecked Sendable {
    public var matrix: Mat4
    public var position: Vec3 {
        get { return matrix.translation }
        set(v) { matrix.translation = v }
    }
    public private(set) var subnodes = [Node3D]()
    public var supernode: Node3D? {
        return self.parent as? Node3D
    }
    public var worldMatrix: Mat4 {
        var m = self.matrix
        var n: Node3D? = self
        while n != nil {
            m = n!.matrix * m
            n = n!.supernode
        }
        return m
    }
    public init(parent: NodeUI, matrix: Mat4 = Mat4.identity) {
        self.matrix = matrix
        super.init(parent: parent)
        if let supernode = self.supernode {
            supernode.subnodes.append(self)
        }
    }
    override open func detach() {
        for n in subnodes {
            n.detach()
        }
        if let supernode = self.supernode {
            supernode.subnodes = supernode.subnodes.filter({ (n) -> Bool in
                return n != self
            })
        }
        super.detach()
    }
    open func render(to g: Graphics, world: Mat4, opaque: Bool) -> Bool {
        return false
    }
    public func child<T: Node3D>(recursive: Bool = false) -> T? {
        for v0 in subnodes {
            if let v = v0 as? T {
                return v
            }
            if recursive, let s = v0.child(recursive: true) as T? {
                return s
            }
        }
        return nil
    }
    public func children<T: Node3D>(recursive: Bool = false) -> [T] {
        var s = [T]()
        for v0 in subnodes {
            if let v = v0 as? T {
                s.append(v)
            }
            if recursive {
                s += v0.children(recursive: true) as [T]
            }
        }
        return s
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
