//
//  Color.swift
//  Alib
//
//  Created by renan jegouzo on 25/02/2016.
//  Copyright © 2016 aestesis. All rights reserved.
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
import MetalKit
import simd

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO: shader hsl <-> rgb https://www.ronja-tutorials.com/post/041-hsv-colorspace/#full-hsv-to-rgb-conversion

public struct Color: CustomStringConvertible, JsonConvertible, Sendable {
    // http://www.easyrgb.com/en/math.php
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var value: SIMD4<Double> = SIMD4<Double>(repeating: 0)
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var rgb: SIMD3<Double> {
        get { return value.xyz }
        set(v) { value.xyz = v }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var r: Double {
        get { return value.x }
        set(v) { value.x = v }
    }
    public var g: Double {
        get { return value.y }
        set(v) { value.y = v }
    }
    public var b: Double {
        get { return value.z }
        set(v) { value.z = v }
    }
    public var a: Double {
        get { return value.w }
        set(v) { value.w = v }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var ai: UInt8 {
        get { return UInt8(a * 255) }
        set(ai) { a = Double(ai) / 255.0 }
    }
    public var ri: UInt8 {
        get { return UInt8(r * 255) }
        set(ri) { r = Double(ri) / 255.0 }
    }
    public var gi: UInt8 {
        get { return UInt8(g * 255) }
        set(gi) { g = Double(gi) / 255.0 }
    }
    public var bi: UInt8 {
        get { return UInt8(b * 255) }
        set(bi) { b = Double(bi) / 255.0 }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var rgba: UInt32 {
        let v0 = UInt32(ai) << 24
        let v1 = UInt32(bi) << 16
        let v2 = UInt32(gi) << 8
        let v3 = UInt32(ri)
        return v0 | v1 | v2 | v3
    }
    public var bgra: UInt32 {
        let v0 = UInt32(ai) << 24
        let v1 = UInt32(ri) << 16
        let v2 = UInt32(gi) << 8
        let v3 = UInt32(bi)
        return v0 | v1 | v2 | v3
    }
    public var abgr: UInt32 {
        let v0 = UInt32(ri) << 24
        let v1 = UInt32(gi) << 16
        let v2 = UInt32(bi) << 8
        let v3 = UInt32(ai)
        return v0 | v1 | v2 | v3
    }
    public var argb: UInt32 {
        let v0 = UInt32(bi) << 24
        let v1 = UInt32(gi) << 16
        let v2 = UInt32(ri) << 8
        let v3 = UInt32(ai)
        return v0 | v1 | v2 | v3
    }
    public var hsba: HSBA {
        let vmax = max(max(self.r, self.g), self.b)
        let vmin = min(min(self.r, self.g), self.b)
        var h = 0.0
        let s = (vmax == 0) ? 0.0 : (vmax - vmin) / vmax
        let b = vmax
        if s != 0 {
            let rc = (vmax - self.r) / (vmax - vmin)
            let gc = (vmax - self.g) / (vmax - vmin)
            let bc = (vmax - self.b) / (vmax - vmin)
            if r == vmax {
                h = bc - gc
            } else if g == vmax {
                h = 2.0 + rc - bc
            } else {
                h = 4.0 + gc - rc
            }
            h /= 6.0
            if h < 0 {
                h += 1.0
            }
        }
        return HSBA(a: a, h: h, s: s, b: b)
    }
    public var hsla: HSLA {
        let vmax = max(max(self.r, self.g), self.b)
        let vmin = min(min(self.r, self.g), self.b)
        let d = vmax - vmin
        var h = 0.0
        var s = 0.0
        let l = (vmax + vmin) * 0.5
        if d != 0 {
            if l < 0.5 {
                s = d / (vmax + vmin)
            } else {
                s = d / (2 - vmax - vmin)
            }
            if self.r == vmax {
                h = (self.g - self.b) / d
            } else if self.g == vmax {
                h = 2 + (self.b - self.r) / d
            } else {
                h = 4 + (self.r - self.g) / d
            }
            h /= 6.0
            if h < 0 {
                h += 1.0
            }
        }
        return HSLA(a: self.a, h: h, s: s, l: l)
    }

    public var description: String {
        return html
    }
    public var infloat4: SIMD4<Float> {
        //return  IMD4<Float>(Float(r),Float(g),Float(b),Float(a))
        return SIMD4<Float>(value)
    }
    public var json: JSON {
        return JSON(html)
    }
    public func lerp(to c: Color, coef m: Double) -> Color {
        return self + (c - self) * m
        //let im=1-m
        //return Color(a:im*a+m*c.a, r:im*r+m*c.r, g: im*g+m*c.g, b: im*b+m*c.b)
    }
    public func lerp(to c: Color, coef s: Signal) -> Color {
        return lerp(to: c, coef: s.value)
    }
    public var luminosity: Double {
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    public var html: String {
        return "#" + String(format: "%02X", Int(a * 255)) + String(format: "%02X", Int(r * 255))
            + String(format: "%02X", Int(g * 255)) + String(format: "%02X", Int(b * 255))
    }
    public var uint: UInt32 {
        return argb
    }
    public var saturated: Color {
        return Color(
            a: min(1, max(0, a)), r: min(1, max(0, r)), g: min(1, max(0, g)), b: min(1, max(0, b)))
    }
    public func adjusted(chroma: Double, luminosity: Double) -> Color {
        let lum = Vec3(x: luminosity, y: luminosity, z: luminosity)
        let w = Vec3(x: 0.2989, y: 0.5870, z: 0.1140)
        let c = Vec3(x: self.r, y: self.g, z: self.b)
        let l = dot(c, w)
        let vl = Vec3(x: l, y: l, z: l)
        let d = c - vl
        var nc = (vl + (d * chroma)).clamp(min: Vec3.zero, max: Vec3.unity)
        nc = (nc + lum).clamp(min: Vec3.zero, max: Vec3.unity)
        return Color(a: a, r: nc.x, g: nc.y, b: nc.z)
    }
    public func adjusted(contrast: Double, brightness: Double) -> Color {
        let b = Vec3(x: brightness, y: brightness, z: brightness)
        let c = Vec3(x: self.r, y: self.g, z: self.b)
        let m = Vec3(x: 0.5, y: 0.5, z: 0.5)
        var nc = (m + (c - m) * contrast).clamp(min: Vec3.zero, max: Vec3.unity)
        nc = (nc + b).clamp(min: Vec3.zero, max: Vec3.unity)
        return Color(a: a, r: nc.x, g: nc.y, b: nc.z)
    }
    public func with(a: Double? = nil, r: Double? = nil, g: Double? = nil, b: Double? = nil)
        -> Color
    {
        return Color(a: a ?? self.a, r: r ?? self.r, g: g ?? self.g, b: b ?? self.b)
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func set(a: Double? = nil, r: Double? = nil, g: Double? = nil, b: Double? = nil) -> Color
    {
        return Color(a: a ?? self.a, r: r ?? self.r, g: g ?? self.g, b: b ?? self.b)
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public init(_ value: SIMD4<Double>) {
        self.value = value
    }
    public init(_ value: SIMD4<Float>) {
        self.value = SIMD4<Double>(value)
    }
    public init(a: Double = 1, rgb: SIMD3<Double>) {
        value.xyz = rgb
        value.w = a
    }
    public init(bgra: UInt32) {
        self.a = Double((Int(bgra) >> 24) & 255) / 255.0
        self.r = Double((Int(bgra) >> 16) & 255) / 255.0
        self.g = Double((Int(bgra) >> 8) & 255) / 255.0
        self.b = Double(Int(bgra) & 255) / 255.0
    }
    public init(abgr: UInt32) {
        self.r = Double((Int(abgr) >> 24) & 255) / 255.0
        self.g = Double((Int(abgr) >> 16) & 255) / 255.0
        self.b = Double((Int(abgr) >> 8) & 255) / 255.0
        self.a = Double(Int(abgr) & 255) / 255.0
    }
    public init(rgba: UInt32) {
        self.a = Double((Int(rgba) >> 24) & 255) / 255.0
        self.b = Double((Int(rgba) >> 16) & 255) / 255.0
        self.g = Double((Int(rgba) >> 8) & 255) / 255.0
        self.r = Double(Int(rgba) & 255) / 255.0
    }
    public init(argb: UInt32) {
        self.b = Double((Int(argb) >> 24) & 255) / 255.0
        self.g = Double((Int(argb) >> 16) & 255) / 255.0
        self.r = Double((Int(argb) >> 8) & 255) / 255.0
        self.a = Double(Int(argb) & 255) / 255.0
    }
    public init(a: Double = 1, r: Double, g: Double, b: Double) {
        self.a = a
        self.r = r
        self.g = g
        self.b = b
    }
    public init(a: Double = 1, l: Double) {
        self.value = SIMD4(l, l, l, a)
    }
    public init(a: Double = 1, rgb: Color) {
        self.a = a
        self.r = rgb.r
        self.g = rgb.g
        self.b = rgb.b
    }
    public init(hsba: HSBA) {
        self.init(a: hsba.a, h: hsba.h, s: hsba.s, b: hsba.b)
    }
    #if os(iOS) || os(tvOS)
        public init(a: Double = 1, h: Double, s: Double, b: Double) {
            self.a = min(max(a, 0), 1)
            let ui = UIColor(
                hue: CGFloat(h), saturation: CGFloat(s), brightness: CGFloat(b), alpha: CGFloat(ta))
            var cr = CGFloat()
            var cg = CGFloat()
            var cb = CGFloat()
            var ca = CGFloat()
            ui.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            self.r = Double(cr)
            self.g = Double(cg)
            self.b = Double(cb)
        }
    #elseif os(OSX)
        public init(a: Double = 1, h: Double, s: Double, b: Double) {
            self.a = min(max(a, 0), 1)
            let ns = NSColor(
                hue: CGFloat(h), saturation: CGFloat(s), brightness: CGFloat(b), alpha: CGFloat(a))
            self.r = Double(ns.redComponent)
            self.g = Double(ns.greenComponent)
            self.b = Double(ns.blueComponent)
        }
    #else
        public init(ta: Double = 1, h: Double, s: Double, b: Double) {
            self.ta = min(max(ta, 0), 1)
            if s == 0 {
                self.r = b
                self.g = b
                self.b = b
            } else {
                let sectorPos = h * 360 / 60.0
                let sectorNumber = Int(floor(sectorPos))
                let fractionalSector = sectorPos - Double(sectorNumber)
                let p = b * (1.0 - s)
                let q = b * (1.0 - (s * fractionalSector))
                let t = b * (1.0 - (s * (1 - fractionalSector)))
                switch sectorNumber
                {
                case 1:
                    self.r = q
                    self.g = b
                    self.b = p
                case 2:
                    self.r = p
                    self.g = b
                    self.b = t
                case 3:
                    self.r = p
                    self.g = q
                    self.b = b
                case 4:
                    self.r = t
                    self.g = p
                    self.b = b
                case 5:
                    self.r = b
                    self.g = p
                    self.b = q
                default:  // 0
                    self.r = b
                    self.g = t
                    self.b = p
                }
            }
        }
    #endif
    public init(hsla: HSLA) {
        self.init(a: hsla.a, h: hsla.h, s: hsla.s, l: hsla.l)
    }
    public init(a: Double = 1, h: Double, s: Double, l: Double) {
        // https://stackoverflow.com/questions/4793729/rgb-to-hsl-and-back-calculation-problems
        self.a = min(max(a, 0), 1)
        if s == 0 {
            self.r = l
            self.g = l
            self.b = l
        } else {
            var t2 = 0.0
            if l < 0.5 {
                t2 = l * (1 + s)
            } else {
                t2 = (l + s) - (l * s)
            }
            let t1 = 2 * l - t2

            let r = h + (1 / 3)
            let g = h
            let b = h - (1 / 3)

            func calc(_ c0: Double) -> Double {
                let c = ß.modulo(c0, 1)
                if 6 * c < 1 {
                    return t1 + (t2 - t1) * 6 * c
                } else if 2 * c < 1 {
                    return t2
                } else if 3 * c < 2 {
                    return t1 + (t2 - t1) * (2 / 3 - c) * 6
                }
                return t1
            }

            self.r = calc(r)
            self.g = calc(g)
            self.b = calc(b)
        }
    }
    public init(html: String) {
        var h: String = html
        if h[0] == "#" {
            h = h[1...]
        }
        if h.length == 8 {
            let ta = h[0...1]
            h = h[2...]
            a = Double(UInt8(strtoul(ta, nil, 16))) / 255.0
        } else {
            a = 1
        }
        if h.length == 6 {
            r = Double(UInt8(strtoul(h[0...1], nil, 16))) / 255.0
            g = Double(UInt8(strtoul(h[2...3], nil, 16))) / 255.0
            b = Double(UInt8(strtoul(h[4...5], nil, 16))) / 255.0
        } else {
            r = 0
            g = 0
            b = 0
        }
    }
    public init(hex: String) {
        self.init(html: hex)
    }
    public init(json: JSON) {
        if let s = json.string {
            self.init(html: s)
        } else {
            self.init(a: 1, l: 0)
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    #if os(iOS) || os(tvOS)
        public var system: UIColor {
            return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        }
        public init(_ c: UIColor) {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var ta: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &ta)
            self.r = Double(r)
            self.g = Double(g)
            self.b = Double(b)
            self.ta = Double(ta)
        }
    #elseif os(OSX)
        public var system: NSColor {
            return NSColor(
                deviceRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        }
    #endif
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public static var transparent: Color {
        return Color(html: "#00000000")
    }
    public static var black: Color {
        return Color(html: "#000000")
    }
    public static var darkGrey: Color {
        return Color(html: "#404040")
    }
    public static var grey: Color {
        return Color(html: "#808080")
    }
    public static var lightGrey: Color {
        return Color(html: "#C0C0C0")
    }
    public static var white: Color {
        return Color(html: "#FFFFFF")
    }
    public static var red: Color {
        return Color(html: "#FF0000")
    }
    public static var green: Color {
        return Color(html: "#00FF00")
    }
    public static var blue: Color {
        return Color(html: "#0000FF")
    }
    public static var aeOrange: Color {
        return Color(html: "#FFAA00")
    }
    public static var aeMagenta: Color {
        return Color(html: "#FF00AA")
    }
    public static var aeGreen: Color {
        return Color(html: "#AAFF00")
    }
    public static var aeAqua: Color {
        return Color(html: "#00FFAA")
    }
    public static var aeViolet: Color {
        return Color(html: "#AA00FF")
    }
    public static var aeBlue: Color {
        return Color(html: "#00AAFF")
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////////

    // TODO: load of json file https://gist.github.com/renanyoy/4acff1a8ba8de7f6f779   css??

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public func == (l: Color, r: Color) -> Bool {
    return l.value == r.value
}
public func != (l: Color, r: Color) -> Bool {
    return l.value != r.value
}
public func + (l: Color, r: Color) -> Color {
    return Color(l.value + r.value)
}
public func - (l: Color, r: Color) -> Color {
    return Color(l.value - r.value)
}
public func * (l: Color, r: Color) -> Color {
    return Color(l.value * r.value)
}
public func * (l: Color, r: Double) -> Color {
    return Color(l.value * r)
}
public func / (l: Color, r: Double) -> Color {
    return Color(l.value / r)
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public struct HSLA: CustomStringConvertible {
    public var description: String {
        return "HSLA(a:\(a),h:\(h),s:\(s),l:\(l))"
    }
    public var value: SIMD4<Double> = SIMD4<Double>(repeating: 0)
    public var hue: Double {
        get { return value.x }
        set { value.x = newValue }
    }
    public var saturation: Double {
        get { return value.y }
        set { value.y = newValue }
    }
    public var lightness: Double {
        get { return value.z }
        set { value.z = newValue }
    }
    public var alpha: Double {
        get { return value.w }
        set { value.w = newValue }
    }
    public var h: Double {
        get { return value.x }
        set { value.x = newValue }
    }
    public var s: Double {
        get { return value.y }
        set { value.y = newValue }
    }
    public var l: Double {
        get { return value.z }
        set { value.z = newValue }
    }
    public var a: Double {
        get { return value.w }
        set { value.w = newValue }
    }
    public init(_ hsla: SIMD4<Double>) {
        value = hsla
    }
    public init(hsla: SIMD4<Double>) {
        value = hsla
    }
    public init(
        alpha a: Double = 1, hue h: Double, saturation s: Double = 1, lightness l: Double = 1
    ) {
        self.h = h
        self.s = s
        self.l = l
        self.a = a
    }
    public init(a: Double = 1, h: Double, s: Double = 1, l: Double = 1) {
        self.h = h
        self.s = s
        self.l = l
        self.a = a
    }
    public var saturated: HSLA {
        let hs = h.truncatingRemainder(dividingBy: 1)
        return HSLA(
            a: min(1, max(0, a)), h: hs < 0 ? hs + 1 : hs, s: min(1, max(0, s)),
            l: min(1, max(0, l)))
    }
    public static func == (l: HSLA, r: HSLA) -> Bool {
        return l.value == r.value
    }
    public static func != (l: HSLA, r: HSLA) -> Bool {
        return l.value != r.value
    }
    public static func + (l: HSLA, r: HSLA) -> HSLA {
        return HSLA(l.value + r.value)
    }
    public static func - (l: HSLA, r: HSLA) -> HSLA {
        return HSLA(l.value - r.value)
    }
    public static func * (l: HSLA, r: HSLA) -> HSLA {
        return HSLA(l.value * r.value)
    }
    public static func * (l: HSLA, r: Double) -> HSLA {
        return HSLA(l.value * r)
    }
    public static func / (l: HSLA, r: Double) -> HSLA {
        return HSLA(l.value / r)
    }
}
public struct HSBA: CustomStringConvertible {
    public var description: String {
        return "HSBA(a:\(a),h:\(h),s:\(s),b:\(b))"
    }
    public var value: SIMD4<Double> = SIMD4<Double>(repeating: 0)
    public var hsb: SIMD3<Double> {
        get { return value.xyz }
        set(v) { value.xyz = v }
    }
    public var hue: Double {
        get { return value.x }
        set { value.x = newValue }
    }
    public var saturation: Double {
        get { return value.y }
        set { value.y = newValue }
    }
    public var brightness: Double {
        get { return value.z }
        set { value.z = newValue }
    }
    public var alpha: Double {
        get { return value.w }
        set { value.w = newValue }
    }
    public var h: Double {
        get { return value.x }
        set { value.x = newValue }
    }
    public var s: Double {
        get { return value.y }
        set { value.y = newValue }
    }
    public var b: Double {
        get { return value.z }
        set { value.z = newValue }
    }
    public var a: Double {
        get { return value.w }
        set { value.w = newValue }
    }
    init(_ hsba: SIMD4<Double>) {
        value = hsba
    }
    public init(hsba: SIMD4<Double>) {
        value = hsba
    }
    public init(
        alpha a: Double = 1, hue h: Double, saturation s: Double = 1, brightness b: Double = 1
    ) {
        self.h = h
        self.s = s
        self.b = b
        self.a = a
    }
    public init(a: Double = 1, h: Double, s: Double = 1, b: Double = 1) {
        self.h = h
        self.s = s
        self.b = b
        self.a = a
    }
    public var saturated: HSBA {
        let hs = h.truncatingRemainder(dividingBy: 1)
        return HSBA(
            a: min(1, max(0, a)), h: hs < 0 ? hs + 1 : hs, s: min(1, max(0, s)),
            b: min(1, max(0, b)))
    }
    public static func == (l: HSBA, r: HSBA) -> Bool {
        return l.value == r.value
    }
    public static func != (l: HSBA, r: HSBA) -> Bool {
        return l.value != r.value
    }
    public static func + (l: HSBA, r: HSBA) -> HSBA {
        return HSBA(l.value + r.value)
    }
    public static func - (l: HSBA, r: HSBA) -> HSBA {
        return HSBA(l.value - r.value)
    }
    public static func * (l: HSBA, r: HSBA) -> HSBA {
        return HSBA(l.value * r.value)
    }
    public static func * (l: HSBA, r: Double) -> HSBA {
        return HSBA(l.value * r)
    }
    public static func / (l: HSBA, r: Double) -> HSBA {
        return HSBA(l.value / r)
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension Color {
    // Google Material design colors palette.
    // https://material.google.com/style/color.html
    public struct Material {
        public static let red = red500
        public static let red50 = Color(bgra: 0xFFFF_EBEE)
        public static let red100 = Color(bgra: 0xFFFF_CDD2)
        public static let red200 = Color(bgra: 0xFFEF_9A9A)
        public static let red300 = Color(bgra: 0xFFE5_7373)
        public static let red400 = Color(bgra: 0xFFEF_5350)
        public static let red500 = Color(bgra: 0xFFF4_4336)
        public static let red600 = Color(bgra: 0xFFE5_3935)
        public static let red700 = Color(bgra: 0xFFD3_2F2F)
        public static let red800 = Color(bgra: 0xFFC6_2828)
        public static let red900 = Color(bgra: 0xFFB7_1C1C)
        public static let redA100 = Color(bgra: 0xFFFF_8A80)
        public static let redA200 = Color(bgra: 0xFFFF_5252)
        public static let redA400 = Color(bgra: 0xFFFF_1744)
        public static let redA700 = Color(bgra: 0xFFD5_0000)
        public static let pink = pink500
        public static let pink50 = Color(bgra: 0xFFFC_E4EC)
        public static let pink100 = Color(bgra: 0xFFF8_BBD0)
        public static let pink200 = Color(bgra: 0xFFF4_8FB1)
        public static let pink300 = Color(bgra: 0xFFF0_6292)
        public static let pink400 = Color(bgra: 0xFFEC_407A)
        public static let pink500 = Color(bgra: 0xFFE9_1E63)
        public static let pink600 = Color(bgra: 0xFFD8_1B60)
        public static let pink700 = Color(bgra: 0xFFC2_185B)
        public static let pink800 = Color(bgra: 0xFFAD_1457)
        public static let pink900 = Color(bgra: 0xFF88_0E4F)
        public static let pinkA100 = Color(bgra: 0xFFFF_80AB)
        public static let pinkA200 = Color(bgra: 0xFFFF_4081)
        public static let pinkA400 = Color(bgra: 0xFFF5_0057)
        public static let pinkA700 = Color(bgra: 0xFFC5_1162)
        public static let purple = purple500
        public static let purple50 = Color(bgra: 0xFFF3_E5F5)
        public static let purple100 = Color(bgra: 0xFFE1_BEE7)
        public static let purple200 = Color(bgra: 0xFFCE_93D8)
        public static let purple300 = Color(bgra: 0xFFBA_68C8)
        public static let purple400 = Color(bgra: 0xFFAB_47BC)
        public static let purple500 = Color(bgra: 0xFF9C_27B0)
        public static let purple600 = Color(bgra: 0xFF8E_24AA)
        public static let purple700 = Color(bgra: 0xFF7B_1FA2)
        public static let purple800 = Color(bgra: 0xFF6A_1B9A)
        public static let purple900 = Color(bgra: 0xFF4A_148C)
        public static let purpleA100 = Color(bgra: 0xFFEA_80FC)
        public static let purpleA200 = Color(bgra: 0xFFE0_40FB)
        public static let purpleA400 = Color(bgra: 0xFFD5_00F9)
        public static let purpleA700 = Color(bgra: 0xFFAA_00FF)
        public static let deepPurple = deepPurple500
        public static let deepPurple50 = Color(bgra: 0xFFED_E7F6)
        public static let deepPurple100 = Color(bgra: 0xFFD1_C4E9)
        public static let deepPurple200 = Color(bgra: 0xFFB3_9DDB)
        public static let deepPurple300 = Color(bgra: 0xFF95_75CD)
        public static let deepPurple400 = Color(bgra: 0xFF7E_57C2)
        public static let deepPurple500 = Color(bgra: 0xFF67_3AB7)
        public static let deepPurple600 = Color(bgra: 0xFF5E_35B1)
        public static let deepPurple700 = Color(bgra: 0xFF51_2DA8)
        public static let deepPurple800 = Color(bgra: 0xFF45_27A0)
        public static let deepPurple900 = Color(bgra: 0xFF31_1B92)
        public static let deepPurpleA100 = Color(bgra: 0xFFB3_88FF)
        public static let deepPurpleA200 = Color(bgra: 0xFF7C_4DFF)
        public static let deepPurpleA400 = Color(bgra: 0xFF65_1FFF)
        public static let deepPurpleA700 = Color(bgra: 0xFF62_00EA)
        public static let indigo = indigo500
        public static let indigo50 = Color(bgra: 0xFFE8_EAF6)
        public static let indigo100 = Color(bgra: 0xFFC5_CAE9)
        public static let indigo200 = Color(bgra: 0xFF9F_A8DA)
        public static let indigo300 = Color(bgra: 0xFF79_86CB)
        public static let indigo400 = Color(bgra: 0xFF5C_6BC0)
        public static let indigo500 = Color(bgra: 0xFF3F_51B5)
        public static let indigo600 = Color(bgra: 0xFF39_49AB)
        public static let indigo700 = Color(bgra: 0xFF30_3F9F)
        public static let indigo800 = Color(bgra: 0xFF28_3593)
        public static let indigo900 = Color(bgra: 0xFF1A_237E)
        public static let indigoA100 = Color(bgra: 0xFF8C_9EFF)
        public static let indigoA200 = Color(bgra: 0xFF53_6DFE)
        public static let indigoA400 = Color(bgra: 0xFF3D_5AFE)
        public static let indigoA700 = Color(bgra: 0xFF30_4FFE)
        public static let blue = blue500
        public static let blue50 = Color(bgra: 0xFFE3_F2FD)
        public static let blue100 = Color(bgra: 0xFFBB_DEFB)
        public static let blue200 = Color(bgra: 0xFF90_CAF9)
        public static let blue300 = Color(bgra: 0xFF64_B5F6)
        public static let blue400 = Color(bgra: 0xFF42_A5F5)
        public static let blue500 = Color(bgra: 0xFF21_96F3)
        public static let blue600 = Color(bgra: 0xFF1E_88E5)
        public static let blue700 = Color(bgra: 0xFF19_76D2)
        public static let blue800 = Color(bgra: 0xFF15_65C0)
        public static let blue900 = Color(bgra: 0xFF0D_47A1)
        public static let blueA100 = Color(bgra: 0xFF82_B1FF)
        public static let blueA200 = Color(bgra: 0xFF44_8AFF)
        public static let blueA400 = Color(bgra: 0xFF29_79FF)
        public static let blueA700 = Color(bgra: 0xFF29_62FF)
        public static let lightBlue = lightBlue500
        public static let lightBlue50 = Color(bgra: 0xFFE1_F5FE)
        public static let lightBlue100 = Color(bgra: 0xFFB3_E5FC)
        public static let lightBlue200 = Color(bgra: 0xFF81_D4FA)
        public static let lightBlue300 = Color(bgra: 0xFF4F_C3F7)
        public static let lightBlue400 = Color(bgra: 0xFF29_B6F6)
        public static let lightBlue500 = Color(bgra: 0xFF03_A9F4)
        public static let lightBlue600 = Color(bgra: 0xFF03_9BE5)
        public static let lightBlue700 = Color(bgra: 0xFF02_88D1)
        public static let lightBlue800 = Color(bgra: 0xFF02_77BD)
        public static let lightBlue900 = Color(bgra: 0xFF01_579B)
        public static let lightBlueA100 = Color(bgra: 0xFF80_D8FF)
        public static let lightBlueA200 = Color(bgra: 0xFF40_C4FF)
        public static let lightBlueA400 = Color(bgra: 0xFF00_B0FF)
        public static let lightBlueA700 = Color(bgra: 0xFF00_91EA)
        public static let cyan = cyan500
        public static let cyan50 = Color(bgra: 0xFFE0_F7FA)
        public static let cyan100 = Color(bgra: 0xFFB2_EBF2)
        public static let cyan200 = Color(bgra: 0xFF80_DEEA)
        public static let cyan300 = Color(bgra: 0xFF4D_D0E1)
        public static let cyan400 = Color(bgra: 0xFF26_C6DA)
        public static let cyan500 = Color(bgra: 0xFF00_BCD4)
        public static let cyan600 = Color(bgra: 0xFF00_ACC1)
        public static let cyan700 = Color(bgra: 0xFF00_97A7)
        public static let cyan800 = Color(bgra: 0xFF00_838F)
        public static let cyan900 = Color(bgra: 0xFF00_6064)
        public static let cyanA100 = Color(bgra: 0xFF84_FFFF)
        public static let cyanA200 = Color(bgra: 0xFF18_FFFF)
        public static let cyanA400 = Color(bgra: 0xFF00_E5FF)
        public static let cyanA700 = Color(bgra: 0xFF00_B8D4)
        public static let teal = teal500
        public static let teal50 = Color(bgra: 0xFFE0_F2F1)
        public static let teal100 = Color(bgra: 0xFFB2_DFDB)
        public static let teal200 = Color(bgra: 0xFF80_CBC4)
        public static let teal300 = Color(bgra: 0xFF4D_B6AC)
        public static let teal400 = Color(bgra: 0xFF26_A69A)
        public static let teal500 = Color(bgra: 0xFF00_9688)
        public static let teal600 = Color(bgra: 0xFF00_897B)
        public static let teal700 = Color(bgra: 0xFF00_796B)
        public static let teal800 = Color(bgra: 0xFF00_695C)
        public static let teal900 = Color(bgra: 0xFF00_4D40)
        public static let tealA100 = Color(bgra: 0xFFA7_FFEB)
        public static let tealA200 = Color(bgra: 0xFF64_FFDA)
        public static let tealA400 = Color(bgra: 0xFF1D_E9B6)
        public static let tealA700 = Color(bgra: 0xFF00_BFA5)
        public static let green = green500
        public static let green50 = Color(bgra: 0xFFE8_F5E9)
        public static let green100 = Color(bgra: 0xFFC8_E6C9)
        public static let green200 = Color(bgra: 0xFFA5_D6A7)
        public static let green300 = Color(bgra: 0xFF81_C784)
        public static let green400 = Color(bgra: 0xFF66_BB6A)
        public static let green500 = Color(bgra: 0xFF4C_AF50)
        public static let green600 = Color(bgra: 0xFF43_A047)
        public static let green700 = Color(bgra: 0xFF38_8E3C)
        public static let green800 = Color(bgra: 0xFF2E_7D32)
        public static let green900 = Color(bgra: 0xFF1B_5E20)
        public static let greenA100 = Color(bgra: 0xFFB9_F6CA)
        public static let greenA200 = Color(bgra: 0xFF69_F0AE)
        public static let greenA400 = Color(bgra: 0xFF00_E676)
        public static let greenA700 = Color(bgra: 0xFF00_C853)
        public static let lightGreen = lightGreen500
        public static let lightGreen50 = Color(bgra: 0xFFF1_F8E9)
        public static let lightGreen100 = Color(bgra: 0xFFDC_EDC8)
        public static let lightGreen200 = Color(bgra: 0xFFC5_E1A5)
        public static let lightGreen300 = Color(bgra: 0xFFAE_D581)
        public static let lightGreen400 = Color(bgra: 0xFF9C_CC65)
        public static let lightGreen500 = Color(bgra: 0xFF8B_C34A)
        public static let lightGreen600 = Color(bgra: 0xFF7C_B342)
        public static let lightGreen700 = Color(bgra: 0xFF68_9F38)
        public static let lightGreen800 = Color(bgra: 0xFF55_8B2F)
        public static let lightGreen900 = Color(bgra: 0xFF33_691E)
        public static let lightGreenA100 = Color(bgra: 0xFFCC_FF90)
        public static let lightGreenA200 = Color(bgra: 0xFFB2_FF59)
        public static let lightGreenA400 = Color(bgra: 0xFF76_FF03)
        public static let lightGreenA700 = Color(bgra: 0xFF64_DD17)
        public static let lime = lime500
        public static let lime50 = Color(bgra: 0xFFF9_FBE7)
        public static let lime100 = Color(bgra: 0xFFF0_F4C3)
        public static let lime200 = Color(bgra: 0xFFE6_EE9C)
        public static let lime300 = Color(bgra: 0xFFDC_E775)
        public static let lime400 = Color(bgra: 0xFFD4_E157)
        public static let lime500 = Color(bgra: 0xFFCD_DC39)
        public static let lime600 = Color(bgra: 0xFFC0_CA33)
        public static let lime700 = Color(bgra: 0xFFAF_B42B)
        public static let lime800 = Color(bgra: 0xFF9E_9D24)
        public static let lime900 = Color(bgra: 0xFF82_7717)
        public static let limeA100 = Color(bgra: 0xFFF4_FF81)
        public static let limeA200 = Color(bgra: 0xFFEE_FF41)
        public static let limeA400 = Color(bgra: 0xFFC6_FF00)
        public static let limeA700 = Color(bgra: 0xFFAE_EA00)
        public static let yellow = yellow500
        public static let yellow50 = Color(bgra: 0xFFFF_FDE7)
        public static let yellow100 = Color(bgra: 0xFFFF_F9C4)
        public static let yellow200 = Color(bgra: 0xFFFF_F59D)
        public static let yellow300 = Color(bgra: 0xFFFF_F176)
        public static let yellow400 = Color(bgra: 0xFFFF_EE58)
        public static let yellow500 = Color(bgra: 0xFFFF_EB3B)
        public static let yellow600 = Color(bgra: 0xFFFD_D835)
        public static let yellow700 = Color(bgra: 0xFFFB_C02D)
        public static let yellow800 = Color(bgra: 0xFFF9_A825)
        public static let yellow900 = Color(bgra: 0xFFF5_7F17)
        public static let yellowA100 = Color(bgra: 0xFFFF_FF8D)
        public static let yellowA200 = Color(bgra: 0xFFFF_FF00)
        public static let yellowA400 = Color(bgra: 0xFFFF_EA00)
        public static let yellowA700 = Color(bgra: 0xFFFF_D600)
        public static let amber = amber500
        public static let amber50 = Color(bgra: 0xFFFF_F8E1)
        public static let amber100 = Color(bgra: 0xFFFF_ECB3)
        public static let amber200 = Color(bgra: 0xFFFF_E082)
        public static let amber300 = Color(bgra: 0xFFFF_D54F)
        public static let amber400 = Color(bgra: 0xFFFF_CA28)
        public static let amber500 = Color(bgra: 0xFFFF_C107)
        public static let amber600 = Color(bgra: 0xFFFF_B300)
        public static let amber700 = Color(bgra: 0xFFFF_A000)
        public static let amber800 = Color(bgra: 0xFFFF_8F00)
        public static let amber900 = Color(bgra: 0xFFFF_6F00)
        public static let amberA100 = Color(bgra: 0xFFFF_E57F)
        public static let amberA200 = Color(bgra: 0xFFFF_D740)
        public static let amberA400 = Color(bgra: 0xFFFF_C400)
        public static let amberA700 = Color(bgra: 0xFFFF_AB00)
        public static let orange = orange500
        public static let orange50 = Color(bgra: 0xFFFF_F3E0)
        public static let orange100 = Color(bgra: 0xFFFF_E0B2)
        public static let orange200 = Color(bgra: 0xFFFF_CC80)
        public static let orange300 = Color(bgra: 0xFFFF_B74D)
        public static let orange400 = Color(bgra: 0xFFFF_A726)
        public static let orange500 = Color(bgra: 0xFFFF_9800)
        public static let orange600 = Color(bgra: 0xFFFB_8C00)
        public static let orange700 = Color(bgra: 0xFFF5_7C00)
        public static let orange800 = Color(bgra: 0xFFEF_6C00)
        public static let orange900 = Color(bgra: 0xFFE6_5100)
        public static let orangeA100 = Color(bgra: 0xFFFF_D180)
        public static let orangeA200 = Color(bgra: 0xFFFF_AB40)
        public static let orangeA400 = Color(bgra: 0xFFFF_9100)
        public static let orangeA700 = Color(bgra: 0xFFFF_6D00)
        public static let deepOrange = deepOrange500
        public static let deepOrange50 = Color(bgra: 0xFFFB_E9E7)
        public static let deepOrange100 = Color(bgra: 0xFFFF_CCBC)
        public static let deepOrange200 = Color(bgra: 0xFFFF_AB91)
        public static let deepOrange300 = Color(bgra: 0xFFFF_8A65)
        public static let deepOrange400 = Color(bgra: 0xFFFF_7043)
        public static let deepOrange500 = Color(bgra: 0xFFFF_5722)
        public static let deepOrange600 = Color(bgra: 0xFFF4_511E)
        public static let deepOrange700 = Color(bgra: 0xFFE6_4A19)
        public static let deepOrange800 = Color(bgra: 0xFFD8_4315)
        public static let deepOrange900 = Color(bgra: 0xFFBF_360C)
        public static let deepOrangeA100 = Color(bgra: 0xFFFF_9E80)
        public static let deepOrangeA200 = Color(bgra: 0xFFFF_6E40)
        public static let deepOrangeA400 = Color(bgra: 0xFFFF_3D00)
        public static let deepOrangeA700 = Color(bgra: 0xFFDD_2C00)
        public static let brown = brown500
        public static let brown50 = Color(bgra: 0xFFEF_EBE9)
        public static let brown100 = Color(bgra: 0xFFD7_CCC8)
        public static let brown200 = Color(bgra: 0xFFBC_AAA4)
        public static let brown300 = Color(bgra: 0xFFA1_887F)
        public static let brown400 = Color(bgra: 0xFF8D_6E63)
        public static let brown500 = Color(bgra: 0xFF79_5548)
        public static let brown600 = Color(bgra: 0xFF6D_4C41)
        public static let brown700 = Color(bgra: 0xFF5D_4037)
        public static let brown800 = Color(bgra: 0xFF4E_342E)
        public static let brown900 = Color(bgra: 0xFF3E_2723)
        public static let grey = grey500
        public static let grey50 = Color(bgra: 0xFFFA_FAFA)
        public static let grey100 = Color(bgra: 0xFFF5_F5F5)
        public static let grey200 = Color(bgra: 0xFFEE_EEEE)
        public static let grey300 = Color(bgra: 0xFFE0_E0E0)
        public static let grey400 = Color(bgra: 0xFFBD_BDBD)
        public static let grey500 = Color(bgra: 0xFF9E_9E9E)
        public static let grey600 = Color(bgra: 0xFF75_7575)
        public static let grey700 = Color(bgra: 0xFF61_6161)
        public static let grey800 = Color(bgra: 0xFF42_4242)
        public static let grey900 = Color(bgra: 0xFF21_2121)
        public static let blueGrey = blueGrey500
        public static let blueGrey50 = Color(bgra: 0xFFEC_EFF1)
        public static let blueGrey100 = Color(bgra: 0xFFCF_D8DC)
        public static let blueGrey200 = Color(bgra: 0xFFB0_BEC5)
        public static let blueGrey300 = Color(bgra: 0xFF90_A4AE)
        public static let blueGrey400 = Color(bgra: 0xFF78_909C)
        public static let blueGrey500 = Color(bgra: 0xFF60_7D8B)
        public static let blueGrey600 = Color(bgra: 0xFF54_6E7A)
        public static let blueGrey700 = Color(bgra: 0xFF45_5A64)
        public static let blueGrey800 = Color(bgra: 0xFF37_474F)
        public static let blueGrey900 = Color(bgra: 0xFF26_3238)
        public static let black = Color(bgra: 0xFF00_0000)
        public static let white = Color(bgra: 0xFFFF_FFFF)
    }
}
