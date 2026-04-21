//
//  Geo.swift
//  Alib
//
//  Created by renan jegouzo on 23/08/2018.
//  Copyright © 2018 aestesis. All rights reserved.
//

import CoreLocation
import Foundation

// http://wiki.geojson.org/GeoJSON_draft_version_6#Polygon

public struct GeoPoint {
    public var lat: Double
    public var lng: Double
    public var latitude: Double {
        return lat
    }
    public var longitude: Double {
        return lng
    }
    public init(geojson: JSON) {
        if geojson["type"].stringValue == "Point" {
            let c = geojson["coordinates"]
            lng = c[0].doubleValue
            lat = c[1].doubleValue
        } else {
            lng = 0
            lat = 0
            Debug.error("GeoPoint.init() bad json format")
        }
    }
    public init?(json: JSON) {
        if let lat = json["lat"].double {
            self.lat = lat
        } else if let lat = json["latitude"].double {
            self.lat = lat
        } else {
            return nil
        }
        if let lng = json["lng"].double {
            self.lng = lng
        } else if let lng = json["long"].double {
            self.lng = lng
        } else if let lng = json["longitude"].double {
            self.lng = lng
        } else {
            return nil
        }
    }
    public init?(json: [String: JSON]) {
        if let lat = json["lat"]?.double {
            self.lat = lat
        } else {
            return nil
        }
        if let lng = json["lng"]?.double {
            self.lng = lng
        } else {
            return nil
        }
    }
    public init(_ gms: CLLocationCoordinate2D) {
        lat = gms.latitude
        lng = gms.longitude
    }
    public init(_ lng: Double, _ lat: Double) {
        self.lat = lat
        self.lng = lng
    }
    public init(lng: Double, lat: Double) {
        self.lat = lat
        self.lng = lng
    }
    public var geojson: JSON {
        return JSON(["type": "Point", "coordinates": [lng, lat]] as [String: Any])
    }
    public var json: JSON {
        return JSON(["lng": lng, "lat": lat])
    }
    public var locationCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    public var location: CLLocation {
        return CLLocation(
            coordinate: self.locationCoordinate, altitude: 0, horizontalAccuracy: 0,
            verticalAccuracy: 0, course: 0, speed: 0, timestamp: Date())
    }
    public var cell: GeoCell {
        return GeoCell(self)
    }
    public var string: String {
        return "(\(lng),\(lat))"
    }
    public static var zero: GeoPoint {
        return GeoPoint(lng: 0, lat: 0)
    }
    public func distance(from: GeoPoint) -> Double {  // in meters
        return self.location.distance(from: from.location)
    }
    public func square(border meters: Double) -> GeoRect {
        let rad2deg = 180 / ß.π
        let deg2rad = ß.π / 180
        let m = meters * 0.5
        let r = 6378137.0  // earth radius
        let d = GeoPoint(lng: (m / (r * cos(lat * deg2rad))) * rad2deg, lat: (m / r) * rad2deg)
        return GeoRect(sw: self - d, ne: self + d)
    }
    public static func fromGoogle(
        apiKey: String, address: String, fn: @escaping @Sendable (GeoPoint?) -> Void
    ) {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!
        let key = URLQueryItem(name: "key", value: apiKey)
        let address = URLQueryItem(name: "address", value: address)
        components.queryItems = [key, address]
        let task = URLSession.shared.dataTask(with: components.url!) { data, response, error in
            guard let data = data, let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200, error == nil
            else {
                Debug.error(String(describing: response))
                Debug.error(String(describing: error))
                fn(nil)
                return
            }
            do {
                let json = try JSON(data: data)
                guard let status = json["status"].string, status == "OK" else {
                    fn(nil)
                    return
                }
                if let g = GeoPoint(
                    json: json["results"][0]["geometry"]["location"].dictionaryValue)
                {
                    DispatchQueue.main.async {
                        fn(g)
                    }
                }
            } catch {
                Debug.error("google geocode error")
                fn(nil)
            }
        }
        task.resume()
    }
}

