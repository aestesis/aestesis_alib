//
//  Application.swift
//  Alib
//
//  Created by renan jegouzo on 13/03/2016.
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

#if os(OSX)
    import AppKit
#else
    import UIKit
#endif

public class Application {
    #if os(OSX)
    @MainActor public static var applicationDelegate : OsAppDelegate {
        return NSApplication.shared.delegate as! OsAppDelegate
    }
    #else
    @MainActor public static var applicationDelegate : OsAppDelegate {
        return UIApplication.shared.delegate as! OsAppDelegate
    }
    #endif
    //public static let events = MultiEvent<String>()
    nonisolated(unsafe) public static var launches : Int = 0
    nonisolated(unsafe) public static var author:String = "aestesis"
    public static let onPause=Event<Void>()
    public static let onResume=Event<Void>()
    public static let onStop=Event<Void>()
    nonisolated(unsafe) public static var live=[String:Any]()
    nonisolated(unsafe) public static var db=Application()
    public static var id:String {
        return Bundle.main.bundleIdentifier!
    }
    public static var name:String {
        return Bundle.main.infoDictionary!["CFBundleName"] as! String
    }
    public static var version:String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }
    public static var build:String {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    }
    #if os(OSX) || os(iOS)
    public subscript(key: String) -> String? {
        get { return UserDefaults.standard.string(forKey:key) }
        set(v) { UserDefaults.standard.setValue(v,forKey:key) }
    }
    public func synchronize() {
        UserDefaults.standard.synchronize()
    }
    public func clear() {
        Debug.warning("clearing user data")
        UserDefaults.standard.removePersistentDomain(forName: Application.id)
    }
    public private(set) var loaded = true
    init() {
        Debug.warning("application initialized")
        Device.initialize()
    }
    #else
    var def = [String:String]()
    public subscript(key: String) -> String? {
        get { return def[key] }
        set(v) { def[key] = v }
    }
    public func synchronize() {
        Application.setJSON(Application.localPath(".defaults.json"), JSON(def))
    }
    public func clear() {
        def.removeAll()
    }
    public private(set) var loaded = false
    init() {
        Debug.warning("application initialized")
        Device.initialize()
        Debug.warning("Application.db: loading")
        srand48(Int(ß.time))
        Application.getJSON(Application.localPath(".defaults.json")) { json in
            for (k,v) in json.dictionaryValue {
                self.def[k] = v.stringValue
                //Debug.info("loaded db[\(k)]")
            }
            self.loaded = true
        Debug.warning("Application.db: loaded")
        }
    }
    #endif
    public var secureUrls = SynchronizedDictionnary<String,Foundation.URL>()
    deinit {
        for url in secureUrls.values {
            url.stopAccessingSecurityScopedResource()
        }
    }
    public func contains(key: String) -> Bool {
        if let _ = self[key] {
            return true
        }
        return false
    }
    public func json(_ key:String) -> JSON? {
        if let data = self[key] {
            let json = JSON(parseJSON: data)
            return json
        }
        return nil
    }
    public func json(_ key:String,value:JSON) {
        if let text = value.rawString() {
            self[key] = text
        } else {
            Debug.error("can't convert JSON to text",#file,#line);
        }
    }
    public func secureUrl(string:String,write:Bool = false) -> Foundation.URL? {
        if let surl = secureUrls[string] {
            return surl
        }
        guard let url = Foundation.URL(string:string) else {
            return nil
        }
        #if os(iOS)
        do {
            let scope:Foundation.URL.BookmarkCreationOptions = write ? [.withSecurityScope] : [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
            if !contains(key: string){
                let data = try url.bookmarkData(options: scope)
                self[string] = data.base64EncodedString()
            } else {
                let data = Data(base64Encoded: self[string]!,options: [])!
                var stale:Bool = false
                let surl = try Foundation.URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
                if surl.startAccessingSecurityScopedResource() {
                    secureUrls[string] = surl
                } else {
                    Debug.warning("secureUrl(\(string)) security scope error")
                }
                if(stale) {
                    let data = try surl.bookmarkData(options: scope)
                    self[string] = data.base64EncodedString()
                    return surl
                } else {
                    return surl
                }
            }
        } catch {
            Debug.error("Application.secureUrl() error: \(error.localizedDescription)")
        }
        #endif
        return url
    }
    public static func localPath(_ path:String) -> String {
        #if os(OSX)
            let sup=NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
            let dir=sup+"/"+Bundle.main.bundleIdentifier!+"/"
            let fm=FileManager.default
            if !fm.fileExists(atPath: dir) {
                do {
                    try fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    Debug.error(Error("can't create app local directory",#file,#line))
                }
            }
            return dir+path
        #elseif os(iOS)
            let dir=NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
            return dir+"/"+path
        #elseif os(tvOS)
            let dir=NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).last!
            return dir+"/"+path
        #endif
    }
    public static func resourcePath(_ path:String, bundle: Bundle = Bundle.main) -> String {
        if path[0]=="/" {
            return path
        }
        return "\(bundle.resourcePath!)/\(path)"
    }
    public static func fileExists(_ path:String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    public static func getText(_ path:String,_ fn:@escaping (String?)->()) {
        let p=Application.resourcePath(path)
        if FileManager.default.fileExists(atPath: p) {
            let f=FileReader(filename:p)
            let r=UTF8Reader()
            r.onClose.once {
                if let s=r.readAll() {
                    fn(s)
                } else {
                    fn(nil)
                }
            }
            r.onError.once { err in
                fn(nil)
            }
            f.pipe(to:r)
        } else {
            fn(nil)
        }
    }
    public static func readText(_ path:String,_ fn:(UTF8Reader?)->()) {
        let p=Application.resourcePath(path)
        if FileManager.default.fileExists(atPath: p) {
            let f=FileReader(filename:p)
            let r=UTF8Reader()
            f.pipe(to:r)
            fn(r)
        } else {
            fn(nil)
        }
    }
    public static func getJSON(_ path:String,_ fn:@escaping (JSON)->()) {
        let p=Application.resourcePath(path)
        if FileManager.default.fileExists(atPath: p) {
            let f=FileReader(filename:p)
            let r=UTF8Reader()
            r.onClose.once {
                if let s=r.readAll() {
                    fn(JSON(parseJSON:s))
                }
            }
            r.onError.once { err in
                fn(JSON.null)
            }
            f.pipe(to:r)
        } else {
            fn(JSON.null)
        }
    }
    public static func setJSON(_ path:String,_ json:JSON) {
        let f=FileWriter(filename:path)
        let w=UTF8Writer()
        w.pipe(to:f)
        let _ = w.write(json.rawString()!)
        w.close()
    }
    public static func open(url:String)  {
        #if os(iOS)
            if let nsurl = Foundation.URL(string:url) {
                UIApplication.shared.open(nsurl)
            } else {
                Debug.error("can't open \(url) in default browser")
            }
        #elseif os(macOS)
            if let nsurl = Foundation.URL(string:url) {
                NSWorkspace.shared.open(nsurl)
            } else {
                Debug.error("can't open \(url) in default browser")
            }
        #else
            Debug.notImplemented()
        #endif
    }
    @MainActor public static func stop() {
        Application.onStop.dispatch(())
        Application.live.removeAll()
        Application.db.synchronize()
        #if os(OSX)
            NSApplication.shared.terminate(nil)
        #endif
    }
    public static func pause() {
        onPause.dispatch(())
    }
    public static func resume() {
        onResume.dispatch(())
    }
}
