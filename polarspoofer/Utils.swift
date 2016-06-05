//
//  Utils.swift
//  polarspoofer
//
//  Created by Adam Kuczyński on 05.06.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

func hex(data: [UInt8]) -> String {
    var result = "["
    
    data.forEach({body in
        result += String(format: "0x%02X,", body)
    })
    
    return result + "]"
}

func d2a(data: NSData) -> [UInt8] {
    var result = [UInt8](count: data.length, repeatedValue: 0)
    data.getBytes(&result, length: data.length)
    return result
}

func a2d(array: [UInt8]) -> NSData {
    return NSData(bytes: array, length: array.count)
}

func readFile(path: String) -> [UInt8] {
    return d2a(NSData(contentsOfFile: path)!)
}

func readDirectory(path: String) -> [UInt8] {
    let manager = NSFileManager.defaultManager()
    var entries = Array<Directory.Entry>()
    
    for file in try! manager.contentsOfDirectoryAtPath(path) {
        let attr = try! manager.attributesOfItemAtPath(path + file)
        let type = attr[NSFileType]! as! String
        let size = attr[NSFileSize]! as! Int
        var name = file
        
        if type == NSFileTypeDirectory {
            name += "/"
        }
        
        entries.append(try! Directory.Entry.Builder().setPath(name).setSize(UInt32(size)).build())
    }
    
    return d2a(try! Directory.Builder().setEntries(entries).build().data())
}

func decode(message: [UInt8]) -> [UInt8] {
    var i = 0, j = 0
    return [] + message.filter { _ in return i++ % 20 != 0 }.filter { _ in return j++ % 300 > 2 }.dropLast()
}

func encode(message: [UInt8]) -> [UInt8] {
    let zeroed = message + [0x00]
    let parts = encodeParts(zeroed)
    var result = [UInt8]()
    
    for part in parts {
        for packet in encodePackets(part, last: parts.last! == part) {
            result += packet
        }
    }
    
    return result
}

func encodeParts(message: [UInt8]) -> [[UInt8]] {
    var result = [[UInt8]]()
    var left = message
    
    while left.count > 0 {
        let remove = left.count > 301 ? 301 : left.count
        result.append([0x00, 0x00, 0x00] + left[0...remove-1])
        left.removeFirst(remove)
    }
    
    return result
}

func encodePackets(part: [UInt8], last: Bool) -> [[UInt8]] {
    var result = [[UInt8]]()
    var left = part
    
    var packet : UInt8 = 0
    let packets = UInt8(ceil(Double(part.count) / 19.0))
    
    while left.count > 0 {
        let remove = left.count > 19 ? 19 : left.count
        let header : UInt8 = (packets - ++packet) << 4 + (!last || left.count > 19 ? 9 : 0)
        result.append([header] + left[0...remove-1])
        left.removeFirst(remove)
    }
    
    return result
}