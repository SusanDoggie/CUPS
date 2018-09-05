//
//  CUPSDest.swift
//
//  The MIT License
//  Copyright (c) 2015 - 2018 Susan Cheng. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

public struct CUPSDest {
    
    public let name: String
    public let instance: String?
    
    init(_ dest: cups_dest_t) {
        self.name = dest.name.map { String(cString: $0) } ?? ""
        self.instance = dest.instance.map { String(cString: $0) }
    }
}

extension CUPSDest {
    
    public static var dests: [CUPSDest] {
        
        var dests: UnsafeMutablePointer<cups_dest_t>?
        let num_dests = cupsGetDests(&dests)
        
        let _dests = UnsafeBufferPointer(start: dests, count: Int(num_dests)).map(CUPSDest.init)
        
        cupsFreeDests(num_dests, dests)
        
        return _dests
    }
    
    func withUnsafeDestPointer<Result>(callback: (UnsafePointer<cups_dest_t>?) throws -> Result) rethrows -> Result {
        var dests: UnsafeMutablePointer<cups_dest_t>?
        let num_dests = cupsGetDests(&dests)
        defer { cupsFreeDests(num_dests, dests) }
        return try callback(cupsGetDest(self.name, self.instance, num_dests, dests))
    }
    
    func withUnsafeDestInfoPointer<Result>(callback: (UnsafePointer<cups_dest_t>?, OpaquePointer?) throws -> Result) rethrows -> Result {
        return try self.withUnsafeDestPointer { dest in
            if let dest = UnsafeMutablePointer(mutating: dest), let info = cupsCopyDestInfo(nil, dest) {
                defer { cupsFreeDestInfo(info) }
                return try callback(dest, info)
            } else {
                return try callback(nil, nil)
            }
        }
    }
}

extension CUPSDest {
    
    public var isDefault: Bool {
        return self.withUnsafeDestPointer { !($0?.pointee.is_default == 0) }
    }
    
    public var attributes: [String: String] {
        
        return self.withUnsafeDestPointer { dest in
            
            guard let dest = dest else { return [:] }
            
            var attributes: [String: String] = [:]
            
            if let options = dest.pointee.options {
                for i in 0..<dest.pointee.num_options {
                    let option = options[Int(i)]
                    attributes[String(cString: option.name)] = String(cString: option.value)
                }
            }
            
            return attributes
        }
    }
}

extension CUPSDest {
    
    public var media: [CUPSMedia] {
        
        return self.withUnsafeDestInfoPointer { dest, info in
            
            guard let dest = UnsafeMutablePointer(mutating: dest), let info = info else { return [] }
            
            let count = cupsGetDestMediaCount(nil, dest, info, 0)
            
            var media: [CUPSMedia] = []
            media.reserveCapacity(Int(count))
            
            for index in 0..<count {
                var size = cups_size_t()
                cupsGetDestMediaByIndex(nil, dest, info, index, 0, &size)
                media.append(CUPSMedia(size))
            }
            
            return media
        }
    }
    
    public var defaultMedia: CUPSMedia? {
        
        return self.withUnsafeDestInfoPointer { dest, info in
            guard let dest = UnsafeMutablePointer(mutating: dest), let info = info else { return nil }
            var size = cups_size_t()
            guard cupsGetDestMediaDefault(nil, dest, info, 0, &size) == 1 else { return nil }
            return CUPSMedia(size)
        }
    }
}

extension CUPSDest {
    
    public var info: String {
        return attributes["printer-info"] ?? ""
    }
    
    public var model: String? {
        return attributes["printer-make-and-model"]
    }
    
    public var uri: URL? {
        return attributes["printer-uri-supported"].flatMap { URL(string: $0) }
    }
    
    public var deviceUri: URL? {
        return attributes["device-uri"].flatMap { URL(string: $0) }
    }
}

extension CUPSDest {
    
    public var state: String? {
        return attributes["printer-state"]
    }
    
    public var stateReasons: String? {
        return attributes["printer-state-reasons"]
    }
    
    public var isShared: Bool? {
        guard let bool = attributes["printer-is-shared"] else { return nil }
        switch bool {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
    
    public var isTemporary: Bool? {
        guard let bool = attributes["printer-is-temporary"] else { return nil }
        switch bool {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
    
    public var isAcceptingJobs: Bool? {
        guard let bool = attributes["printer-is-accepting-jobs"] else { return nil }
        switch bool {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
    
    public var stateUpdateTime: Date? {
        guard let time = attributes["printer-state-change-time"].flatMap(TimeInterval.init) else { return nil }
        return Date(timeIntervalSince1970: time)
    }
}

extension CUPSDest {
    
    public var markerLevels: String? {
        return attributes["marker-levels"]
    }
    
    public var markerHighLevels: String? {
        return attributes["marker-high-levels"]
    }
    
    public var markerLowLevels: String? {
        return attributes["marker-low-levels"]
    }
    
    public var markerColors: String? {
        return attributes["marker-colors"]
    }
    
    public var markerNames: String? {
        return attributes["marker-names"]
    }
    
    public var markerTypes: String? {
        return attributes["marker-types"]
    }
    
    public var markerUpdateTime: Date? {
        guard let time = attributes["marker-change-time"].flatMap(TimeInterval.init) else { return nil }
        return Date(timeIntervalSince1970: time)
    }
}
