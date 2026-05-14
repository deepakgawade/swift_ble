//
//  BLEPeripheralConnection.swift
//  harry
//
//  Created by ESAB India on 12/05/26.
//
import CoreBluetooth
import Combine
final class BLEPeripheralConnection: NSObject{
    
    let peripheral: CBPeripheral
    
    let events = PassthroughSubject<BLEEvent, Never>()
    
    private var controlChar: CBCharacteristic?
    private var pendingWrite: Data?
    
    init(peripheral:CBPeripheral)
    {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }
    
    func discoverServices(){
        peripheral.discoverServices(GATT.allservice)
    }
    
    func stopSensorNotifications() {
        write(GATT.Sensor.stopSensor, to: GATT.Sensor.control)
    }
    
    func write(_ data: Data, to uuid:CBUUID){
        guard let service = peripheral.services?.first(where: {$0.uuid == GATT.Sensor.service}),
              let char = service.characteristics?.first(where:{$0.uuid == uuid})
        else{
            pendingWrite = data; return
            
        }
        peripheral.writeValue(data, for: char, type: .withResponse)
                
    }
}

extension BLEPeripheralConnection: CBPeripheralDelegate{
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        peripheral.services?.forEach{service in
            switch service.uuid{
            case GATT.DIS.service:
                peripheral.discoverCharacteristics(GATT.DIS.allCharacteristics, for: service)
            case GATT.Sensor.service:
                peripheral.discoverCharacteristics([GATT.Sensor.temperature,GATT.Sensor.humidity,GATT.Sensor.control], for: service)
            default: break
        }}
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        
        service.characteristics?.forEach{ char in
            switch char.uuid{
            case GATT.Sensor.temperature,GATT.Sensor.humidity:
                peripheral.setNotifyValue(true, for: char)
            case GATT.Sensor.control:
                controlChar = char
                let data = pendingWrite ?? GATT.Sensor.startSensor
                peripheral.writeValue(data,for: char, type:.withResponse)
                pendingWrite=nil
            case GATT.DIS.modelNumber,GATT.DIS.firmwareVersion,GATT.DIS.hardwareVersion,GATT.DIS.manufacturerName:
                peripheral.readValue(for: char)
                
            default: break
            }}
        events.send(.didUpdateConnectionState(.ready))
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        
        guard let data = characteristic.value else{return}
        events.send(.didReceiveData(characteristic.uuid,data:data))
    }
    
}
