//
//  CUPSPage.swift
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

public struct CUPSPage {
    
    public var header: cups_page_header2_t
    
    public init?(_ media: UnsafePointer<pwg_media_t>, _ type: UnsafePointer<Int8>, _ xdpi: UInt32, _ ydpi: UInt32, _ sides: UnsafePointer<Int8>?, _ sheet_back: UnsafePointer<Int8>?) {
        self.header = cups_page_header2_t()
        guard cupsRasterInitPWGHeader(&header, UnsafeMutablePointer(mutating: media), type, Int32(xdpi), Int32(ydpi), sides, sheet_back) != 0 else { return nil }
    }
    
    public init?(_ media: CUPSMedia, _ type: UnsafePointer<Int8>, _ xdpi: UInt32, _ ydpi: UInt32, _ sides: UnsafePointer<Int8>?, _ sheet_back: UnsafePointer<Int8>?) {
        guard let page = media.withUnsafePwgMediaPointer(callback: { $0.flatMap { CUPSPage($0, type, xdpi, ydpi, sides, sheet_back) } }) else { return nil }
        self = page
        self.header.Margins.0 = 72 * UInt32(media.left) / 2540
        self.header.Margins.1 = 72 * UInt32(media.bottom) / 2540
        self.header.cupsWidth = UInt32(media.width - media.left - media.right) * xdpi / 2540
        self.header.cupsHeight = UInt32(media.height - media.top - media.bottom) * ydpi / 2540
        self.header.ImagingBoundingBox.0 = 72 * UInt32(media.left) / 2540
        self.header.ImagingBoundingBox.1 = 72 * UInt32(media.bottom) / 2540
        self.header.ImagingBoundingBox.2 = 72 * UInt32(media.width - media.left - media.right) / 2540
        self.header.ImagingBoundingBox.3 = 72 * UInt32(media.height - media.top - media.bottom) / 2540
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
    
    public func write(_ fd: Int32, _ bytes: UnsafeRawBufferPointer) -> Bool {
        
        guard let raster = cupsRasterOpen(fd, CUPS_RASTER_WRITE_COMPRESSED) else { return false }
        defer { cupsRasterClose(raster) }
        
        var header = self.header
        guard cupsRasterWriteHeader2(raster, &header) == 1 else { return false }
        
        var bytes = bytes
        while bytes.count != 0 {
            let written = cupsRasterWritePixels(raster, UnsafeMutablePointer(mutating: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)), UInt32(bytes.count))
            bytes = UnsafeRawBufferPointer(rebasing: bytes.dropFirst(Int(written)))
        }
        
        return true
    }
}

extension CUPSPage {
    
    public static let type_adobe_rgb_8 = "adobe-rgb_8"
    public static let type_adobe_rgb_16 = "adobe-rgb_16"
    public static let type_black_1 = "black_1"
    public static let type_black_8 = "black_8"
    public static let type_black_16 = "black_16"
    public static let type_cmyk_8 = "cmyk_8"
    public static let type_cmyk_16 = "cmyk_16"
    public static let type_rgb_8 = "rgb_8"
    public static let type_rgb_16 = "rgb_16"
    public static let type_sgray_1 = "sgray_1"
    public static let type_sgray_8 = "sgray_8"
    public static let type_sgray_16 = "sgray_16"
    public static let type_srgb_8 = "srgb_8"
    public static let type_srgb_16 = "srgb_16"
    
    public static let type_device1_8 = "device1_8"
    public static let type_device2_8 = "device2_8"
    public static let type_device3_8 = "device3_8"
    public static let type_device4_8 = "device4_8"
    public static let type_device5_8 = "device5_8"
    public static let type_device6_8 = "device6_8"
    public static let type_device7_8 = "device7_8"
    public static let type_device8_8 = "device8_8"
    public static let type_device9_8 = "device9_8"
    public static let type_device10_8 = "device10_8"
    public static let type_device11_8 = "device11_8"
    public static let type_device12_8 = "device12_8"
    public static let type_device13_8 = "device13_8"
    public static let type_device14_8 = "device14_8"
    public static let type_device15_8 = "device15_8"
    
    public static let type_device1_16 = "device1_16"
    public static let type_device2_16 = "device2_16"
    public static let type_device3_16 = "device3_16"
    public static let type_device4_16 = "device4_16"
    public static let type_device5_16 = "device5_16"
    public static let type_device6_16 = "device6_16"
    public static let type_device7_16 = "device7_16"
    public static let type_device8_16 = "device8_16"
    public static let type_device9_16 = "device9_16"
    public static let type_device10_16 = "device10_16"
    public static let type_device11_16 = "device11_16"
    public static let type_device12_16 = "device12_16"
    public static let type_device13_16 = "device13_16"
    public static let type_device14_16 = "device14_16"
    public static let type_device15_16 = "device15_16"
    
}

extension CUPSPage {
    
    public static let sides_two_sided_long_edge = "two-sided-long-edge"
    public static let sides_two_sided_short_edge = "two-sided-short-edge"
    public static let sides_one_sided = "one-sided"
    
}

extension CUPSPage {
    
    public static let sheet_back_flipped = "flipped"
    public static let sheet_back_manual_tumble = "manual-tumble"
    public static let sheet_back_rotated = "rotated"
    public static let sheet_back_normal = "normal"
    
}
