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
        print(SUCC, "recvp", hex(d2a(value)))
        
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
        } else if type == .Continue {
            print(SUCC, "recvm", type)
            sendp16()
        } else {
            print(FAIL, "recvm", type, hex(message))
        }
    }
    
    public func recvNotification(message: [UInt8]) {
        let type = NotificationType.type(message)

        print(SUCC, "recvm", MessageType.Notification, type)
        
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
        let request = try! Request.parseFromData(a2d(decoded))
        let path = BackupRoot + request.path
        print(SUCC, "recvm", MessageType.Request, request.types, path)

        var response : [UInt8]
        
        if path.hasSuffix("/") {
            response = readDirectory(path)
        } else {
            response = readFile(path)
        }
        
        sendm(encode(response))
    }
    
    var packets = [[UInt8]]()

    public func sendm(message: [UInt8]) {
        var remains = message
        packets.removeAll()
        
        while remains.count > 0 {
            let s = remains.count > 20 ? 20 : remains.count
            packets.append([] + remains[0...s-1])
            remains.removeFirst(s)
        }
        
        sendp16()
    }
    
    public func sendp16() {
        if (packets.count == 0) {
            print(FAIL, "sendp16")
            return
        }
        
        print(SUCC, "sendp16", MessageType.type(packets[0]))
        let count = packets.count > 16 ? 16 : packets.count
        
        for _ in 0..<count {
            sendp(packets.removeFirst())
        }
    }
    
    public func sendp(packet: [UInt8]) {
        print(SUCC, "sendp", hex(packet))
        p!.writeValue(a2d(packet), forCharacteristic: c!, type: .WithoutResponse)
    }
}

