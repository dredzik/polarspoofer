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

func hex20(data: [UInt8]) -> String {
    var result = ""
    
    var left = data
    while left.count > 0 {
        let r = left.count > 20 ? 20 : left.count
        result += "\n" + hex([] + left[0...r-1])
        left.removeFirst(r)
    }
    
    return result
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
        let created = attr[NSFileCreationDate]! as! NSDate
        let modified = attr[NSFileModificationDate]! as! NSDate
        var size = attr[NSFileSize]! as! Int
        var name = file
        
        if type == NSFileTypeDirectory {
            size = 0
            name += "/"
        }
        
        entries.append(try! Directory.Entry.Builder()
            .setPath(name)
            .setSize(UInt32(size))
            .setCreated(knownDate(created))
            .setModified(knownDate(modified))
            .setUnknown(unknownDate())
            .build())
    }
    
    return d2a(try! Directory.Builder().setEntries(entries).build().data())
}

func knownDate(from: NSDate) -> DateTime {
    let c = NSCalendar.currentCalendar().components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: from)
    let date = try! Date.Builder().setYear(UInt32(c.year)).setMonth(UInt32(c.month)).setDay(UInt32(c.day)).build()
    let time = try! Time.Builder().setHour(UInt32(c.hour)).setMinute(UInt32(c.minute)).setSecond(UInt32(c.second)).setMilisecond(0).build()
    return try! DateTime.Builder().setDate(date).setTime(time).setTimezone(1).build()
}

func unknownDate() -> DateTime {
    let date = try! Date.Builder().setYear(1980).setMonth(0).setDay(0).build()
    let time = try! Time.Builder().setHour(0).setMinute(0).setSecond(0).setMilisecond(0).build()
    return try! DateTime.Builder().setDate(date).setTime(time).setTimezone(1).build()
}