public func == (lhs: GeoPoint, rhs: GeoPoint) -> Bool {
    return (lhs.lng == rhs.lng) && (lhs.lat == rhs.lat)
}
public func != (lhs: GeoPoint, rhs: GeoPoint) -> Bool {
    return (lhs.lng != rhs.lng) || (lhs.lat != rhs.lat)
}
public func += (left: inout GeoPoint, right: GeoPoint) {
    left = left + right
}
public func -= (left: inout GeoPoint, right: GeoPoint) {
    left = left - right
}
public func + (lhs: GeoPoint, rhs: GeoPoint) -> GeoPoint {
    return GeoPoint((lhs.lng + rhs.lng), (lhs.lat + rhs.lat))
}
public func - (lhs: GeoPoint, rhs: GeoPoint) -> GeoPoint {
    return GeoPoint((lhs.lng - rhs.lng), (lhs.lat - rhs.lat))
}
public prefix func - (lhs: GeoPoint) -> GeoPoint {
    return GeoPoint(-lhs.lng, -lhs.lat)
}
public func * (lhs: GeoPoint, rhs: GeoPoint) -> GeoPoint {
    return GeoPoint((lhs.lng * rhs.lng), (lhs.lat * rhs.lat))
}
public func * (lhs: GeoPoint, rhs: Double) -> GeoPoint {
    return GeoPoint((lhs.lng * rhs), (lhs.lat * rhs))
}
public func / (lhs: GeoPoint, rhs: GeoPoint) -> GeoPoint {
    return GeoPoint((lhs.lng / rhs.lng), (lhs.lat / rhs.lat))
}
public func / (lhs: GeoPoint, rhs: Double) -> GeoPoint {
    return GeoPoint((lhs.lng / rhs), (lhs.lat / rhs))
}
public func * (lhs: GeoPoint, rhs: Size) -> GeoPoint {
    return GeoPoint((lhs.lng * rhs.w), (lhs.lat * rhs.h))
}
public func / (lhs: GeoPoint, rhs: Size) -> GeoPoint {
    return GeoPoint((lhs.lng / rhs.w), (lhs.lat / rhs.h))
}

public struct GeoCell: Hashable, Equatable {  // used as index in dictionnaries
    static let size: Double = 0.0005
    static let isize: Double = 1 / size
    public var lat: Int
    public var lng: Int
    public var bounds: GeoRect {
        let p = GeoPoint(Double(lng) * GeoCell.size, Double(lat) * GeoCell.size)
        return GeoRect(sw: p, ne: p + GeoPoint(GeoCell.size, GeoCell.size))
    }
    public init(lat: Int, lng: Int) {
        self.lat = lat
        self.lng = lng
    }
    public init(_ p: GeoPoint) {
        lat = Int(floor(p.lat * GeoCell.isize))
        lng = Int(floor(p.lng * GeoCell.isize))
    }
    public func hash(into hasher: inout Hasher) {
        lat.hash(into: &hasher)
        lng.hash(into: &hasher)
    }
    /*
    public var hashValue : Int {
        var hash = 17
        hash = hash.multipliedReportingOverflow(by:31).partialValue
        hash = hash.addingReportingOverflow(lat.hashValue).partialValue
        hash = hash.multipliedReportingOverflow(by:31).partialValue
        hash = hash.addingReportingOverflow(lng.hashValue).partialValue
        return hash
    }
 */
    public static func == (l: GeoCell, r: GeoCell) -> Bool {
        return l.lat == r.lat && l.lng == r.lng
    }
}

