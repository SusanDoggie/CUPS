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

public struct CUPSMedia {
    
    public var name: String?
    
    public var width: Int32
    public var height: Int32
    
    public var bottom: Int32
    public var left: Int32
    public var right: Int32
    public var top: Int32
    
    init(_ size: cups_size_t) {
        self.name = withUnsafeBytes(of: size.media) { String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self)) }
        self.width = size.width
        self.height = size.length
        self.bottom = size.bottom
        self.left = size.left
        self.right = size.right
        self.top = size.top
    }
    
    public init(name: String?, width: Int32, height: Int32, bottom: Int32, left: Int32, right: Int32, top: Int32) {
        self.name = name
        self.width = width
        self.height = height
        self.bottom = bottom
        self.left = left
        self.right = right
        self.top = top
    }
}

extension CUPSMedia {
    
    func withUnsafePwgMediaPointer<Result>(callback: (UnsafePointer<pwg_media_t>?) throws -> Result) rethrows -> Result {
        return try callback(pwgMediaForSize(width, height))
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

public struct CUPSPage {
    
    public var header: cups_page_header2_t
    
    public init?(_ media: UnsafePointer<pwg_media_t>, _ type: UnsafePointer<Int8>, _ xdpi: Int32, _ ydpi: Int32, _ sides: UnsafePointer<Int8>?, _ sheet_back: UnsafePointer<Int8>?) {
        self.header = cups_page_header2_t()
        guard cupsRasterInitPWGHeader(&header, UnsafeMutablePointer(mutating: media), type, xdpi, ydpi, sides, sheet_back) != 0 else { return nil }
    }
    
    public init?(_ media: CUPSMedia, _ type: UnsafePointer<Int8>, _ xdpi: Int32, _ ydpi: Int32, _ sides: UnsafePointer<Int8>?, _ sheet_back: UnsafePointer<Int8>?) {
        guard let page = media.withUnsafePwgMediaPointer(callback: { $0.flatMap { CUPSPage($0, type, xdpi, ydpi, sides, sheet_back) } }) else { return nil }
        self = page
        self.header.Margins.0 = 72 * UInt32(media.left) / 2540
        self.header.Margins.1 = 72 * UInt32(media.bottom) / 2540
        self.header.cupsWidth = UInt32((media.width - media.left - media.right) * xdpi) / 2540
        self.header.cupsHeight = UInt32((media.height - media.top - media.bottom) * ydpi) / 2540
        self.header.cupsBytesPerLine = (self.header.cupsWidth * self.header.cupsBitsPerPixel + 7) / 8
    }
}

extension CUPSPage {
    
    public var numColors: UInt32 {
        return header.cupsNumColors
    }
    
    public var colorOrder: cups_order_t {
        return header.cupsColorOrder
    }
    
    public var bitsPerColor: UInt32 {
        return header.cupsBitsPerColor
    }
    
    public var bitsPerPixel: UInt32 {
        return header.cupsBitsPerPixel
    }
    
    public var bytesPerLine: UInt32 {
        return header.cupsBytesPerLine
    }
}

extension CUPSPage {
    
    public var numCopies: UInt32 {
        get {
            return header.NumCopies
        }
        set {
            header.NumCopies = newValue
        }
    }
}

extension CUPSPage {
    
    public func write(_ fd: Int32, _ bytes: UnsafeRawBufferPointer) {
        guard let address = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
        let raster = cupsRasterOpen(fd, CUPS_RASTER_WRITE)
        var header = self.header
        cupsRasterWriteHeader2(raster, &header)
        cupsRasterWritePixels(raster, UnsafeMutablePointer(mutating: address), UInt32(bytes.count))
        cupsRasterClose(raster)
    }
}

extension CUPSPage {
    
    static let type_adobe_rgb_8 = "adobe-rgb_8"
    static let type_adobe_rgb_16 = "adobe-rgb_16"
    static let type_black_1 = "black_1"
    static let type_black_8 = "black_8"
    static let type_black_16 = "black_16"
    static let type_cmyk_8 = "cmyk_8"
    static let type_cmyk_16 = "cmyk_16"
    static let type_rgb_8 = "rgb_8"
    static let type_rgb_16 = "rgb_16"
    static let type_sgray_1 = "sgray_1"
    static let type_sgray_8 = "sgray_8"
    static let type_sgray_16 = "sgray_16"
    static let type_srgb_8 = "srgb_8"
    static let type_srgb_16 = "srgb_16"
    
    static let type_device1_8 = "device1_8"
    static let type_device2_8 = "device2_8"
    static let type_device3_8 = "device3_8"
    static let type_device4_8 = "device4_8"
    static let type_device5_8 = "device5_8"
    static let type_device6_8 = "device6_8"
    static let type_device7_8 = "device7_8"
    static let type_device8_8 = "device8_8"
    static let type_device9_8 = "device9_8"
    static let type_device10_8 = "device10_8"
    static let type_device11_8 = "device11_8"
    static let type_device12_8 = "device12_8"
    static let type_device13_8 = "device13_8"
    static let type_device14_8 = "device14_8"
    static let type_device15_8 = "device15_8"
    
    static let type_device1_16 = "device1_16"
    static let type_device2_16 = "device2_16"
    static let type_device3_16 = "device3_16"
    static let type_device4_16 = "device4_16"
    static let type_device5_16 = "device5_16"
    static let type_device6_16 = "device6_16"
    static let type_device7_16 = "device7_16"
    static let type_device8_16 = "device8_16"
    static let type_device9_16 = "device9_16"
    static let type_device10_16 = "device10_16"
    static let type_device11_16 = "device11_16"
    static let type_device12_16 = "device12_16"
    static let type_device13_16 = "device13_16"
    static let type_device14_16 = "device14_16"
    static let type_device15_16 = "device15_16"
    
}

extension CUPSPage {
    
    static let sides_two_sided_long_edge = "two-sided-long-edge"
    static let sides_two_sided_short_edge = "two-sided-short-edge"
    static let sides_one_sided = "one-sided"
    
}

extension CUPSPage {
    
    static let sheet_back_flipped = "flipped"
    static let sheet_back_manual_tumble = "manual-tumble"
    static let sheet_back_rotated = "rotated"
    static let sheet_back_normal = "normal"
    
}
