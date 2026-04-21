//
//  Web.swift
//  Alib
//
//  Created by renan jegouzo on 30/03/2016.
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
import SystemConfiguration

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension URL {
    public var pathAndQuery: String? {
        if let query = query {
            return "\(path)?\(query)"
        }
        return path
    }
}
/*
 public struct URL {
 // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURL_Class/
 var nsurl: Foundation.URL?
 public var scheme: String? {
 if let nu = nsurl {
 return nu.scheme
 }
 return nil
 }
 public var user: String? {
 if let nu = nsurl {
 return nu.user
 }
 return nil
 }
 public var password: String? {
 if let nu = nsurl {
 return nu.password
 }
 return nil
 }
 public var host: String? {
 if let nu = nsurl {
 return nu.host
 }
 return nil
 }
 public var port: Int? {
 if let nu = nsurl {
 if let p = (nu as NSURL).port {
 return Int(truncating: p)
 }
 }
 return nil
 }
 public var path: String {
 if let nu = nsurl {
 return nu.path
 }
 return ""
 }
 public var pathAndQuery: String? {
 if let nu = nsurl {
 var r = ""
 r += nu.path
 if let q = nu.query {
 r += "?" + q
 }
 return r
 }
 return nil
 }
 public var query: String? {
 if let nu = nsurl {
 return nu.query
 }
 return nil
 }
 public var absolute: String? {
 if let nu = nsurl {
 return nu.absoluteString
 }
 return nil
 }
 public init?(string: String) {
 nsurl = Foundation.URL(string: string)
 if nsurl == nil {
 return nil
 }
 }
 }
 */
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Socket: Stream<UInt8>, @unchecked Sendable {
    // https://gist.github.com/kvannotten/57ddd5531c228e7e08c6
    nonisolated(unsafe) static var sockets = [Socket]()
    nonisolated(unsafe) static var queue = DispatchQueue(label: "alib.sockets", qos: .userInitiated)
    nonisolated(unsafe) static var ioqueue = DispatchQueue(label: "alib.sockets.io", qos: .userInitiated)
    nonisolated(unsafe) static var timer: DispatchSourceTimer?
    
    var sread: InputStream?
    var swrite: OutputStream?
    var release = false
    var rBuffer = [UInt8]()
    var handle: Handle?
    
    var connected = false
    var errsock = false
    var readOk = false
    var eof = false
    var start = ß.time
    
    var host: String
    var port: Int
    
    public var alive: Double {
        return ß.time - start
    }
    public override var available: Int {
        return rBuffer.count
    }
    public override var free: Int {
        if CFWriteStreamCanAcceptBytes(swrite) {
            return 1024
        }
        return 0
    }
#if DEBUG
    public override var debugDescription: String {
        return "Socket.init(host:\"\(host)\",port:\(port))"
    }
#endif
    public static var count: Int {
        var nsock = 0
        Socket.queue.sync {
            nsock = sockets.count
        }
        return nsock
    }
    static func run() {
        if timer != nil {
            return
        }
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer!.schedule(wallDeadline: .now(), repeating: 0.01)
        timer!.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 1024)  // TODO: fix bug, larger buffer break audio stream decoding...  crash with the info packets ??
            for s in Socket.sockets {
                if !s.release {
                    if !s.connected {
                        if ß.time - s.start > s.timeout || s.errsock {
                            s.onError.dispatch(Error("can't connect \(s.host):\(s.port)"))
                            s.close()
                        }
                    } else if let sr = s.sread {
                        while CFReadStreamHasBytesAvailable(sr) {
                            let done = CFReadStreamRead(sr, &buffer, buffer.count)  // bug on xml response ?? f6d ?? Access-Control-Max-Age: 43200\r\n\r\nf6d\r\n<?xml version="1.0" encoding="UTF-8"?>
                            if done > 0 {
                                ioqueue.sync {
                                    s.rBuffer.append(contentsOf: buffer[0..<done])
                                }
                                s.onData.dispatch(())
                            } else if done == 0 {  // EOF
                                s.close()
                                break
                            } else if done < 0 {  // error
                                s.onError.dispatch(Error("broken connection  \(s.host):\(s.port)"))
                                s.close()
                                break
                            }
                        }
                        if s.eof {
                            s.close()
                        }
                    }
                }
            }
        }
        timer!.resume()
    }
    public init(host: String, port: Int, secure: Bool = false, timeout: Double = 5) {  // TODO: add SSL support (look at websocket source code in alib)
        //Debug.warning("open socket \(host):\(port)",#file,#line)
        Socket.run()
        self.host = host
        self.port = port
        super.init(timeout: timeout)
        Socket.queue.async {
            var readStream: Unmanaged<CFReadStream>?
            var writeStream: Unmanaged<CFWriteStream>?
            CFStreamCreatePairWithSocketToHost(
                kCFAllocatorDefault, host as CFString, UInt32(port), &readStream, &writeStream)
            self.sread = readStream!.takeRetainedValue()
            self.swrite = writeStream!.takeRetainedValue()
            CFReadStreamScheduleWithRunLoop(self.sread, CFRunLoopGetMain(), CFRunLoopMode.commonModes)
            CFWriteStreamScheduleWithRunLoop(self.swrite, CFRunLoopGetMain(), CFRunLoopMode.commonModes)
            self.handle = Handle({ [weak self] event in
                switch event {
                case .openCompleted:
                    if let this = self, !this.connected {
                        this.connected = true
                        this.onOpen.dispatch(())
                    }
                case .hasSpaceAvailable:
                    self?.onFreespace.dispatch(())
                case .hasBytesAvailable:
                    self?.readOk = true
                case .errorOccurred:
                    self?.errsock = true
                case .endEncountered:
                    self?.eof = true
                default:
                    Debug.warning("Socket unknown event \(event)")
                }
            })
            self.swrite!.delegate = self.handle
            self.sread!.delegate = self.handle
            if secure {
                self.sread!.setProperty(
                    StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
                self.swrite!.setProperty(
                    StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
            }
            self.sread!.open()
            self.swrite!.open()
            Socket.sockets.append(self)
            self.start = ß.time
        }
    }
    public override func close() {
        if !release {
            release = true
            Socket.queue.async {
                if let i = Socket.sockets.firstIndex(of: self) {
                    Socket.sockets.remove(at: i)
                }
                CFReadStreamUnscheduleFromRunLoop(self.sread, CFRunLoopGetMain(), CFRunLoopMode.commonModes)
                CFWriteStreamUnscheduleFromRunLoop(
                    self.swrite, CFRunLoopGetMain(), CFRunLoopMode.commonModes)
                CFReadStreamClose(self.sread)
                CFWriteStreamClose(self.swrite)
                self.sread = nil
                self.swrite = nil
            }
            super.close()
        }
    }
    public override func read(_ desired: Int) -> [UInt8] {
        if desired > 0 {
            var rb: [UInt8]?
            Socket.ioqueue.sync {
                let available = self.available
                let m = min(available, desired)
                rb = Array(self.rBuffer[0..<m])
                self.rBuffer.removeSubrange(0..<m)
            }
            return rb ?? []
        } else {
            Debug.error("error Socket.read(desired:\(desired))")
        }
        return []
    }
    public override func write(_ data: [UInt8], offset: Int, count: Int) -> Int {
        if let sw = swrite {
            var writed: CFIndex = 0
            data.withUnsafeBufferPointer { ptr in
                writed = CFWriteStreamWrite(sw, ptr.baseAddress!.advanced(by: offset), count)
            }
            // return CFWriteStreamWrite(sw,UnsafeMutablePointer(mutating:data).advanced(by: offset),count)
            return writed
        }
        return 0
    }
    class Handle: NSObject, StreamDelegate {
        let fn: (Foundation.Stream.Event) -> Void
        @objc func stream(_ aStream: Foundation.Stream, handle eventCode: Foundation.Stream.Event) {
            fn(eventCode)
        }
        init(_ fn: @escaping (Foundation.Stream.Event) -> Void) {
            self.fn = fn
        }
    }
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class SessionTaskDelegate: NSObject, URLSessionTaskDelegate, URLSessionStreamDelegate, @unchecked Sendable {
    @objc public func urlSession(
        _ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest,
        completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void
    ) {
        Debug.warning("URLSessionTaskDelegate.willBeginDelayedRequest")
    }
    @objc public func urlSession(
        _ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask
    ) {
        Debug.warning("URLSessionTaskDelegate.taskIsWaitingForConnectivity")
    }
    @objc public func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        Debug.warning("URLSessionTaskDelegate.willPerformHTTPRedirection")
    }
    @objc public func urlSession(
        _ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // https://developer.apple.com/documentation/foundation/url_loading_system/handling_an_authentication_challenge
        let authMethod = challenge.protectionSpace.authenticationMethod
        Debug.warning("URLSessionTaskDelegate.didReceiveChallenge \(authMethod)")
        guard authMethod == NSURLAuthenticationMethodHTTPBasic else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(
            .useCredential, URLCredential(user: "renan", password: "password", persistence: .forSession))  // TODO: implements user/password
    }
    
    @objc public func urlSession(
        _ session: URLSession, task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
    ) {
        Debug.warning("URLSessionTaskDelegate.needNewBodyStream")
    }
    @objc public func urlSession(
        _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64, totalBytesExpectedToSend: Int64
    ) {
        Debug.warning("URLSessionTaskDelegate.didSendBodyData")
    }
    @objc public func urlSession(
        _ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        Debug.warning("URLSessionTaskDelegate.didFinishCollectingMetrics")
    }
    @objc public func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?
    ) {
        if let error = error {
            Debug.warning("URLSessionTaskDelegate.didCompleteWithError \(error.localizedDescription)")
        }
    }
    @objc public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Swift.Error?)
    {
        if let error = error {
            Debug.warning(
                "URLSessionTaskDelegate.didBecomeInvalidWithError \(error.localizedDescription)")
        }
    }
    @objc public func urlSession(
        _ session: URLSession, readClosedFor streamTask: URLSessionStreamTask
    ) {
        Debug.warning("URLSessionStreamDelegate.readClosed")
    }
    @objc public func urlSession(
        _ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask
    ) {
        Debug.warning("URLSessionStreamDelegate.writeClosed")
    }
    @objc public func urlSession(
        _ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask
    ) {
        Debug.warning("URLSessionStreamDelegate.betterRouteDiscovered")
    }
    @objc public func urlSession(
        _ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream,
        outputStream: OutputStream
    ) {
        Debug.warning("URLSessionStreamDelegate.CapturedStream")
    }
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Request: Future {  // TODO: request response stream from http, filesystem??..
    // http://www.tcpipguide.com/free/t_HTTPRequestMessageFormat.htm
    static let queue = DispatchQueue(label: "alib.request")
    static let opQueue = OperationQueue()
    static let sessionDelegate = SessionTaskDelegate()
    static let session = URLSession(
        configuration: .default, delegate: sessionDelegate, delegateQueue: opQueue)  //  URLSession(configuration: URLSessionConfiguration.default)
    public let url: URL
    public let method: String
    public let timeOut: Double
    public private(set) var response = Response()
    var client: Socket? = nil
    var streamTask: URLSessionStreamTask? = nil
    var writer = UTF8Writer()
    var release = false
    public init(
        url: String, method: String = "GET", header: [String: String]? = nil, body: String? = nil,
        timeOut: Double = 0.5, useSystemAPI: Bool = false
    ) {
        self.url = URL(string: url)!
        self.method = method
        self.timeOut = timeOut
        let secure = url.contains("https")
        var port = secure ? 443 : 80
        if let p = self.url.port {
            port = Int(p)
        }
        if let host = self.url.host {
            if useSystemAPI {
                Debug.notImplemented()  // TODO: not working yet
                streamTask = Request.session.streamTask(withHostName: host, port: port)
                streamTask?.resume()
            } else {
                client = Socket(host: host, port: port, secure: secure)
                client!.pipe(to: response)
                writer.pipe(to: client!)
            }
        }
        super.init(context: url)
        
        var req = [String]()
        var q = "/"
        if let pq = self.url.pathAndQuery {
            if pq.length > 0 {
                q = pq
            }
        }
        req.append(contentsOf: [
            "\(method) \(q) HTTP/1.1",
            "Date: \(ß.date)",
            "Connection: close",
            "Host: \(self.url.host!)",
        ])
        
        if let body = body {
            req.append("Content-Length: \(body.utf8.count)")
        } else {
            req.append("Content-Length: 0")
        }
        if let hl = header {
            for h in Request.appendDefaultHeader(hl) {
                req.append("\(h.0): \(h.1)")
            }
        }
        req.append(Request.CR)  // empty line
        
        self.response.onClose.once {
            self.close()
        }
        self.response.onData.once {
            if self.response.parseHeader() {
                if self.response.status == 200 {
                    self.autodetach = false
                    self.done(self.response)
                } else {
                    self.error(
                        Response.ResponseError(self.response.statusMessage, self.response, #file, #line))
                }
            } else {
                self.error(Error("Bad http response header", #file, #line))
            }
        }
        
        if let client = client {
            client.onOpen.once {
                Request.queue.async {
                    let header = req.joined(separator: Request.CR)
                    let _ = self.writer.write(header)
                    if let body = body {
                        _ = self.writer.write(body)
                    }
                }
            }
            client.onError.once { (error) in
                self.error(error)
            }
        } else if let task = streamTask {
            Request.queue.async {
                let timer = DispatchSource.makeTimerSource(flags: [], queue: Request.queue)
                if url.contains("https://") {
                    task.startSecureConnection()
                }
                let header = req.joined(separator: Request.CR)
                task.write(header.data(using: .utf8)!, timeout: 1) { err in
                    if let err = err {
                        Debug.error("task.write() header error: \(err.localizedDescription)")
                        Debug.error("url: \(url)")
                    }
                }
                if let body = body {
                    task.write(body.data(using: .utf8)!, timeout: 1) { err in
                        if let err = err {
                            Debug.error("task.write() error: \(err.localizedDescription)")
                        }
                    }
                }
                timer.setEventHandler {
                    task.readData(ofMinLength: 0, maxLength: 2048, timeout: 0.009) { data, eof, err in
                        if let data = data {
                            let buffer = [UInt8](data)
                            _ = self.response.write(buffer, offset: 0, count: buffer.count)
                        } else if let err = err {
                            Debug.error("task.read() error: \(err.localizedDescription)")
                        }
                        if eof {
                            Debug.warning("task.read() EOF")
                        }
                    }
                }
                timer.schedule(deadline: .now(), repeating: 0.01)
                timer.resume()
            }
        } else {
            self.error(Error("wrong URL \(url)", #file, #line))
        }
        
    }
    override public func detach() {
        self.close()
    }
    public func close() {
        if !release {
            release = true
            writer.close()
            response.close()
            if let client = client {
                let alive = client.alive
                if alive > 5 {
                    Debug.warning("long lived Request \(alive.string(2)): \(self.url.absoluteString)")
                }
                client.close()
                self.client = nil
            }
        }
        super.detach()
    }
    public static var CR: String {
        return "\r\n"
    }
    static func appendDefaultHeader(_ header: [String: String]) -> [String: String] {
        var h = header
        if h["User-Agent"] == nil {
            h["User-Agent"] = "Mozilla/4.0"
        }
        return h
    }
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Response: UTF8Reader {
    // http://www.tcpipguide.com/free/t_HTTPResponseMessageFormat.htm#Figure_318
    public private(set) var status: Int = 0
    public private(set) var statusMessage: String = ""
    public private(set) var header = [String: String]()
    func parseHeader() -> Bool {
        if let http = readLine() {
            let htp = http.trim().split(" ")
            if htp.count < 3 {
                onError.dispatch(Error("Wrong Http Response, bad format", #file, #line))
                return false
            }
            if let s = Int(htp[1]) {
                status = s
            } else {
                onError.dispatch(Error("Wrong Http Response, bad format", #file, #line))
                return false
            }
            statusMessage = htp[1..<htp.count].joined(separator: " ")
            while let l = readLine() {
                let t = l.trim()
                if t.length == 0 {
                    break
                }
                let p = t.split(":")
                if p.count >= 2 {
                    header[p[0]] = p[1..<p.count].joined(separator: ":").trim()
                } else {
                    Debug.error("wrong header format, in response: \(l)")
                }
            }
            return true
        }
        return false
    }
    public func readBitmap(_ parent: NodeUI) -> Bitmap? {
        //Debug.info("available: \(available)")
        let data = read(available)
        if data.isEmpty {
            return nil
        }
        Debug.info(
            "magic: " + String(format: "%2x", data[0]) + " " + String(format: "%2x", data[1]) + " "
            + String(format: "%2x", data[2]) + " " + String(format: "%2x", data[3]))
        return Bitmap(parent: parent, data: data)
    }
#if os(iOS) || os(tvOS) || os(macOS)
    public func readData() -> Data? {
        //Debug.info("available: \(available)")
        let data = read(available)
        if data.isEmpty {
            return nil
        }
        return NSData(bytes: data, length: data.count) as Data?
    }
#endif
    public class ResponseError: Error {
        public let response: Response
        init(_ message: String, _ response: Response, _ file: String = #file, _ line: Int = #line) {
            self.response = response
            super.init(message, file, line)
        }
    }
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Web {
    static func parseXML(_ text: String) -> AEXMLDocument? {
        if let a = text.indexOf("<"), let b = text.lastIndexOf(">"), a < b {
            do {
                var t = text[a...b]
                t = t.replacingOccurrences(of: "\n", with: "")
                t = t.replacingOccurrences(of: "\r", with: "")
                t = t.replacingOccurrences(of: "\t", with: "")
                return try AEXMLDocument(xml: t)
            } catch {
                return nil
            }
        }
        return nil
    }
    static func parseJSON(_ text: String) -> JSON? {
        var t = text
        let f0 = t.indexOf("[")
        let f1 = t.indexOf("{")
        if let f0 = f0, let f1 = f1, f1 < f0 {
            if let e = t.lastIndexOf("}") {
                t = t[f1...e]
            }
        } else if let f0 = f0 {
            if let e = t.lastIndexOf("]") {
                t = t[f0...e]
            }
        } else if let f1 = f1 {
            if let e = t.lastIndexOf("}") {
                t = t[f1...e]
            }
        }
        let j = JSON(parseJSON: t)
        if j == JSON.null {
            return nil
        }
        return j
    }
    public static func getText(_ url: String, _ fn: @escaping (Any?) -> Void) {
        let header = [
            "User-Agent": "Mozilla/5.0 \(Application.name)/\(Application.version) (\(Application.author))"
        ]
        let _ = Request(url: url, header: header).then { (fut) in
            if let res = fut.result as? Response {
                res.onClose.once {
                    if let text = res.readAll() {
                        fn(text)
                    } else {
                        fn(Error("empty response: \(url)"))
                    }
                }
            } else if let err = fut.result as? Error {
                if let re: Response.ResponseError = err.get() {
                    re.response.onClose.once {
                        if let text = re.response.readAll() {
                            fn(text)
                        } else {
                            fn(Error("empty response: \(url)"))
                        }
                    }
                } else {
                    fn(Error(err))
                }
            }
        }
    }
    public static func getXML(_ url: String, _ fn: @escaping (Any?) -> Void) {
        let header = [
            "User-Agent": "Mozilla/5.0 \(Application.name)/\(Application.version) (\(Application.author))"
        ]
        let _ = Request(url: url, header: header).then { (fut) in
            if let res = fut.result as? Response {
                res.onClose.once {
                    if let text = res.readAll() {
                        if let xdoc = parseXML(text) {
                            fn(xdoc)
                        } else {
                            fn(Error("xml error: \(url)"))
                        }
                    } else {
                        fn(Error("empty response: \(url)"))
                    }
                }
            } else if let err = fut.result as? Error {
                if let re: Response.ResponseError = err.get() {
                    re.response.onClose.once {
                        if let text = re.response.readAll() {
                            if let xdoc = parseXML(text) {
                                fn(xdoc)
                            } else {
                                fn(Error("xml error: \(url)"))
                            }
                        } else {
                            fn(Error("empty response: \(url)"))
                        }
                    }
                } else {
                    fn(Error(err))
                }
            }
        }
    }
    public static func getJSON(
        _ url: String, headers h: [String: String] = [String: String](), timeOut: Double = 0.5,
        _ fn: @escaping (Any?) -> Void
    ) {
        var header = [
            "User-Agent": "Mozilla/5.0 \(Application.name)/\(Application.version) (\(Application.author))"
        ]
        for (k, v) in h {
            header[k] = v
        }
        //let time = ß.time
        let _ = Request(url: url, header: header, timeOut: timeOut).then { (fut) in
            if let res = fut.result as? Response {
                res.onClose.once {
                    if let text = res.readAll() {
                        if let j = parseJSON(text) {
                            /*
                             let t = ß.time - time
                             if t>1 {
                             Debug.warning("Web.getJSON replies in \(t.string(2)) \(url)")
                             }
                             */
                            fn(j)
                        } else {
                            fn(Error("bad json format \(url)"))
                        }
                    } else {
                        fn(Error("empty response: \(url)"))
                    }
                }
            } else if let err = fut.result as? Error {
                if let re: Response.ResponseError = err.get() {
                    re.response.onClose.once {
                        if let text = re.response.readAll() {
                            if let j = parseJSON(text) {
                                fn(j)
                            } else {
                                fn(Error("bad json format: \(url) \(re.message)"))
                            }
                        } else {
                            fn(Error("empty response: \(url)"))
                        }
                    }
                } else {
                    fn(Error(err))
                }
            }
        }
    }
    public static func getBitmap(parent: NodeUI, url: String, _ fn: @escaping (Any?) -> Void) {
        guard let imageUrl: Foundation.URL = Foundation.URL(string: url) else {
            fn(fn(Error("wrong url format")))
            return
        }
        DispatchQueue.global().async {
            guard let imageData = try? Data(contentsOf: imageUrl) else {
                fn(fn(Error("request error")))
                return
            }
#if os(iOS) || os(tvOS)
            parent.ui {
                if let image = UIImage(data: imageData) {
                    fn(Bitmap(parent: parent, cg: image.cgImage!))
                } else {
                    fn(Error("wrong bitmap data"))
                }
            }
#elseif os(macOS)
            if let image = NSImage(data: imageData),
               let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            {
                fn(Bitmap(parent: parent, cg: cg))
            } else {
                fn(Error("wrong bitmap data"))
            }
#else
            Debug.notImplemented()
#endif
        }
    }
    
    public static func post(
        url: String, headers: [String: String]? = nil, json: JSON, fn: @escaping (Any?) -> Void
    ) {
        var h = headers ?? [String: String]()
        h["Content-Type"] = "application/json"
        let request = Request(url: url, method: "POST", header: h, body: json.rawString())
        request.then { (fut) in
            if let res = fut.result as? Response {
                res.onClose.once {
                    if let s = res.readAll() {
                        fn(JSON(parseJSON: s))
                    } else {
                        fn(JSON.null)
                    }
                }
            } else if let err = fut.result as? Error {
                fn(err)
            }
        }
    }
    public static func post(
        url: String, headers: [String: String] = [String: String](), xml: AEXMLDocument,
        fn: @escaping (Any?) -> Void
    ) {
        var h = [
            "User-Agent":
                "Mozilla/5.0 \(Application.name)/\(Application.version) (\(Application.author))",
            "Content-Type": "application/xml",
        ]
        for (k, v) in headers {
            h[k] = v
        }
        let request = Request(url: url, method: "POST", header: h, body: xml.xmlCompact)
        request.then { (fut) in
            if let res = fut.result as? Response {
                res.onClose.once {
                    if let text = res.readAll() {
                        if let xdoc = parseXML(text) {
                            fn(xdoc)
                        } else {
                            fn(Error("bad xml format: \(url)"))
                        }
                    } else {
                        fn(Error("empty response: \(url)"))
                    }
                }
            } else if let err = fut.result as? Error {
                if let re: Response.ResponseError = err.get() {
                    re.response.onClose.once {
                        if let text = re.response.readAll() {
                            if let xdoc = parseXML(text) {
                                fn(xdoc)
                            } else {
                                fn(Error("bad xml format: \(url)"))
                            }
                        } else {
                            fn(Error("empty response: \(url)"))
                        }
                    }
                } else {
                    fn(Error(err))
                }
            }
        }
    }
    public struct Multipart {
        public var disposition: String
        public var type: String?
        public var content: String
    }
    /*
     if let url = Foundation.URL(string:"\(dburl)image/\(id)\(crop ? "?crop=true" : "")") {
     let boundary = "boundary_____\(ß.alphaID)"
     let preboundary = "--\(boundary)"
     var req = URLRequest(url:url)
     req.httpMethod = "POST"
     req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
     var body = Data()
     body.append(preboundary.data(using:.utf8)!)
     body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
     body.append("Content-Type: image/png\r\n".data(using: .utf8)!)
     body.append("\r\n".data(using: .utf8)!)
     body.append(image.pngData()!)
     body.append("\r\n".data(using: .utf8)!)
     body.append("--\(boundary)--".data(using: .utf8)!)
     req.httpBody = body
     req.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
     let task = URLSession.shared.dataTask(with: req) { data, response, error in
     guard let data = data, error == nil else {
     Debug.error(error?.localizedDescription ?? "No data")
     return
     }
     fn?(JSON(data))
     }
     task.resume()
     }*/
    public static func post(
        url: String, headers: [String: String]? = nil, multipart: [Multipart],
        sign: ((String) -> ([String: String]))? = nil, fn: @escaping (Any?) -> Void
    ) {
        // https://www.w3.org/TR/html401/interact/forms.html#h-17.13.4.2
        Debug.notImplemented()  // TODO: debug it (upload image)
        var h = headers ?? [String: String]()
        let boundary = "boundary______\(ß.alphaID)"
        h["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        var body = ""
        for f in multipart {
            body.append("--\(boundary)\(Request.CR)")
            body.append("Content-Disposition: \(f.disposition)\(Request.CR)")
            if let t = f.type {
                body.append("Content-type: \(t)\(Request.CR)")
            }
            body.append(Request.CR)
            body.append(f.content)
        }
        body.append(contentsOf: "--\(boundary)--")
        var u = url
        if let sign = sign {
            let params = sign(body)
            for (k, v) in params {
                if u.contains("?") {
                    u += "&\(k)=\(v.encodedURIComponent!)"
                } else {
                    u += "?\(k)=\(v.encodedURIComponent!)"
                }
            }
        }
        h["Content-Length"] = String(body.count)
        let request = Request(url: u, method: "POST", header: h, body: body)
        request.then { (fut) in
            if let res = fut.result as? Response {
                res.onClose.once {
                    if let s = res.readAll() {
                        Debug.warning("post response: \(s)")
                        fn(JSON(parseJSON: s))
                    } else {
                        fn(JSON.null)
                    }
                }
            } else if let err = fut.result as? Error {
                fn(err)
            }
        }
    }
    public static func post(
        url: String, headers: [String: String]? = nil, form: [String: String],
        sign: ((String) -> ([String: String]))? = nil, fn: @escaping (Any?) -> Void
    ) {
        var mp = [Multipart]()
        for f in form {
            mp.append(Multipart(disposition: "form-data; name=\"\(f.0)\"", type: nil, content: f.1))
        }
        Web.post(url: url, headers: headers, multipart: mp, sign: sign, fn: fn)
    }
#if os(iOS) || os(tvOS)
    /*
     if let url = Foundation.URL(string:"\(dburl)image/\(id)\(crop ? "?crop=true" : "")") {
     let boundary = "boundary_____\(ß.alphaID)"
     let preboundary = "--\(boundary)"
     var req = URLRequest(url:url)
     req.httpMethod = "POST"
     req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
     var body = Data()
     body.append(preboundary.data(using:.utf8)!)
     body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
     body.append("Content-Type: image/png\r\n".data(using: .utf8)!)
     body.append("\r\n".data(using: .utf8)!)
     body.append(image.pngData()!)
     body.append("\r\n".data(using: .utf8)!)
     body.append("--\(boundary)--".data(using: .utf8)!)
     req.httpBody = body
     req.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
     let task = URLSession.shared.dataTask(with: req) { data, response, error in
     guard let data = data, error == nil else {
     Debug.error(error?.localizedDescription ?? "No data")
     return
     }
     fn?(JSON(data))
     }
     task.resume()
     }*/
    public static func post(
        url: String, headers: [String: String]? = nil, form: [String: String]? = nil, image: UIImage,
        filename: String = "image.png", fn: @escaping (Any?) -> Void
    ) {
        let png = image.pngData()
        var mp = [
            Multipart(
                disposition: "form-data; name=\"file\"; filename=\"\(filename)\"", type: "image/png",
                mesh: png!.base64EncodedString())
        ]
        if let form = form {
            for f in form {
                mp.append(Multipart(disposition: "form-data; name=\"\(f.0)\"", type: nil, mesh: f.1))
            }
        }
        Web.post(url: url, headers: headers, multipart: mp, fn: fn)
    }
#endif
    public static func getICE(
        url: String, header headerfn: (([String: String]) -> Void)? = nil,
        meta: (([String: String]) -> Void)? = nil,
        audio: (([String: String], Stream<UInt8>) -> Void)? = nil, error: ((Error) -> Void)? = nil
    ) -> Request {
        let header = ["User-Agent": "WinampMPEG/5.09", "Icy-MetaData": "1"]
        let r = Request(url: url, header: header)
        let _ = r.then { (fut) in
            if let res = fut.result as? Response {
                if let rmi = res.header["icy-metaint"] {
                    if let mi = Int(rmi) {
                        var co = 0
                        let ms = CircularStream<UInt8>(capacity: 65536 * 2, zero: 0)
                        r.onDetach.once {
                            res.close()
                        }
                        ms.onClose.once {
                            res.close()
                        }
                        if let fn = headerfn {
                            fn(res.header)
                        }
                        if let fn = audio {
                            fn(res.header, ms)
                        }
                        var needed = 1
                        let _ = res.onData.always({
                            while true {
                                let na = min(res.available, ms.free)
                                if na <= 0 {
                                    break
                                }
                                let n = min(na, mi - co)
                                if n > 0 {
                                    let b = res.read(n)
                                    co += b.count
                                    let _ = ms.write(b, offset: 0, count: b.count)
                                    
                                }
                                if co == mi {
                                    if res.available < needed {  // wait next call for more data
                                        break
                                    }
                                    if needed == 1 {
                                        let b = res.read(1)
                                        needed = Int(b[0]) * 16
                                        
                                    }
                                    if needed == 0 {
                                        co = 0
                                        needed = 1
                                    } else if needed > 1 && res.available >= needed {
                                        var metadata = [String: String]()
                                        let buf = res.read(needed)
                                        if let mstring = String(bytes: buf, encoding: String.Encoding.utf8) {
                                            for l in mstring.split(";") {
                                                let ww = l.split("=")
                                                if ww.count == 2 {
                                                    let k = ww[0].trim()
                                                    let v = ww[1]
                                                    if let b = v.indexOf("'") {
                                                        if let e = v.lastIndexOf("'") {
                                                            if e - b > 1 {
                                                                metadata[k] = v[b + 1..<e].trim()
                                                            } else {
                                                                metadata[k] = ""
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if let fn = meta {
                                                fn(metadata)
                                            }
                                        }
                                        co = 0
                                        needed = 1
                                    }
                                }
                            }
                        })
                    }
                } else {
                    if let fn = meta {
                        fn(res.header)
                    }
                    if let fn = audio {
                        fn(res.header, res)
                    }
                }
            } else if let err = fut.result as? Error {
                if let fn = error {
                    fn(err)
                }
            }
        }
        return r
    }
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
