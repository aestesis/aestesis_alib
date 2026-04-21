//
//  IGN.swift
//  Alib
//
//  Created by renan jegouzo on 22/08/2018.
//  Copyright © 2018 aestesis. All rights reserved.
//

import Foundation

// Sendable conformance disabled for credentials storage
// Credentials are set once and only changed via @MainActor
class IGN {
    // https://geoservices.ign.fr/documentation/geoservices/geocodage.html#recherche-par-lieux
    // default: epsg:4326 (=WGS84)  googlemap is EPSG::3857
    nonisolated(unsafe) static var key = ""
    nonisolated(unsafe) static var userAgent = ""
    static let apiSearch = "http://wxs.ign.fr/$key/geoportail/ols"
    public static func search(query: String, fn: @escaping ((Any?) -> Void)) {
        var api = IGN.apiSearch
        api = api.replacingOccurrences(of: "$key", with: IGN.key)
        let xreq = AEXMLDocument()
        let attributes = [
            "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
            "xmlns:xls": "http://www.opengis.net/xls", "xmlns:gml": "http://www.opengis.net/gml",
            "xmlns": "http://www.opengis.net/xls",
            "xsi:schemaLocation":
                "http://www.opengis.net/xls http://schemas.opengis.net/ols/1.2/olsAll.xsd",
            "version": "1.2",
        ]
        let xls = xreq.addChild(name: "XLS", attributes: attributes)
        xls.addChild(name: "RequestHeader")
        let req = xls.addChild(
            name: "Request",
            attributes: [
                "requestID": "1", "version": "1.2", "methodName": "GeocodeRequest",
                "maximumResponses": "1",
            ])
        let greq = req.addChild(name: "GeocodeRequest", attributes: ["returnFreeForm": "true"])
        let adr = greq.addChild(name: "Address", attributes: ["countryCode": "StreetAddress"])
        let q = query.replacingOccurrences(of: ",", with: " ").trim()
        adr.addChild(name: "freeFormAddress", value: q)
        Web.post(url: api, headers: ["User-Agent": IGN.userAgent], xml: xreq) { r in
            if let xdoc = r as? AEXMLDocument {
                fn(xdoc)
            } else if let err = r as? Error {
                fn(Error(err))
            }
        }
    }
    public static func geo(address: String, fn: @escaping (GeoPoint?) -> Void) {
        self.search(query: address) { r in
            if let xdoc = r as? AEXMLDocument {
                if let t = xdoc.root["Response"]["GeocodeResponse"]["GeocodeResponseList"][
                    "GeocodedAddress"]["gml:Point"]["gml:pos"].value
                {
                    let tc = t.split(" ")
                    if tc.count == 2, let lat = Double(tc[0]), let lng = Double(tc[1]) {
                        fn(GeoPoint(lng: lng, lat: lat))
                        return
                    }
                }
                Debug.error("IGN, address not found: \(address)")
                fn(nil)
            } else if let err = r as? Error {
                Debug.error(err)
                fn(nil)
            }
        }
    }
    public static func setCredentials(key: String, userAgent: String) {
        IGN.key = key
        IGN.userAgent = userAgent
    }
}
