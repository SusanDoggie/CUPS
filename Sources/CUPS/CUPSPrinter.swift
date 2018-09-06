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
        
        guard let uri = uri ?? deviceUri else { return try callback(nil) }
        
        guard let request = ippNewRequest(IPP_OP_GET_PRINTER_ATTRIBUTES) else { return try callback(nil) }
        
        ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI, "printer-uri", nil, uri.absoluteString)
        ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME, "requesting-user-name", nil, cupsUser())
        
        guard let response = cupsDoRequest(nil, request, uri.path) else { return try callback(nil) }
        defer { ippDelete(response) }
        
        guard let _attr = ippFindAttribute(response, attribute, value_tag) else { return try callback(nil) }
        
        return try callback(_attr)
    }
    
    public func fetch(_ attribute: String) -> String? {
        
        return self.fetch(attribute, IPP_TAG_ZERO) { attr in
            
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

extension CUPSPrinter {
    
    public var resolution: [CUPSResolution] {
        
        func _fetch(_ attribute: String) -> [CUPSResolution]? {
            
            return self.fetch(attribute, IPP_TAG_RESOLUTION) { attr in
                
                guard let attr = attr else { return nil }
                
                var resolution: [CUPSResolution] = []
                
                for i in 0..<ippGetCount(attr) {
                    
                    var xres: Int32 = 0
                    var yres: Int32 = 0
                    var units: ipp_res_t = ipp_res_t(rawValue: 0)
                    
                    xres = ippGetResolution(attr, i, &yres, &units)
                    
                    resolution.append(CUPSResolution(xres: UInt32(xres), yres: UInt32(yres), units: units))
                }
                
                return resolution
            }
        }
        
        return _fetch("printer-resolution-supported") ?? _fetch("pwg-raster-document-resolution-supported") ?? []
    }
    
    public var colorTypeSupported: [String] {
        
        return self.fetch("pwg-raster-document-type-supported", IPP_TAG_KEYWORD) { attr in
            
            guard let attr = attr else { return [] }
            
            var typeSupported: [String] = []
            
            for i in 0..<ippGetCount(attr) {
                typeSupported.append(String(cString: ippGetString(attr, i, nil)))
            }
            
            return typeSupported
        }
    }
    
    public var sheetBack: [String] {
        
        return self.fetch("pwg-raster-document-sheet-back", IPP_TAG_KEYWORD) { attr in
            
            guard let attr = attr else { return [] }
            
            var typeSupported: [String] = []
            
            for i in 0..<ippGetCount(attr) {
                typeSupported.append(String(cString: ippGetString(attr, i, nil)))
            }
            
            return typeSupported
        }
    }
}

extension CUPSPrinter {
    
    public var documentFormatDefault: String? {
        return self.fetch("document-format-default")
    }
    
    public var documentFormatSupported: String? {
        return self.fetch("document-format-supported")
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

extension CUPSPrinter {
    
    public var _attributes: [String: String] {
        
        let attrs = [
            "auth-info-required",
            "charset-configured",
            "charset-supported",
            "color-supported",
            "compression-supported",
            "device-service-count",
            "device-uri",
            "device-uuid",
            "document-charset-default",
            "document-charset-supported",
            "document-creation-attributes-supported",
            "document-digital-signature-default",
            "document-digital-signature-supported",
            "document-format-default",
            "document-format-details-default",
            "document-format-details-supported",
            "document-format-supported",
            "document-format-varying-attributes",
            "document-format-version-default",
            "document-format-version-supported",
            "document-natural-language-default",
            "document-natural-language-supported",
            "document-password-supported",
            "generated-natural-language-supported",
            "identify-actions-default",
            "identify-actions-supported",
            "input-source-supported",
            "ipp-features-supported",
            "ipp-versions-supported",
            "ippget-event-life",
            "job-authorization-uri-supported",
            "job-constraints-supported",
            "job-creation-attributes-supported",
            "job-finishings-col-ready",
            "job-finishings-ready",
            "job-ids-supported",
            "job-impressions-supported",
            "job-k-limit",
            "job-k-octets-supported",
            "job-media-sheets-supported",
            "job-page-limit",
            "job-password-encryption-supported",
            "job-password-supported",
            "job-quota-period",
            "job-resolvers-supported",
            "job-settable-attributes-supported",
            "job-spooling-supported",
            "jpeg-k-octets-supported",
            "jpeg-x-dimension-supported",
            "jpeg-y-dimension-supported",
            "landscape-orientation-requested-preferred",
            "marker-change-time",
            "marker-colors",
            "marker-high-levels",
            "marker-levels",
            "marker-low-levels",
            "marker-message",
            "marker-names",
            "marker-types",
            "media-col-ready",
            "media-ready",
            "member-names",
            "member-uris",
            "multiple-destination-uris-supported",
            "multiple-document-jobs-supported",
            "multiple-operation-time-out",
            "multiple-operation-time-out-action",
            "natural-language-configured",
            "operations-supported",
            "pages-per-minute",
            "pages-per-minute-color",
            "pdf-k-octets-supported",
            "pdf-versions-supported",
            "pdl-override-supported",
            "port-monitor",
            "port-monitor-supported",
            "preferred-attributes-supported",
            "printer-alert",
            "printer-alert-description",
            "printer-charge-info",
            "printer-charge-info-uri",
            "printer-commands",
            "printer-current-time",
            "printer-detailed-status-messages",
            "printer-device-id",
            "printer-dns-sd-name",
            "printer-driver-installer",
            "printer-fax-log-uri",
            "printer-fax-modem-info",
            "printer-fax-modem-name",
            "printer-fax-modem-number",
            "printer-firmware-name",
            "printer-firmware-patches",
            "printer-firmware-string-version",
            "printer-firmware-version",
            "printer-geo-location",
            "printer-get-attributes-supported",
            "printer-icc-profiles",
            "printer-icons",
            "printer-info",
            "printer-input-tray",
            "printer-is-accepting-jobs",
            "printer-is-shared",
            "printer-kind",
            "printer-location",
            "printer-make-and-model",
            "printer-mandatory-job-attributes",
            "printer-message-date-time",
            "printer-message-from-operator",
            "printer-message-time",
            "printer-more-info",
            "printer-more-info-manufacturer",
            "printer-name",
            "printer-native-formats",
            "printer-organization",
            "printer-organizational-unit",
            "printer-output-tray",
            "printer-settable-attributes-supported",
            "printer-state",
            "printer-state-change-date-time",
            "printer-state-change-time",
            "printer-state-message",
            "printer-state-reasons",
            "printer-supply",
            "printer-supply-description",
            "printer-supply-info-uri",
            "printer-type",
            "printer-up-time",
            "printer-uri-supported",
            "printer-uuid",
            "printer-xri-supported",
            "pwg-raster-document-resolution-supported",
            "pwg-raster-document-sheet-back",
            "pwg-raster-document-type-supported",
            "queued-job-count",
            "reference-uri-schemes-supported",
            "repertoire-supported",
            "requesting-user-name-allowed",
            "requesting-user-name-denied",
            "requesting-user-uri-supported",
            "subordinate-printers-supported",
            "urf-supported",
            "uri-authentication-supported",
            "uri-security-supported",
            "user-defined-value-supported",
            "which-jobs-supported",
            "xri-authentication-supported",
            "xri-security-supported",
            "xri-uri-scheme-supported",
            ]
        
        var attributes: [String: String] = [:]
        
        for attr in attrs {
            attributes[attr] = self.fetch(attr)
        }
        
        return attributes
    }
}
