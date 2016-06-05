//
//  Spoofer.swift
//  polarspoofer
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import CoreBluetooth
import Foundation

public class Spoofer : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var m : CBCentralManager?
    var p : CBPeripheral?
    var c : CBCharacteristic?
    
    public override init() {
        super.init()
        m = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }
    
    // CBCentralManagerDelegate
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if peripheral.name == nil || !peripheral.name!.containsString("Polar") {
            return
        }

        p = peripheral
        peripheral.delegate = self
        
        central.stopScan()
        central.connectPeripheral(peripheral, options: nil)
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print(SUCC, "connected to", peripheral.name!)
        peripheral.discoverServices([Constants.UUIDs.Service])
    }
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print(error == nil ? SUCC : FAIL, "disconnected from", peripheral.name!)
    }
    
    // CBPeripheralDelegate
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        for characteristic in service.characteristics! {
            if Constants.UUIDs.Char.isEqual(characteristic.UUID) {
                c = characteristic
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                peripheral.readValueForCharacteristic(characteristic)
            }
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let value = characteristic.value {
            recvp(value)
        }
    }
    
    var message = [UInt8]()
    
    public func recvp(value: NSData) {
        let packet = d2a(value)
        message += packet
        
        if packet[0] >> 4 == 0 {
            recvm(message)
            message.removeAll()
        }
    }
    
    public func recvm(message: [UInt8]) {
        let type = MessageType.type(message)
        if type == .Notification {
            recvNotification(message)
        } else if type == .Request {
            recvRequest(message)
        } else {
            print(FAIL, "recvm", type, hex(message))
        }
    }
    
    public func recvNotification(message: [UInt8]) {
        let type = NotificationType.type(message)

        print(SUCC, "recvm", MessageType.Notification, type, hex(decode(message)))
        
        if message.startsWith([0x18, 0x00, 0x01, 0x80]) || message.startsWith([0x18, 0x00, 0x03, 0x80]) {
            var response : [UInt8] = [0x19, 0x00, 0x00, 0x00]
            response += message[4...message.count-1]
            response += [0x00]
            response[20] = 0x08
            sendm(response)
        }
    }
    
    public func recvRequest(message: [UInt8]) {
        let decoded = decode(message)
        print(SUCC, "recvm", MessageType.Request, hex(decoded))
        
        if decoded.elementsEqual([0x08, 0x00, 0x12, 0x0B, 0x2F, 0x44, 0x45, 0x56, 0x49, 0x43, 0x45, 0x2E, 0x42, 0x50, 0x42]) {
            sendm([0x69, 0x00, 0x00, 0x00, 0x0A, 0x06, 0x08, 0x01, 0x10, 0x08, 0x18, 0x05, 0x12, 0x06, 0x08, 0x00, 0x10, 0x09, 0x18, 0x05, 0x59, 0x1A, 0x07, 0x08, 0x01, 0x10, 0x08, 0x18, 0xAC, 0x02, 0x32, 0x08, 0x36, 0x41, 0x35, 0x42, 0x31, 0x31, 0x31, 0x44, 0x49, 0x3A, 0x0A, 0x50, 0x6F, 0x6C, 0x61, 0x72, 0x20, 0x4D, 0x34, 0x30, 0x30, 0x42, 0x0B, 0x30, 0x30, 0x37, 0x35, 0x33, 0x39, 0x39, 0x32, 0x33, 0x2E, 0x30, 0x32, 0x4A, 0x05, 0x42, 0x6C, 0x61, 0x63, 0x6B, 0x52, 0x06, 0x55, 0x6E, 0x69, 0x73,0x29, 0x65, 0x78, 0x5A, 0x10, 0x30, 0x30, 0x32, 0x32, 0x44, 0x30, 0x46, 0x46, 0x46, 0x45, 0x36, 0x41, 0x35, 0x42, 0x31, 0x19, 0x31, 0x62, 0x14, 0x91, 0xB5, 0x57, 0x51, 0x47, 0xAA, 0x68, 0x7C, 0xF8, 0x8D, 0x26, 0x18, 0xCC, 0xE3, 0x63, 0x3B, 0x08, 0xD9, 0x24, 0xC8, 0xC5, 0x00, ])
        }
    }
    
    public func sendm(message: [UInt8]) {
        print(SUCC, "sendm", MessageType.type(message), hex(message))
        var remains = message
        
        while remains.count > 0 {
            let s = remains.count > 20 ? 20 : remains.count
            sendp([] + remains[0...s-1])
            remains.removeFirst(s)
        }
    }
    
    public func sendp(packet: [UInt8]) {
        p!.writeValue(a2d(packet), forCharacteristic: c!, type: .WithoutResponse)
    }
}

