//
//  BLEDevice.swift
//  harry
//
//  Created by ESAB India on 12/05/26.
//
import Foundation
import CoreBluetooth
struct BLEDevice: Identifiable, Equatable{
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
    
    static func ==(lhs: BLEDevice, rhs:BLEDevice)-> Bool{
        lhs.id == rhs.id
    }
}
