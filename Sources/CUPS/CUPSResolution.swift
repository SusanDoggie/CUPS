//
//  CUPSResolution.swift
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

public struct CUPSResolution {
    
    public var xres: UInt32
    public var yres: UInt32
    public var units: ipp_res_t
    
    public init(xdpi: UInt32, ydpi: UInt32) {
        self.xres = xdpi
        self.yres = ydpi
        self.units = IPP_RES_PER_INCH
    }
    
    public init(xres: UInt32, yres: UInt32, units: ipp_res_t) {
        self.xres = xres
        self.yres = yres
        self.units = units
    }
}

extension CUPSResolution {
    
    public var xdpi: UInt32 {
        switch units {
        case IPP_RES_PER_CM: return 254 * xres / 100
        case IPP_RES_PER_INCH: return xres
        default: return 0
        }
    }
    
    public var ydpi: UInt32 {
        switch units {
        case IPP_RES_PER_CM: return 254 * yres / 100
        case IPP_RES_PER_INCH: return yres
        default: return 0
        }
    }
}
