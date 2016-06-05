//
//  Constants.swift
//  polarspoofer
//
//  Created by Adam Kuczyński on 28.05.2016.
//  Copyright © 2016 Adam Kuczyński. All rights reserved.
//

import CoreBluetooth
import Foundation

struct Constants {
    struct UUIDs {
        static let Service = CBUUID(string: "fb005c14-9815-d766-a528-32d54cf35530")
        static let Char = CBUUID(string: "fb005c16-02e7-f387-1cad-8acd2d8df0c8")
    }
}

let BackupRoot = "/Users/ak/.polar/backup/current"
let SUCC = "[+]"
let FAIL = "[-]"