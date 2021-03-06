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
            recvp(d2a(value))
        }
    }

    var recvpa = [PSPacket]()
    var recvca = [PSChunk]()
    var sendca = [PSChunk]()
    
    public func recvp(value: [UInt8]) {
        let packet = PSPacket.decode(value)
        recvpa.append(packet)
        
        if (packet.sequence == 0) {
            recvc(recvpa)
            recvpa.removeAll()
        }
    }
    
    public func recvc(packets: [PSPacket]) {
        let chunk = PSChunk.decode(packets)
        recvca.append(chunk)
        
        if (chunk.more) {
            sendr([0x09, chunk.number])
        } else {
            recvm(recvca)
            recvca.removeAll()
        }
    }
    
    public func recvm(chunks: [PSChunk]) {
        let message = PSMessage.decode(chunks)

        if message.type == .Control {
            print(SUCC, "recvm", message.type)
            return
        }
        
        if message.type == .Error {
            print(FAIL, "recvm", message.type)
            return
        }
        
        if message.type == .Continue {
            sendc()
            return
        }
        
        if message.subtype == .Notification {
            print(SUCC, "recvm", message.type, message.subtype, hex(message.header), hex(message.payload))
            return
        }
        
        if message.subtype == .Query {
            print(SUCC, "recvm", message.type, message.subtype, hex(message.header))
            let response = PSMessage()

            response.payload = message.payload + [0x00]

            sendm(response)
            return
        }
        
        if message.subtype == .Data {
            let length = Int(message.header[0])
            let data = Array(message.payload[0...length-1])
            let request = try! Request.parseFromData(a2d(data))
            let path = BackupRoot + request.path
            
            print(SUCC, "recvm", message.type, message.subtype, request.types, path)
            
            if request.types == .Read {
                let response = PSMessage()

                if path.hasSuffix("/") {
                    response.payload = readDirectory(path) + [0x00]
                } else {
                    response.payload = readFile(path) + [0x00]
                }
                
                sendm(response)
            } else if request.types == .Write {
                sendr([0x09, 0x00])
            }
            
            return
        }

        print(FAIL, "recvm", message.type, message.subtype, hex(message.header), hex(message.payload))
    }
    
    public func sendm(message: PSMessage) {
        sendca = PSMessage.encode(message)
        sendc()
    }
    
    public func sendc() {
        let chunk = sendca.removeFirst()
        
        for packet in PSChunk.encode(chunk) {
            sendp(packet)
        }
    }
    
    public func sendp(packet: PSPacket) {
        sendr(PSPacket.encode(packet))
    }
    
    public func sendr(raw: [UInt8]) {
        p!.writeValue(a2d(raw), forCharacteristic: c!, type: .WithoutResponse)
    }
}