public struct GeoRect {
    public var southWest: GeoPoint  // lesser value
    public var northEast: GeoPoint  // bigger value
    public var sw: GeoPoint {
        get {
            return southWest
        }
        set(v) {
            southWest = v
        }
    }
    public var ne: GeoPoint {
        get {
            return northEast
        }
        set(v) {
            northEast = v
        }
    }
    public var center: GeoPoint {
        return (southWest + northEast) * 0.5
    }
    public var size: GeoPoint {
        return ne - sw
    }
    public init(sw: GeoPoint, ne: GeoPoint) {
        southWest = sw
        northEast = ne
    }
    public init(west: Double, south: Double, east: Double, north: Double) {
        southWest = GeoPoint(lng: west, lat: south)
        northEast = GeoPoint(lng: east, lat: north)
    }
    public init(w: Double, s: Double, e: Double, n: Double) {
        southWest = GeoPoint(lng: w, lat: s)
        northEast = GeoPoint(lng: e, lat: n)
    }
    public func union(_ r: GeoRect) -> GeoRect {
        if r == .zero {
            return self
        } else if self == .zero {
            return r
        }
        var rr = GeoRect.zero
        rr.southWest.lng = min(self.southWest.lng, r.southWest.lng)
        rr.southWest.lat = min(self.southWest.lat, r.southWest.lat)
        rr.northEast.lng = max(self.northEast.lng, r.northEast.lng)
        rr.northEast.lat = max(self.northEast.lat, r.northEast.lat)
        return rr
    }
    public func union(_ p: GeoPoint) -> GeoRect {
        return self.union(GeoRect(sw: p, ne: p))
    }
    public func contains(_ point: GeoPoint) -> Bool {
        return point.lat >= southWest.lat && point.lng >= southWest.lng
            && point.lat <= northEast.lat && point.lng <= northEast.lng
    }
    public func contains(_ rect: GeoRect) -> Bool {
        return rect.southWest.lat >= self.southWest.lat && rect.southWest.lng >= self.southWest.lng
            && rect.northEast.lat <= self.northEast.lat && rect.northEast.lng <= self.northEast.lng
    }
    public var geojson: JSON {
        return JSON(
            [
                "type": "Polygon",
                "coordinates": [
                    [[sw.lng, sw.lng], [sw.lng, ne.lat], [ne.lng, ne.lat], [ne.lng, sw.lat]]
                ],
            ] as [String: Any])
    }
    public var bounds: [Double] {  // west,south,north,east
        return [sw.lng, sw.lat, ne.lng, ne.lat]
    }
    public var query: String {
        return "\(sw.lng),\(sw.lat),\(ne.lng),\(ne.lat)"
    }
    public static var zero: GeoRect {
        return GeoRect(sw: .zero, ne: .zero)
    }
    public static var world: GeoRect {
        return GeoRect(sw: GeoPoint(lng: -180, lat: -90), ne: GeoPoint(lng: 180, lat: 90))
    }
}

public func == (lhs: GeoRect, rhs: GeoRect) -> Bool {
    return (lhs.sw == rhs.sw) && (lhs.ne == rhs.ne)
}
public func != (lhs: GeoRect, rhs: GeoRect) -> Bool {
    return (lhs.sw != rhs.sw) || (lhs.ne != rhs.ne)
}
public func + (lhs: GeoRect, rhs: GeoRect) -> GeoRect {
    return GeoRect(
        sw: GeoPoint(lng: min(lhs.sw.lng, rhs.sw.lng), lat: min(lhs.sw.lat, rhs.sw.lat)),
        ne: GeoPoint(lng: max(lhs.ne.lng, rhs.ne.lng), lat: max(lhs.ne.lat, rhs.ne.lat)))
}
public func + (lhs: GeoRect, rhs: GeoPoint) -> GeoRect {
    return GeoRect(
        w: min(lhs.sw.lng, rhs.lng), s: min(lhs.sw.lat, rhs.lat), e: max(lhs.ne.lng, rhs.lng),
        n: max(lhs.ne.lat, rhs.lat))
}
/*

 TODO:
 public func *(lhs: GeoRect, rhs: Size) -> GeoRect {
 return GeoRect(x:lhs.x*rhs.w,y:lhs.y*rhs.h,w:lhs.w*rhs.w,h:lhs.h*rhs.h)
 }
 public func /(lhs: GeoRect, rhs: Size) -> GeoRect {
 return GeoRect(x:lhs.x/rhs.w,y:lhs.y/rhs.h,w:lhs.w/rhs.w,h:lhs.h/rhs.h)
 }
 public func *(l:GeoRect,r:Double) -> GeoRect {
 return GeoRect(x:l.x*r,y:l.y*r,w:l.w*r,h:l.h*r)
 }
 public func /(l:GeoRect,r:Double) -> GeoRect {
 return GeoRect(x:l.x/r,y:l.y/r,w:l.w/r,h:l.h/r)
 }
 */
