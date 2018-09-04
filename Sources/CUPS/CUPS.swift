//
//  CUPS.swift
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
import ccups

public struct CUPSDest {
    
    public let name: String
    public let instance: String?
    public let is_default: Bool
    public let attributes: [String: String]
    
    init(_ dest: cups_dest_t) {
        
        self.name = dest.name.map { String(cString: $0) } ?? ""
        self.instance = dest.instance.map { String(cString: $0) }
        self.is_default = dest.is_default != 0
        
        var _attributes: [String: String] = [:]
        
        if let options = dest.options {
            for i in 0..<dest.num_options {
                let option = options[Int(i)]
                _attributes[String(cString: option.name)] = String(cString: option.value)
            }
        }
        
        self.attributes = _attributes
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

public struct CUPSPage {
    
    public var header: cups_page_header2_t
    
    init?(_ media: UnsafePointer<pwg_media_t>, _ type: UnsafePointer<Int8>, _ xdpi: Int32, _ ydpi: Int32, _ sides: UnsafePointer<Int8>?, _ sheet_back: UnsafePointer<Int8>?) {
        self.header = cups_page_header2_t()
        guard cupsRasterInitPWGHeader(&header, UnsafeMutablePointer(mutating: media), type, xdpi, ydpi, sides, sheet_back) != 0 else { return nil }
    }
}
