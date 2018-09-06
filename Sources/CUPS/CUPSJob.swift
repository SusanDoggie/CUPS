//
//  CUPSJob.swift
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

public struct CUPSJob {
    
    public let dest: CUPSPrinter
    public let id: Int32
    
    init(dest: CUPSPrinter, id: Int32) {
        self.dest = dest
        self.id = id
    }
}

extension CUPSJob {
    
    func withCupsJob<Result>(callback: (cups_job_t?) throws -> Result) rethrows -> Result {
        
        var jobs: UnsafeMutablePointer<cups_job_t>?
        let num_jobs = cupsGetJobs(&jobs, dest.name, 1, CUPS_WHICHJOBS_ALL)
        defer { cupsFreeJobs(num_jobs, jobs) }
        
        for index in 0..<Int(num_jobs) {
            if let job = jobs?[index], job.id == self.id {
                return try callback(job)
            }
        }
        
        return try callback(nil)
    }
}

extension CUPSJob {
    
    public var title: String {
        return self.withCupsJob { ($0?.title).map { String(cString: $0) } } ?? ""
    }
    
    public var format: String {
        return self.withCupsJob { ($0?.format).map { String(cString: $0) } } ?? ""
    }
    
    public var state: ipp_jstate_t? {
        return self.withCupsJob { $0?.state }
    }
    
    public var priority: Int32? {
        return self.withCupsJob { $0?.priority }
    }
    
    public var completedTime: Date? {
        return self.withCupsJob { ($0?.completed_time).map { Date(timeIntervalSince1970: TimeInterval($0)) } }
    }
    
    public var creationTime: Date? {
        return self.withCupsJob { ($0?.creation_time).map { Date(timeIntervalSince1970: TimeInterval($0)) } }
    }
    
    public var processingTime: Date? {
        return self.withCupsJob { ($0?.processing_time).map { Date(timeIntervalSince1970: TimeInterval($0)) } }
    }
}

extension CUPSJob {
    
    @discardableResult
    public func cancel() -> Bool {
        return cupsCancelJob(dest.name, id) == 1
    }
}
