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
    let connected: ConnectionState
    
    func with(connected: ConnectionState) -> BLEDevice {
        BLEDevice(id: id, name: name, rssi: rssi, peripheral: peripheral, connected: connected)
    }

    static func ==(lhs: BLEDevice, rhs:BLEDevice)-> Bool{
        lhs.id == rhs.id && lhs.connected == rhs.connected
    }
}
