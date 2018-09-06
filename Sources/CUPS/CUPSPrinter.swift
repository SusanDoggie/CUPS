//
//  CUPSPrinter.swift
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

public struct CUPSPrinter {
    
    public let name: String
    public let instance: String?
    
    init(_ dest: cups_dest_t) {
        self.name = dest.name.map { String(cString: $0) } ?? ""
        self.instance = dest.instance.map { String(cString: $0) }
    }
}

extension CUPSPrinter {
    
    public static var printers: [CUPSPrinter] {
        
        var dests: UnsafeMutablePointer<cups_dest_t>?
        let num_dests = cupsGetDests(&dests)
        
        let _dests = UnsafeBufferPointer(start: dests, count: Int(num_dests)).map(CUPSPrinter.init)
        
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

extension CUPSPrinter {
    
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

extension CUPSPrinter {
    
    public var media: [CUPSMedia] {
        
        return self.withUnsafeDestInfoPointer { dest, info in
            
            guard let dest = UnsafeMutablePointer(mutating: dest), let info = info else { return [] }
            
            let count = cupsGetDestMediaCount(nil, dest, info, UInt32(CUPS_MEDIA_FLAGS_DEFAULT))
            
            var media: [CUPSMedia] = []
            media.reserveCapacity(Int(count))
            
            for index in 0..<count {
                var size = cups_size_t()
                cupsGetDestMediaByIndex(nil, dest, info, index, UInt32(CUPS_MEDIA_FLAGS_DEFAULT), &size)
                media.append(CUPSMedia(size))
            }
            
            return media
        }
    }
    
    public var defaultMedia: CUPSMedia? {
        
        return self.withUnsafeDestInfoPointer { dest, info in
            guard let dest = UnsafeMutablePointer(mutating: dest), let info = info else { return nil }
            var size = cups_size_t()
            guard cupsGetDestMediaDefault(nil, dest, info, UInt32(CUPS_MEDIA_FLAGS_DEFAULT), &size) == 1 else { return nil }
            return CUPSMedia(size)
        }
    }
}

extension CUPSPrinter {
    
    public func fetch<Result>(_ attribute: String, _ value_tag: ipp_tag_t, callback: (OpaquePointer?) throws -> Result) rethrows -> Result {
        
        guard let uri = uri else { return try callback(nil) }
        
        guard let request = ippNewRequest(IPP_OP_GET_PRINTER_ATTRIBUTES) else { return try callback(nil) }
        
        ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI, "printer-uri", nil, uri.absoluteString)
        ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME, "requesting-user-name", nil, cupsUser())
        
        guard let response = cupsDoRequest(nil, request, uri.path) else { return try callback(nil) }
        defer { ippDelete(response) }
        
        guard let _attr = ippFindAttribute(response, attribute, value_tag) else { return try callback(nil) }
        
        return try callback(_attr)
    }
}

extension CUPSPrinter {
    
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

extension CUPSPrinter {
    
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

extension CUPSPrinter {
    
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

public struct CUPSResolution {
    
    public var xdpi: Int32
    public var ydpi: Int32
    public var units: ipp_res_t
}

extension CUPSPrinter {
    
    public var resolution: [CUPSResolution] {
        
        return self.fetch("pwg-raster-document-resolution-supported", IPP_TAG_RESOLUTION) { attr in
            
            guard let attr = attr else { return [] }
            
            var resolution: [CUPSResolution] = []
            
            for i in 0..<ippGetCount(attr) {
                
                var xdpi: Int32 = 0
                var ydpi: Int32 = 0
                var units: ipp_res_t = ipp_res_t(rawValue: 0)
                
                xdpi = ippGetResolution(attr, i, &ydpi, &units)
                
                resolution.append(CUPSResolution(xdpi: xdpi, ydpi: ydpi, units: units))
            }
            
            return resolution
        }
    }
    
    public var typeSupported: String? {
        
        return self.fetch("pwg-raster-document-type-supported", IPP_TAG_KEYWORD) { attr in
            
            guard let attr = attr else { return nil }
            
            var buffer = [Int8](repeating: 0, count: ippAttributeString(attr, nil, 0) + 1)
            return buffer.withUnsafeMutableBufferPointer {
                ippAttributeString(attr, $0.baseAddress, $0.count)
                return String(cString: $0.baseAddress!)
            }
        }
    }
}

extension CUPSPrinter {
    
    public func print(title: String, _ files: [String], _ options: [String: String] = [:]) -> CUPSJob? {
        
        var buffer: [UnsafePointer<Int8>?] = []
        
        var num_options: Int32 = 0
        var _options: UnsafeMutablePointer<cups_option_t>?
        
        for (key, value) in options {
            num_options = cupsAddOption(key, value, num_options, &_options)
        }
        
        func _print(_ index: Int) -> Int32 {
            if index == files.count {
                var buffer = buffer
                return cupsPrintFiles(name, Int32(buffer.count), &buffer, title, num_options, _options)
            } else {
                return files[index].withCString {
                    buffer.append($0)
                    return _print(index + 1)
                }
            }
        }
        
        let job_id = _print(0)
        
        if num_options != 0 {
            cupsFreeOptions(num_options, _options)
        }
        
        return job_id == 0 ? nil : CUPSJob(dest: self, id: job_id)
    }
}
