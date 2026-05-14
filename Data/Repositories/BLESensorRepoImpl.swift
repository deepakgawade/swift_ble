//
//  BLESensorRepoImpl.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import Combine
import Foundation
import CoreBluetooth
final class BLESensorRepoImpl: BLESensorRepository{
    
    private let connection: BLEPeripheralConnection
    private var cancellables = Set<AnyCancellable>()
    
    private let readingSubject = PassthroughSubject<SensorData, Never>()
   private let connectionSubject = CurrentValueSubject<ConnectionState, Never>(.idle)
    
    private var latestTemp: Double = 0
    private var latestHum: Double = 0
    
    
    var readings: AnyPublisher<SensorData, Never>{
        readingSubject.eraseToAnyPublisher()
    }
    
    var connectionState: AnyPublisher<ConnectionState, Never>{
        connectionSubject.eraseToAnyPublisher()
    }
    
    
    init(
        connection: BLEPeripheralConnection,
    ) {
        self.connection = connection
        bindEvents()
        connection.discoverServices()
    }

    private func bindEvents() {
        connection.events
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .didReceiveData(let uuid, let data):
                    handleData(uuid: uuid, data: data)
                case .didUpdateConnectionState(let state):
                    connectionSubject.send(state)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Bridge central-level disconnect events into this repo's state stream.
        // BLEPeripheralConnection only sees characteristic events, so the
        // disconnected state must come from BLECentralManager via this signal.
//        disconnectSignal
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] state in self?.connectionSubject.send(state) }
//            .store(in: &cancellables)
    }
    
    private func handleData(uuid:CBUUID, data:Data) {
        
        switch uuid{
        case GATT.Sensor.temperature:
            guard let temp = BLEDecoder.decodeTemperature(data) else {return}
            latestTemp = temp
            readingSubject.send(SensorData(temoerature:latestTemp, humidity: latestHum,
                                          timeStamp:    Date()))
            
        case GATT.Sensor.humidity:
            guard let hum  = BLEDecoder.decodeHumidity(data) else {return}
            latestHum = hum
            readingSubject.send(SensorData(temoerature:latestTemp, humidity: latestHum,
                                           timeStamp:    Date()))
        default: break
        }
        
    }
    func startNotification() {
        connection.write(GATT.Sensor.startSensor, to: GATT.Sensor.control)
        
    }
    
    func stopNotification() {
        connection.write(GATT.Sensor.stopSensor, to: GATT.Sensor.control)
    }
    
    
}
