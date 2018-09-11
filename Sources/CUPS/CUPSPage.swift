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
    
    public var data: Data = Data()
    
    public init?(_ media: CUPSMedia, _ colorSpace: cups_cspace_t, _ bitsPerColor: UInt8, _ xdpi: UInt32, _ ydpi: UInt32, _ sides: String?, _ sheet_back: String?) {
        
        self.header = cups_page_header2_t()
        
        guard let pwgMedia = pwgMediaForSize(media.width, media.height) else { return nil }
        
        withUnsafeMutableBytes(of: &self.header.cupsPageSizeName) { _ = strlcpy($0.baseAddress?.assumingMemoryBound(to: Int8.self), pwgMedia.pointee.pwg, $0.count) }
        
        switch bitsPerColor {
        case 1:
            switch colorSpace {
            case CUPS_CSPACE_K:     self.header.cupsNumColors = 1
            case CUPS_CSPACE_SW:    self.header.cupsNumColors = 1
            default: return nil
            }
        case 8, 16:
            switch colorSpace {
            case CUPS_CSPACE_K:         self.header.cupsNumColors = 1
            case CUPS_CSPACE_SW:        self.header.cupsNumColors = 1
            case CUPS_CSPACE_SRGB:      self.header.cupsNumColors = 3
            case CUPS_CSPACE_ADOBERGB:  self.header.cupsNumColors = 3
            case CUPS_CSPACE_RGB:       self.header.cupsNumColors = 3
            case CUPS_CSPACE_CMYK:      self.header.cupsNumColors = 4
            case CUPS_CSPACE_DEVICE1:   self.header.cupsNumColors = 1
            case CUPS_CSPACE_DEVICE2:   self.header.cupsNumColors = 2
            case CUPS_CSPACE_DEVICE3:   self.header.cupsNumColors = 3
            case CUPS_CSPACE_DEVICE4:   self.header.cupsNumColors = 4
            case CUPS_CSPACE_DEVICE5:   self.header.cupsNumColors = 5
            case CUPS_CSPACE_DEVICE6:   self.header.cupsNumColors = 6
            case CUPS_CSPACE_DEVICE7:   self.header.cupsNumColors = 7
            case CUPS_CSPACE_DEVICE8:   self.header.cupsNumColors = 8
            case CUPS_CSPACE_DEVICE9:   self.header.cupsNumColors = 9
            case CUPS_CSPACE_DEVICEA:   self.header.cupsNumColors = 10
            case CUPS_CSPACE_DEVICEB:   self.header.cupsNumColors = 11
            case CUPS_CSPACE_DEVICEC:   self.header.cupsNumColors = 12
            case CUPS_CSPACE_DEVICED:   self.header.cupsNumColors = 13
            case CUPS_CSPACE_DEVICEE:   self.header.cupsNumColors = 14
            case CUPS_CSPACE_DEVICEF:   self.header.cupsNumColors = 15
            default: return nil
            }
        default: return nil
        }
        
        self.header.HWResolution.0          = xdpi
        self.header.HWResolution.1          = ydpi
        self.header.cupsColorSpace          = colorSpace
        self.header.cupsBitsPerColor        = UInt32(bitsPerColor)
        self.header.cupsColorOrder          = CUPS_ORDER_CHUNKED
        self.header.PageSize.0              = 72 * UInt32(media.width) / 2540
        self.header.PageSize.1              = 72 * UInt32(media.height) / 2540
        self.header.cupsPageSize.0          = 72.0 * Float(media.width) / 2540.0
        self.header.cupsPageSize.1          = 72.0 * Float(media.height) / 2540.0
        self.header.Margins.0               = 72 * UInt32(media.left) / 2540
        self.header.Margins.1               = 72 * UInt32(media.bottom) / 2540
        self.header.ImagingBoundingBox.0    = self.header.Margins.0
        self.header.ImagingBoundingBox.1    = self.header.Margins.1
        self.header.ImagingBoundingBox.2    = 72 * UInt32(media.width - media.right) / 2540
        self.header.ImagingBoundingBox.3    = 72 * UInt32(media.height - media.top) / 2540
        self.header.cupsWidth               = UInt32(media.width - media.left - media.right) * xdpi / 2540
        self.header.cupsHeight              = UInt32(media.height - media.top - media.bottom) * ydpi / 2540
        self.header.cupsBitsPerPixel        = self.header.cupsBitsPerColor * self.header.cupsNumColors
        self.header.cupsBytesPerLine        = (self.header.cupsWidth * self.header.cupsBitsPerPixel + 7) / 8
        
        self.header.cupsInteger.1 = 1
        self.header.cupsInteger.2 = 1
        
        if let sides = sides {
            
            switch sides {
            case "two-sided-long-edge": self.header.Duplex = CUPS_TRUE
            case "two-sided-short-edge":
                
                self.header.Duplex = CUPS_TRUE
                self.header.Tumble = CUPS_TRUE
                
            case "one-sided": break
            default: return nil
            }
            
            if let sheet_back = sheet_back {
                
                switch sheet_back {
                case "flipped":
                    if self.header.Tumble == CUPS_TRUE {
                        self.header.cupsInteger.1 = 0xffffffff
                    } else {
                        self.header.cupsInteger.2 = 0xffffffff
                    }
                case "manual-tumble":
                    if self.header.Tumble == CUPS_TRUE {
                        self.header.cupsInteger.1 = 0xffffffff
                        self.header.cupsInteger.2 = 0xffffffff
                    }
                case "rotated":
                    if self.header.Tumble == CUPS_FALSE {
                        self.header.cupsInteger.1 = 0xffffffff
                        self.header.cupsInteger.2 = 0xffffffff
                    }
                case "normal": break
                default: return nil
                }
            }
        }
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
    
    @discardableResult
    public func write(_ fd: Int32) -> Bool {
        
        guard let raster = cupsRasterOpen(fd, CUPS_RASTER_WRITE_COMPRESSED) else { return false }
        defer { cupsRasterClose(raster) }
        
        var header = self.header
        guard cupsRasterWriteHeader2(raster, &header) == 1 else { return false }
        
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            var bytes = bytes
            var remain = UInt32(data.count)
            while remain > 0 {
                let written = cupsRasterWritePixels(raster, UnsafeMutablePointer(mutating: bytes), remain)
                bytes += Int(written)
                remain -= written
            }
        }
        
        return true
    }
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
