//
//  Library.swift
//  Alib
//
//  Created by renan jegouzo on 25/04/2016.
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

/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Library: NodeUI, @unchecked Sendable {
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var keepCount: Int = 100
    public var tryMax: Int = 5
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    var servers: [String]
    var server: String {
        if servers.count == 1 {
            return servers[0]
        }
        return servers[Int(floor(ß.rnd * Double(servers.count) * 0.99999))]
    }
    var images = [String: Image]()
    var urls = Set<String>()
    var downloads = Set<Future>()
    var release = false
    let lock = Lock()
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func bitmap(_ url: String) -> Bitmap? {
        var b: Bitmap? = nil
        lock.sync {
            if let i = self.images[url] {
                b = i.bitmap
            } else {
                self.images[url] = Image(library: self, url: url)
            }
        }
        return b
    }
    func download(_ url: String) -> Future {
        let fut = Future(context: "download")
        fut["url"] = url
        lock.sync {
            if !self.urls.contains(url) {
                self.urls.insert(url)
            }
            self.downloads.insert(fut)
        }
        return fut
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    func run() {
        // cleaner //
        let _ = Thread {
            while !self.release {
                self.lock.sync {
                    if self.images.count > self.keepCount {
                        let l = self.images
                        let a = self.images.values
                        let b = a.sorted(by: { (a, b) -> Bool in
                            return a.lastAccess > b.lastAccess
                        })
                        for i in self.keepCount..<l.count {
                            self.images.removeValue(forKey: b[i].url)
                            b[i].detach()
                        }
                    }
                }
                Thread.sleep(1)
            }
        }
        // downloader //
        let _ = Thread {
            var insrv = true
            var insrvtime = ß.time + 3  // wait first timeout to really start, let time for the app to initialize
            while !self.release {  // TODO: remove download timeout, cleanly
                if !insrv && self.urls.count > 0 {
                    let fm = FileManager.default
                    insrv = true
                    insrvtime = ß.time + 3
                    let url: String = self.urls.first!
                    let filename = Application.localPath("library/" + url)
                    let dir = NSString(string: filename).deletingLastPathComponent
                    if !fm.fileExists(atPath: dir) {
                        do {
                            try fm.createDirectory(
                                atPath: dir, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            Debug.error("error, Library.DownloadManager()")
                        }
                    }
                    if fm.fileExists(atPath: filename) {
                        Debug.error("error, Library.DownloadManager()")
                    }
                    var ntries = 0
                    var next: ((Future) -> Void)? = nil
                    next = { f in
                        if let res = f.result as? Response {
                            res.onClose.once {
                                insrv = false
                                self.lock.sync {
                                    if self.urls.contains(url) {
                                        self.urls.remove(url)
                                        let d = self.downloads
                                        for f in d {
                                            if (f["url"] as! String) == url {
                                                self.downloads.remove(f)
                                                self.bg {
                                                    f.done()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            let writer = FileWriter(
                                filename: filename,
                                error: { err in
                                    Debug.error(Error(err, #file, #line))
                                })
                            res.pipe(to: writer)
                        } else {
                            Debug.error("error downloading asset \(url)  #try: \(ntries)")
                            if ntries < self.tryMax {
                                Thread.sleep(0.1)
                                let _ = Request(url: "\(self.server)\(url)").then(next!)
                                ntries += 1
                            } else {
                                Debug.error("too many tries, aborting.. \(url)")
                                insrv = false
                                self.lock.sync {
                                    self.urls.remove(url)
                                    let d = self.downloads
                                    for f in d {
                                        if (f["url"] as! String) == url {
                                            self.downloads.remove(f)
                                            f.error(
                                                Error(
                                                    "too manies tries Library.download(\(url))",
                                                    #file, #line))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Request(url: "\(self.server)\(url)").then(next!)
                } else if insrv && insrvtime < ß.time {
                    insrv = false
                }
                Thread.sleep(0.1)
            }
        }
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public init(parent: NodeUI, server: String) {
        self.servers = [server]
        super.init(parent: parent)
        run()
    }
    public init(parent: NodeUI, servers: [String]) {
        self.servers = servers
        super.init(parent: parent)
        run()
    }
    public override func detach() {
        release = true
        keepCount = 0
        self.lock.sync {
            for b in self.images.values {
                b.detach()
            }
            self.images.removeAll()
        }
        super.detach()
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    class Image: NodeUI, @unchecked Sendable {
        let url: String
        var bitmap: Bitmap? = nil
        var lastAccess = ß.time
        func load(_ path: String) {
            bitmap = Bitmap(parent: self, path: path)
            lastAccess = ß.time
        }
        override func detach() {
            if let b = bitmap {
                b.detach()
                bitmap = nil
            }
            super.detach()
        }
        init(library: Library, url: String) {
            self.url = url
            super.init(parent: library)
            let path = Application.localPath("library/\(url)")
            if Application.fileExists(path) {
                load(path)
            } else {
                library.download(url).then { fut in
                    if let err = fut.result as? Error {
                        Debug.error(err, #file, #line)
                    } else {
                        self.load(path)
                    }
                }
            }
        }
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
