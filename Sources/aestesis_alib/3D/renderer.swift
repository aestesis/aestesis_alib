//
//  Renderer.swift
//  Alib
//
//  Created by renan jegouzo on 17/05/2017.
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
import Metal
import MetalKit

// TODO: add mouse/touch support http://antongerdelan.net/opengl/raycasting.html
// TODO: normal mapping https://learnopengl.com/#!Advanced-Lighting/Normal-Mapping  http://fabiensanglard.net/bumpMapping/index.php

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Mirror : Node3D { } // implemented in renderer
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public protocol RendererProtocol {
    var renderer:Renderer? { get }
    var db:NodeUI { get }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Renderer : NodeUI {
    struct RenderInfo {
        var node:Node3D
        var g:Graphics
        var world:Mat4
    }
    public var db:NodeUI? {
        return self.parent as? NodeUI
    }
    public var world:Node3D?
    public var camera:Camera3D?
    public var lights:[Light] = []
    public var lightsProgram : String {
        if lights.count == 0 {
            return ""
        }
        if lights.count>1 {
            return "point.\(lights.count)."
        }
        if lights[0] is DirectionalLight {
            return "directional."
        }
        return "point.1."
    }
    func perspective(scale s:Double=1) -> Mat4 {
        return Mat4.scale(Vec3(x:s,y:s,z:0.002))*Mat4.perspective(view:Size.unity,angleOfView:ß.π2,near:0.1,far:1000)
    }
    public init(parent:NodeUI) {
        super.init(parent:parent)
        if let db = self.db {
            db["material.default"] = MaterialOld(parent:db,name:"default")
        }
    }
    override public func detach() {
        camera = nil
        world?.detach()
        world = nil
        super.detach()
    }
    public func render(to g:Graphics,size:Size) {
        if let world=self.world, let camera=self.camera {
            lights = world.children(recursive:true)
            if lights.count>1 {
                lights = lights.filter{$0 is PointLight}
            }
            let perspective = self.perspective(scale:size.length/1400)*Mat4.translation(Vec3(size.point(0.5,0.5)))
            let gview = Graphics(parent:g,matrix:camera.viewMatrix*perspective)
            let nodesTrans = self.render(to:gview,world:world.matrix,node:world,opaque:true)
            // TODO: z sort nodesTrans
            for n in nodesTrans {
                _ = n.node.render(to:n.g,world:n.world,opaque:false)
            }
        }
    }
    func render(to g:Graphics,world:Mat4,node:Node3D,opaque:Bool) -> [RenderInfo] {
        var infos=[RenderInfo]()
        if node.render(to:g,world:world,opaque:opaque) {
            infos.append(RenderInfo(node:node,g:g,world:world))
        }
        let mirrors = node.subnodes.filter { n -> Bool in
            return n is Mirror
        }
        if mirrors.count>0 {
            let nodes = node.subnodes.filter { n -> Bool in
                return !(n is Mirror)
            }
            for n in nodes {
                let gn = Graphics(parent:g,matrix:n.matrix)
                infos.append(contentsOf:self.render(to:gn,world:n.matrix*world,node:n,opaque:opaque))
            }
            for m in mirrors {
                let gm = Graphics(parent:g,matrix:m.matrix)
                let wm = m.matrix*world
                for n in nodes {
                    let gn = Graphics(parent:gm,matrix:n.matrix)
                    infos.append(contentsOf:self.render(to:gn,world:n.matrix*wm,node:n,opaque:opaque))
                }
            }
        } else {
            for n in node.subnodes {
                let gn = Graphics(parent:g,matrix:n.matrix)
                infos.append(contentsOf:self.render(to:gn,world:n.matrix*world,node:n,opaque:opaque))
            }
        }
        return infos
    }
    static func globals(_ viewport:Viewport) {
        viewport["3d.depth.all"] = DepthStencilState(viewport:viewport,mode:.all,write:true)
        viewport["3d.depth.lesser"] = DepthStencilState(viewport:viewport,mode:.lesser,write:true)
        viewport["3d.depth.greater"] = DepthStencilState(viewport:viewport,mode:.greater,write:true)
        viewport["3d.depth.all.nowrite"] = DepthStencilState(viewport:viewport,mode:.all,write:false)
        viewport["3d.depth.lesser.nowrite"] = DepthStencilState(viewport:viewport,mode:.lesser,write:false)
        viewport["3d.depth.greater.nowrite"] = DepthStencilState(viewport:viewport,mode:.greater,write:false)
        // Object rendering
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.basic",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.texture",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentTextureFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.directional.basic",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentDirectionalLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.directional.texture",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentTextureDirectionalLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.1.basic",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentPointLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.1.texture",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentTexturePointLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.2.basic",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentPoint2LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.2.texture",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentTexturePoint2LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.3.basic",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentPoint3LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.3.texture",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentTexturePoint3LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.4.basic",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentPoint4LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.4.texture",library:viewport.gpu.library!,vertex:"vertex3DFunc",fragment:"fragmentTexturePoint4LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        
        // ObjectCollection rendering (Instances)
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.basic",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.texture",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentTextureFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.directional.basic",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentDirectionalLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.directional.texture",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentTextureDirectionalLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.1.basic",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentPointLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.1.texture",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentTexturePointLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.2.basic",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentPoint2LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.2.texture",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentTexturePoint2LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.3.basic",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentPoint3LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.3.texture",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentTexturePoint3LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.4.basic",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentPoint4LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.instance.point.4.texture",library:viewport.gpu.library!,vertex:"vertex3DInstance",fragment:"fragmentTexturePoint4LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])

        // Height map rendering
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.height",library:viewport.gpu.library!,vertex:"vertex3DHeightFunc",fragment:"fragmentFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.directional.height",library:viewport.gpu.library!,vertex:"vertex3DHeightFunc",fragment:"fragmentDirectionalLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.1.height",library:viewport.gpu.library!,vertex:"vertex3DHeightFunc",fragment:"fragmentPointLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.2.height",library:viewport.gpu.library!,vertex:"vertex3DHeightFunc",fragment:"fragmentPoint2LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.3.height",library:viewport.gpu.library!,vertex:"vertex3DHeightFunc",fragment:"fragmentPoint3LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.4.height",library:viewport.gpu.library!,vertex:"vertex3DHeightFunc",fragment:"fragmentPoint4LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.height.texture",library:viewport.gpu.library!,vertex:"vertex3DHeightTextureFunc",fragment:"fragmentTextureFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.directional.height.texture",library:viewport.gpu.library!,vertex:"vertex3DHeightTextureFunc",fragment:"fragmentTextureDirectionalLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.1.height.texture",library:viewport.gpu.library!,vertex:"vertex3DHeightTextureFunc",fragment:"fragmentTexturePointLightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.2.height.texture",library:viewport.gpu.library!,vertex:"vertex3DHeightTextureFunc",fragment:"fragmentTexturePoint2LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.3.height.texture",library:viewport.gpu.library!,vertex:"vertex3DHeightTextureFunc",fragment:"fragmentTexturePoint3LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        Program.populateDefaultBlendModes(store:viewport,key:"program.3d.point.4.height.texture",library:viewport.gpu.library!,vertex:"vertex3DHeightTextureFunc",fragment:"fragmentTexturePoint4LightFunc",vertexFormat:[.float3,.float4,.float2,.float3])
        
        // particles rendering
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.basic",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.texture",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointTextureFunc",vertexFormat:[.float3,.float,.float4])
        // TODO: implement the illuminations
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.directional.basic",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.directional.texture",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointTextureFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.1.basic",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.1.texture",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointTextureFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.2.basic",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.2.texture",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointTextureFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.3.basic",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.3.texture",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointTextureFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.4.basic",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointFunc",vertexFormat:[.float3,.float,.float4])
        Program.populateDefaultBlendModes(store:viewport,key:"program.point.3d.point.4.texture",library:viewport.gpu.library!,vertex:"point3DFunc",fragment:"fragmentPointTextureFunc",vertexFormat:[.float3,.float,.float4])
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// http://www.codinglabs.net/article_world_view_projection_matrix.aspx
public class RendererView : View,RendererProtocol {
    public var db: NodeUI {
        return self
    }
    public var renderer:Renderer?
    public var camera: Camera3D? {
        get { return renderer?.camera }
        set { renderer?.camera = newValue }
    }
    public var world: Node3D? {
        get { return renderer?.world }
        set { renderer?.world = newValue }
    }
    public init(superview:View,layout:Layout) {
        super.init(superview:superview,layout:layout)
        renderer = Renderer(parent:self)
        self.clipping = true
    }
    override public func detach() {
        renderer?.detach()
        renderer = nil
        super.detach()
    }
    override public func draw(to g: Graphics) {
        renderer?.render(to:g,size:self.size)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class RendererBitmap : Bitmap,RendererProtocol {
    public var db : NodeUI {
        return self
    }
    public var camera: Camera3D? {
        get { return renderer?.camera }
        set { renderer?.camera = newValue }
    }
    public var world: Node3D? {
        get { return renderer?.world }
        set { renderer?.world = newValue }
    }
    public var renderer:Renderer?
    public init(parent:NodeUI,size:Size) {
        super.init(parent:parent,size:size)
        renderer = Renderer(parent:self)
    }
    override public func detach() {
        renderer?.detach()
        renderer = nil
        super.detach()
    }
    public func render(_ fn:@escaping (()->())) {
        let g=Graphics(image:self)
        renderer?.render(to:g,size:self.size)
        g.onDone { [weak self] ok in
            guard let self=self, self.attached else { return }
            switch ok {
            case .success:
                fn()
                break
            case .error(let message):
                Debug.error("RenderBitmap.render() error \(message)")
                break
            default:
                break
            }
        }
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
