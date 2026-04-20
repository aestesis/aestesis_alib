//
//  Misc.swift
//  Alib
//
//  Created by renan jegouzo on 22/02/2016.
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

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class ß : Misc {
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Misc {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    public static var alphaID:String {
        let data:String="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
        var id:String="";
        for _ in 1...16 {
            let n:Int=Int(arc4random_uniform(UInt32(UInt(data.count))))
            id+=data[n];
        }
        return id;
    }
    public static func daysHoursMinutesSeconds(_ seconds:Int) -> (d:Int,h:Int,m:Int,s:Int) {
        var s=seconds
        let d:Int=s/(60*60*24)
        s -= d * 60*60*24
        let h:Int = s/(60*60)
        s -= h * 60*60
        let m:Int = s/60
        s -= m*60
        return (d:d,h:h,m:m,s:s)
    }
    public static func nearest(array:[Double],value:Double) -> (index:Int,value:Double) {
        var dm = Double.greatestFiniteMagnitude
        var n = -1
        var i = 0
        for v in array {
            let d=abs(v-value)
            if d<dm {
                dm = d
                n = i
            }
            i += 1
        }
        if i>=0 {
            return (index:n,value:array[n])
        }
        return (index:-1,value:value)
    }
    public static func daysHoursMinutesSecondsInText(_ seconds:Int) -> String {
        let t=ß.daysHoursMinutesSeconds(seconds)
        var r=""
        if t.d>0 {
            r += " \(t.d)d"
        }
        if t.h>0 {
            r += " \(t.h)h"
        }
        if t.m>0 {
            r += " \(t.m)m"
        }
        if t.s>0 && t.d == 0 {
            r += " \(t.s)s"
        }
        return r.trim()
    }
    public static func radian(degree:Double) -> Double {
        return degree*ß.π/180
    }
    public static var rnd:Double {
        return Double(arc4random_uniform(UInt32.max))/Double(UInt32.max)
    }
    public static var time:Double {
        return Double(Date.timeIntervalSinceReferenceDate)
    }
    public static var hour:String {
        let pub = DateFormatter()
        pub.dateFormat="HH:mm:ss"
        return pub.string(from: Date())
    }
    public static var hourMinutes:String {
        let pub = DateFormatter()
        pub.dateFormat="HH:mm"
        return pub.string(from: Date())
    }
    public static var date:String {
        let pub = DateFormatter()
        pub.locale = Locale(identifier:"en_US_POSIX")
        pub.dateFormat="yyyy-MM-dd'T'HH:mm:ssZ"
        return pub.string(from: Date())
        //return NSDate().description
    }
    public static func date(_ date:String) -> Date? {
        let pub = DateFormatter()
        pub.dateFormat="yyyy-MM-dd'T'HH:mm:ssZ"     // maybe: "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return pub.date(from: date)
    }
    public static var dateISO8601:String {
        let pub = ISO8601DateFormatter()
        return pub.string(from:Date())
    }
    public static func dateISO8601(_ date:String) -> Date? {
        let pub = ISO8601DateFormatter()
        if let d = pub.date(from: date) {
            return d
        }
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let d = p.date(from: date) {
            return d
        }
        return nil
    }
    public static var justDate:String {
        let pub = DateFormatter()
        pub.locale = Locale(identifier:"en_US_POSIX")
        pub.timeZone = TimeZone(secondsFromGMT: 0)
        pub.dateFormat="yyyy-MM-dd"
        return pub.string(from:Date())
    }
    public static func justDate(date:String) -> Date? {
        let pub = DateFormatter()
        pub.locale = Locale(identifier:"en_US_POSIX")
        pub.timeZone = TimeZone(secondsFromGMT: 0)
        pub.dateFormat="yyyy-MM-dd"
        return pub.date(from: date)
    }
    public static func justDate(date:Date) -> String {
        let pub = DateFormatter()
        pub.locale = Locale(identifier:"en_US_POSIX")
        pub.timeZone = TimeZone(secondsFromGMT: 0)
        pub.dateFormat="yyyy-MM-dd"
        return pub.string(from:date)
    }
    public static func justLocaleDate(date:String) -> String {
        let pub = DateFormatter()
        pub.locale = Locale(identifier:"en_US_POSIX")
        pub.timeZone = TimeZone(secondsFromGMT: 0)
        pub.dateFormat="yyyy-MM-dd"
        if let d = pub.date(from: date) {
            let pub = DateFormatter()
            pub.timeZone = TimeZone(secondsFromGMT: 0)
            pub.locale = Locale.current
            pub.dateStyle = .medium
            pub.timeZone = .none
            return pub.string(from: d)
        }
        return date
    }
    public static func hasFlag(_ value:Int,_ flag:Int) -> Bool {
        return (value & flag) == flag
    }
    public static func hasFlag(_ value:UInt,_ flag:UInt) -> Bool {
        return (value & flag) == flag
    }
    public static func lerp(from:Double,to:Double,coef:Double) -> Double {
        return from * (1-coef) + to * coef
    }
    public static func lerp(from:Float,to:Float,coef:Double) -> Float {
        return from * (1-Float(coef)) + to * Float(coef)
    }
    public static func lerp(array:[Double],coef:Double) -> Double {
        let nf = coef*Double(array.count)*0.9999999
        let n = Int(nf)
        let f = nf-Double(n)
        if n<array.count-1 {
            let v = array[n]
            let vn = array[n+1]
            return vn*f + v*(1-f)
        }
        return array.last!
    }
    public static func lerp(array:[Float],coef:Double) -> Float {
        let nf = coef*Double(array.count)*0.9999999
        let n = Int(nf)
        let f = nf-Double(n)
        if n<array.count-1 {
            let v = array[n]
            let vn = array[n+1]
            return Float(Double(vn)*f + Double(v)*(1-f))
        }
        return array.last!
    }
    public static func hash(_ s:String) -> String {
        var h = Crypto.SHA256(string:s)
        h = h.replacingOccurrences(of: "/", with: "-")
        return h
    }
    public static func modulo(_ value:Int,_ mod:Int) -> Int {
        return ((value % mod) + mod) % mod
    }
    public static func modulo(_ value:Double,_ mod:Double) -> Double {
        return (value.truncatingRemainder(dividingBy: mod) + mod).truncatingRemainder(dividingBy: mod)
    }
    public static var π:Double {
        return Double.pi
    }
    public static var π2:Double {
        return Double.pi/2
    }
    public static var π4:Double {
        return Double.pi/4
    }
    public static func sign(_ a:Double) -> Double {
        if a == 0 {
            return 0
        }
        return a<0 ? -1 : 1
    }
#if os(Linux)
    public static let clocksPerSeconds = CLOCKS_PER_SEC
#else
    public static let clocksPerSeconds = NSEC_PER_SEC
#endif
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public protocol JsonConvertible {
    var json: JSON { get }
    init(json:JSON)
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public extension Array {
    mutating func push(_ newElement: Element) {
        self.append(newElement)
    }
    @inlinable mutating func pop() -> Element? {
        return self.removeLast()
    }
    @inlinable func peekAtStack() -> Element? {
        return self.last
    }
    @inlinable mutating func enqueue(_ newElement: Element) {
        self.append(newElement)
    }
    @discardableResult
    @inlinable mutating func dequeue() -> Element? {
        if count>0 {
            return self.remove(at: 0)
        } else {
            return nil
        }
    }
    @inlinable func peekAtQueue() -> Element? {
        return self.first
    }
    mutating func appendIndex(_ e:Element) -> Index {
        let n = self.count
        self.append(e)
        return n
    }
}
public extension Array where Element : Equatable {
    func contains(element e:Element) -> Bool {
        return self.contains(where: { ei in
            return e == ei
        })
    }
}
public extension Array where Element == Double {
    mutating func blur(sigma:Int) {
        let r = self
        for i in 0..<count {
            var s:Double = 0
            for j in i-sigma...i+sigma {
                if j<0 || j>=count {
                    s += r[i]
                }
            }
            self[i] = s / Double(sigma*2 + 1)
        }
    }
}
public extension Array where Element == Float {
    mutating func blur(sigma:Int) {
        let r = self
        for i in 0..<count {
            var s:Float = 0
            for j in i-sigma...i+sigma {
                if j<0 || j>=count {
                    s += r[i]
                } else {
                    s += r[j]
                }
            }
            self[i] = s / Float(sigma*2 + 1)
        }
    }
}
public extension String {
    
    @inlinable subscript (i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: i)]
    }
    @inlinable subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    subscript (r: Range<Int>) -> String {
        let start = self.index(startIndex, offsetBy: r.lowerBound)
        let end = self.index(start, offsetBy: r.count)
        return String(self[start..<end])
    }
    subscript (r: ClosedRange <Int>) -> String {
        let start = self.index(startIndex, offsetBy: r.lowerBound)
        let end = self.index(start, offsetBy: r.count-1)
        return String(self[start...end])
    }
    subscript (r: PartialRangeFrom<Int>) -> String {
        let start = self.index(startIndex, offsetBy: r.lowerBound)
        let end = self.index(startIndex, offsetBy: self.length-1)
        return String(self[start...end])
    }
    subscript (r: PartialRangeThrough<Int>) -> String {
        let start = startIndex
        let end = self.index(startIndex, offsetBy: min(r.upperBound,self.length-1))
        return String(self[start...end])
    }
    subscript (r: PartialRangeUpTo<Int>) -> String {
        let start = startIndex
        let end = self.index(startIndex, offsetBy: min(r.upperBound,self.length))
        return String(self[start..<end])
    }
    @inlinable var length:Int {
        return self.count;
    }
    @inlinable func contains(_ s:String) -> Bool {
        return self.range(of:s) != nil
    }
    func matches(_ pattern:String) -> [CountableRange<Int>] {
        var ranges=[CountableRange<Int>]()
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            ranges = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count)).map { Range($0.range)! }
        } catch {
            ranges = []
        }
        return ranges
    }
    func matches(regex:String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern:regex, options: [])
            let ranges = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count)).map { Range($0.range)! }
            return ranges.map { self[$0.lowerBound..<$0.upperBound] }
        } catch {
        }
        return [String]()
    }
    @inlinable func split(_ pattern:String) -> [String] {
        return self.components(separatedBy: pattern)
    }
    func splitByEach(_ characters:String) -> [String] {
        let ch=CharacterSet(charactersIn: characters)
        return self.components(separatedBy: ch)
    }
    @inlinable func trim() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    func indexOf(_ s: String) -> Int? {
        if let r: Range<Index> = self.range(of: s) {
            return self.distance(from: self.startIndex, to: r.lowerBound)
        }
        return nil
    }
    func lastIndexOf(_ s: String) -> Int? {
        if let r: Range<Index> = self.range(of: s, options: .backwards) {
            return self.distance(from: self.startIndex, to: r.lowerBound)
        }
        return nil
    }
    @inlinable var urlEncoded : String? {  // deprecated
        return self.encodedURI
    }
    @inlinable var encodedURI : String? {
        return self.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed)
    }
    var encodedURIComponent : String? {
        var characters = NSCharacterSet.urlQueryAllowed
        characters.remove(charactersIn: "&")
        guard let encodedString = self.addingPercentEncoding(withAllowedCharacters:characters) else {
            return nil
        }
        return encodedString
    }
    func dataFromHex() -> Data? {
        var data = Data(capacity: self.count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    enum Regex {
        case number
        case frenchWords
    }
    static func regex(type:Regex) -> String {
        switch type {
        case .number:
            return "(^|\\s)([0-9]+)($|\\s)"
        case .frenchWords:
            return "[a-zA-Z0-9àâäèéêëîïôœùûüÿçÀÂÄÈÉÊËÎÏÔŒÙÛÜŸÇ]+"
        }
    }
}
public extension Int {
    func formatUsingAbbrevation () -> String {
        let numFormatter = NumberFormatter()
        
        typealias Abbrevation = (threshold:Double, divisor:Double, suffix:String)
        let abbreviations:[Abbrevation] = [(0, 1, ""),
                                           (1000.0, 1000.0, "K"),
                                           (100_000.0, 1_000_000.0, "M"),
                                           (100_000_000.0, 1_000_000_000.0, "B")]
        // you can add more !
        
        let startValue = Double (abs(self))
        let abbreviation:Abbrevation = {
            var prevAbbreviation = abbreviations[0]
            for tmpAbbreviation in abbreviations {
                if (startValue < tmpAbbreviation.threshold) {
                    break
                }
                prevAbbreviation = tmpAbbreviation
            }
            return prevAbbreviation
        } ()
        
        let value = Double(self) / abbreviation.divisor
        numFormatter.positiveSuffix = abbreviation.suffix
        numFormatter.negativeSuffix = abbreviation.suffix
        numFormatter.allowsFloats = true
        numFormatter.minimumIntegerDigits = 1
        numFormatter.minimumFractionDigits = 0
        numFormatter.maximumFractionDigits = 1
        return numFormatter.string(from:NSNumber(value:value))!
    }
}

public extension Float {
    func string(_ fractionDigits:Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value:self)) ?? "\(self)"
    }
}
public extension Double {
    func string(_ fractionDigits:Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value:self)) ?? "\(self)"
    }
    func formatUsingAbbrevation () -> String {
        let numFormatter = NumberFormatter()
        
        typealias Abbrevation = (threshold:Double, divisor:Double, suffix:String)
        let abbreviations:[Abbrevation] = [(0, 1, ""),
                                           (1000.0, 1000.0, "K"),
                                           (100_000.0, 1_000_000.0, "M"),
                                           (100_000_000.0, 1_000_000_000.0, "B")]
        let startValue = abs(self)
        let abbreviation:Abbrevation = {
            var prevAbbreviation = abbreviations[0]
            for tmpAbbreviation in abbreviations {
                if (startValue < tmpAbbreviation.threshold) {
                    break
                }
                prevAbbreviation = tmpAbbreviation
            }
            return prevAbbreviation
        } ()
        
        let value = Double(self) / abbreviation.divisor
        numFormatter.positiveSuffix = abbreviation.suffix
        numFormatter.negativeSuffix = abbreviation.suffix
        numFormatter.allowsFloats = true
        numFormatter.minimumIntegerDigits = 1
        numFormatter.minimumFractionDigits = 0
        numFormatter.maximumFractionDigits = 1
        return numFormatter.string(from:NSNumber(value:value))!
    }
}
public extension Date {
    /// Returns the amount of years from another date
    @inlinable func years(from date: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: date, to: self).year ?? 0
    }
    /// Returns the amount of months from another date
    @inlinable func months(from date: Date) -> Int {
        return Calendar.current.dateComponents([.month], from: date, to: self).month ?? 0
    }
    /// Returns the amount of weeks from another date
    @inlinable func weeks(from date: Date) -> Int {
        return Calendar.current.dateComponents([.weekOfYear], from: date, to: self).weekOfYear ?? 0
    }
    /// Returns the amount of days from another date
    @inlinable func days(from date: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
    /// Returns the amount of hours from another date
    @inlinable func hours(from date: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0
    }
    /// Returns the amount of minutes from another date
    @inlinable func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
    /// Returns the amount of seconds from another date
    @inlinable func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    /// Returns the a custom time interval description from another date
    func offset(from date: Date) -> String {
        if years(from: date)   > 0 { return "\(years(from: date))y"   }
        if months(from: date)  > 0 { return "\(months(from: date))M"  }
        if weeks(from: date)   > 0 { return "\(weeks(from: date))w"   }
        if days(from: date)    > 0 { return "\(days(from: date))d"    }
        if hours(from: date)   > 0 { return "\(hours(from: date))h"   }
        if minutes(from: date) > 0 { return "\(minutes(from: date))m" }
        if seconds(from: date) > 0 { return "\(seconds(from: date))s" }
        return ""
    }
}

