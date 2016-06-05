//
//  Message.swift
//  polarspoofer
//
//  Created by Adam Kuczyński on 05.06.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import Foundation

public enum MessageType {
    case Control
    case Notification
    case Request
    case Response
    case Unknown
    
    public static func type(message: [UInt8]) -> MessageType {
        if message.elementsEqual([0x0f, 0x00]) {
            return .Control
        }
        
        if message.count > 4 && message[3] == 0x80 {
            return .Notification
        }
        
        if message.count > 4 && message[3] == 0x00 {
            return message[0] & 0x01 == 0x01 ? .Response : .Request
        }
        
        return .Unknown
    }
}

public enum NotificationType : UInt8 {
    case SetSystemDateTime = 1
    case SetLocalDateTime = 3
    
    public static func type(message: [UInt8]) -> NotificationType {
        return NotificationType(rawValue: message[2])!
    }
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