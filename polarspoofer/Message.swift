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
    case Continue
    case Notification
    case Request
    case Response
    case Unknown
    case Something
    
    public static func type(message: [UInt8]) -> MessageType {
        if message.elementsEqual([0x0f, 0x00]) {
            return .Control
        }
        
        if message[0] == 0x09 {
            return .Continue
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