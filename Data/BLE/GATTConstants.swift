//
//  Untitled.swift
//  harry
//
//  Created by ESAB India on 11/05/26.
//

import CoreBluetooth

enum GATT{
    
    
    enum DIS{
        static let service = CBUUID(string:"180A")
        static let manufacturerName = CBUUID(string:"2A29")
        static let modelNumber = CBUUID(string:"2A24")
        static let firmwareVersion = CBUUID(string:"2A26")
        static let hardwareVersion = CBUUID(string:"2A27")
        
        static let allCharacteristics = [manufacturerName, modelNumber, firmwareVersion, hardwareVersion]
    }
    
    enum Sensor{
        static let service = CBUUID(string:"12345678-1234-1234-1234-123456789abc")
        static let temperature = CBUUID(string:"12345678-1234-1234-1234-123456789abd")
        static let humidity = CBUUID(string:"12345678-1234-1234-1234-123456789abe")
        static let control = CBUUID(string:"12345678-1234-1234-1234-123456789abf")
        
        //uint16 little endian
        static let startSensor: Data = Data([0x01, 0x00])
        static let stopSensor: Data = Data([0x00, 0x00])
        
        
    }
    
    static let allservice = [DIS.service, Sensor.service]
    
}
