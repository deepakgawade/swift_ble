//
//  BLEDecoder.swift
//  harry
//
//  Created by ESAB India on 11/05/26.
//

import Foundation
enum BLEDecoder{
    
    // MARK: Temperature
    // int16_t little-endian ×10 → Double °C
    // [0xEB, 0x00] → raw 235 → 23.5 °C
    static func decodeTemperature(_ data: Data)-> Double?{
        guard data.count >= 2 else {return nil}
        let raw = Int16(data[0])|(Int16(data[1])<<8)
        return Double(raw)/10.0
    }
    
    // MARK: Humidity
    // uint16_t little-endian ×10 → Double %RH
    // [0x26, 0x02] → raw 550 → 55.0 %
    
    static func decodeHumidity(_ data: Data)-> Double?
    {
        guard data.count >= 2 else {return nil}
        let raw  = UInt16(data[0])|(UInt16(data[1])<<8)
        return Double (raw)/10.0
    }
    
    // MARK: DIS strings
    // Raw UTF-8 bytes, no null terminator
    static func decodeString(_ data:Data)->String?{
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: Control (encode for writing to ESP32)
     // Bool → uint16 LE → Data
    static func encodeControl(_ start:Bool)->Data{
        return start ? GATT.Sensor.startSensor:GATT.Sensor.stopSensor
    }
    
}
