//
//  Thread.swift
//  Alib
//
//  Created by renan jegouzo on 03/03/2016.
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

public class Thread: Atom {
    var nst: Foundation.Thread?
    init(nst: Foundation.Thread) {
        self.nst = nst
    }
    static var callStackSymbols: [String] {
        return Foundation.Thread.callStackSymbols
    }
    static var current: Thread {
        if let t = Foundation.Thread.current.threadDictionary["aestesis.alib.Thread"] as? Thread {
            return t
        }
        let t = Thread(nst: Foundation.Thread.current)
        Foundation.Thread.current.threadDictionary["aestesis.alib.Thread"] = t
        return t
    }
    var dictionary = [String: Any]()
    subscript(key: String) -> Any? {
        get { return dictionary[key] }
        set(v) { dictionary[key] = v }
    }
    public static func sleep(_ seconds: Double) {
        Foundation.Thread.sleep(forTimeInterval: TimeInterval(seconds))
    }
    public static var callstack: [String] {
        return Foundation.Thread.callStackSymbols
    }
    @objc func darun(_ obj: AnyObject?) {
        if let a = obj as? Action<Void> {
            a.invoke(())
        }
    }
    public init(name:String? = nil, _ fn: @escaping () -> Void) {
        super.init()
        nst = Foundation.Thread(target: self, selector: #selector(darun), object: Action<Void>(fn))
        if let name = name {
            nst!.name = name
        }
        nst!.start()
    }
    public func cancel() {
        if let t = nst, !t.isCancelled {
            t.cancel()
        }
    }
    public var cancelled: Bool {
        if let t = nst {
            return t.isCancelled
        }
        return true
    }
    public var priority: Double {
        get { return nst!.threadPriority }
        set(p) { nst!.threadPriority = p }
    }
    var name:String {
        get {
            return nst!.name ?? "unnamed"
        }
        set (name) {
            nst!.name = name
        }
    }
}

public class SynchronizedValue<T> {
    private let accessQueue = DispatchQueue(label: "SynchronizedValueAccess")
    private var _value:T?
    var value:T? {
        get {
            var v:T?
            accessQueue.sync {
                v = _value
            }
            return v
        }
        set(v) {
            accessQueue.async { [weak self] in
                self?._value = v
            }
        }
    }
}


public class SynchronizedArray<T> {
    private var array: [T] = []
    private let accessQueue = DispatchQueue(label: "SynchronizedArrayAccess", attributes: .concurrent)
    
    public func append(_ newElement: T) {
        self.accessQueue.async(flags: .barrier) {
            self.array.append(newElement)
        }
    }
    
    public func remove(at index: Int) -> T {
        var element: T?
        self.accessQueue.sync(flags: .barrier) {
            element = self.array.remove(at: index)
        }
        return element!
    }
    
    public var count: Int {
        var count = 0
        self.accessQueue.sync {
            count = self.array.count
        }
        return count
    }

    public var isEmpty: Bool {
        var isEmpty = false
        self.accessQueue.sync {
            isEmpty = self.array.isEmpty
        }
        return isEmpty
    }

    public var first:T? {
        get {
            var element: T?
            self.accessQueue.sync {
                element = self.array.first
            }
            return element
        }
    }

    public var last:T? {
        get {
            var element: T?
            self.accessQueue.sync {
                element = self.array.last
            }
            return element
        }
    }

    public func removeLast() -> T {
        var element: T?
        self.accessQueue.sync {
            element = self.array.removeLast()
        }
        return element!

    }
    
    public subscript(index: Int) -> T {
        set {
            self.accessQueue.async(flags: .barrier) {
                self.array[index] = newValue
            }
        }
        get {
            var element: T!
            self.accessQueue.sync {
                element = self.array[index]
            }
            return element
        }
    }
    
    func push(_ newElement: T) {
        self.append(newElement)
    }
    func pop() -> T? {
        return self.removeLast()
    }
    func peekAtStack() -> T? {
        return self.last
    }
    func enqueue(_ newElement: T) {
        self.append(newElement)
    }
    func dequeue() -> T? {
        if count>0 {
            return self.remove(at: 0)
        } else {
            return nil
        }
    }
    func peekAtQueue() -> T? {
        return self.first
    }
}

public class SynchronizedDictionnary<TK:Hashable, TV> : Collection {
    private let accessQueue: DispatchQueue = DispatchQueue(
        label: "SynchronizedDictionaryAccess", qos: .userInteractive, attributes: .concurrent)
    private var dictionary: [TK: TV]
    
    var keys: Dictionary<TK, TV>.Keys {
        self.accessQueue.sync {
            return self.dictionary.keys
        }
    }
    
    var values: Dictionary<TK, TV>.Values {
        self.accessQueue.sync {
            return self.dictionary.values
        }
    }
    
    public var startIndex: Dictionary<TK, TV>.Index {
        self.accessQueue.sync {
            return self.dictionary.startIndex
        }
    }
    
    public var endIndex: Dictionary<TK, TV>.Index {
        self.accessQueue.sync {
            return self.dictionary.endIndex
        }
    }
    
    init(dict: [TK: TV] = [TK:TV]()) {
        self.dictionary = dict
    }
    public func removeAll() {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary.removeAll()
        }
    }
    public func removeValue(forKey: TK) {
        accessQueue.async(flags:.barrier) { [weak self] in
            self?.dictionary.removeValue(forKey: forKey)
        }
    }
    public subscript(index: Dictionary<TK, TV>.Index) -> Dictionary<TK, TV>.Element {
        self.accessQueue.sync {
            return self.dictionary[index]
        }
    }
    public subscript(@Sendable key: TK) -> TV? {
        set {
            accessQueue.async(flags: .barrier) {
                self.dictionary[key] = newValue
            }
        }
        get {
            var element: TV!
            accessQueue.sync {
                element = dictionary[key]
            }
            return element
        }
    }
    public var count: Int {
        var count = 0
        accessQueue.sync {
            count = dictionary.count
        }
        return count
    }
    public var isEmpty: Bool {
        var empty = true
        accessQueue.sync {
            empty = dictionary.isEmpty
        }
        return empty
    }
    public var capacity: Int {
        var capacity = 0
        accessQueue.sync {
            capacity = dictionary.capacity
        }
        return capacity
    }
    public var _dictionary: [TK: TV] {
        var dico = [TK: TV]()
        accessQueue.sync {
            dico = dictionary
        }
        return dico
    }
    public func has(key:TK) -> Bool {
        var r = false
        accessQueue.sync {
            r = dictionary.has(key: key)
        }
        return r
    }
    
    // this is because it is an apple protocol method
    // swiftlint:disable identifier_name
    public func index(after i: Dictionary<TK, TV>.Index) -> Dictionary<TK, TV>.Index {
        self.accessQueue.sync {
            return self.dictionary.index(after: i)
        }
    }
    // swiftlint:enable identifier_name
    
    
    
    /*
     public func append(newElement: T) {
     dictionary.
     self.accessQueue.async(flags:.barrier) {
     self.array.append(newElement)
     }
     }
     
     public func removeAtIndex(index: Int) {
     self.accessQueue.async(flags:.barrier) {
     self.array.remove(at: index)
     }
     }
     
     public var count: Int {
     var count = 0
     self.accessQueue.sync {
     count = self.array.count
     }
     return count
     }
     
     public func first() -> T? {
     var element: T?
     self.accessQueue.sync {
     if !self.array.isEmpty {
     element = self.array[0]·
     }
     }
     return element
     }
     */
}
