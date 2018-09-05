//
//  CUPSMedia.swift
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