public extension Dictionary {
    func has(key: Key) -> Bool {
        return index(forKey: key) != nil
    }
    mutating func removeAll(keys: [Key]) {
        keys.forEach({ removeValue(forKey: $0)})
    }
    func jsonData(prettify: Bool = false) -> Data? {
        guard JSONSerialization.isValidJSONObject(self) else {
            return nil
        }
        let options = (prettify == true) ? JSONSerialization.WritingOptions.prettyPrinted : JSONSerialization.WritingOptions()
        return try? JSONSerialization.data(withJSONObject: self, options: options)
    }
    func jsonString(prettify: Bool = false) -> String? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        let options = (prettify == true) ? JSONSerialization.WritingOptions.prettyPrinted : JSONSerialization.WritingOptions()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: self, options: options) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    static func + (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value] {
        var result = lhs
        rhs.forEach { result[$0] = $1 }
        return result
    }
    static func += (lhs: inout [Key: Value], rhs: [Key: Value]) {
        rhs.forEach { lhs[$0] = $1}
    }
    static func - (lhs: [Key: Value], keys: [Key]) -> [Key: Value] {
        var result = lhs
        result.removeAll(keys: keys)
        return result
    }
    static func -= (lhs: inout [Key: Value], keys: [Key]) {
        lhs.removeAll(keys: keys)
    }
}
public extension Data {
    struct HexEncodingOptions: OptionSet, Sendable {
        public let rawValue: Int
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
        public init(rawValue:Int) {
            self.rawValue = rawValue
        }
    }
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let hexDigits = Array((options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef").utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        for byte in self {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}
#if os(tvOS) || os(iOS)
public extension UIImage {
    func scaledTo(size aSize :CGSize) -> UIImage {
        if self.size.equalTo(aSize) {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(aSize, false, 0.0)
        self.draw(in:CGRect(x:0.0, y:0.0, width:aSize.width, height:aSize.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    func tintedWith(color:UIColor,blend:CGBlendMode = .normal)->UIImage {
        UIGraphicsBeginImageContext(self.size)
        let context = UIGraphicsGetCurrentContext()!
        context.scaleBy(x:1.0,y:-1.0)
        context.translateBy(x:0.0,y:-self.size.height)
        context.setBlendMode(blend)
        let rect = CGRect(x:0,y:0,width:self.size.width,height:self.size.height)
        context.clip(to:rect,mask:self.cgImage!)
        color.setFill()
        context.fill(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class QueueNode<T>  {
    var next:QueueNode?
    var value:T
    init(value:T) {
        self.value=value
    }
}
public struct Queue<T> {
    typealias Node = QueueNode<T>
    var first : Node?
    var last : Node?
    public private(set) var count : Int = 0
    public mutating func enqueue(_ item:T) {
        let i = Node(value:item)
        if let l = last {
            l.next = i
            last = i
        } else {
            first = i
            last = i
        }
        count += 1
    }
    public mutating func dequeue() -> T? {
        if let i=first {
            first = i.next
            if first == nil {
                last = nil
            }
            count -= 1
            return i.value
        }
        return nil
    }
    public init() {
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////


