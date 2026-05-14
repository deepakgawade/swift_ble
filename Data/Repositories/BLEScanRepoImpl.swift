//
//  BLEScanRepoImpl.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import Combine
import CoreBluetooth
final class BLEScanRepoImpl: BLEScanRepository{
    var connections: [UUID : BLEPeripheralConnection] {
        central.connections
    }

    private let central: BLECentralManager
    private var cancellables = Set<AnyCancellable>()

    private let devicesSubject = CurrentValueSubject<[BLEDevice],Never>([])

    var devices : AnyPublisher<[BLEDevice],Never>{
        devicesSubject.eraseToAnyPublisher()
    }

    init(central: BLECentralManager){
        self.central = central
        bindEvents()
    }
    
    
    
    func startScanning() {
        devicesSubject.send([])
        central.startScanning()
    }
    
    func connect(to device: BLEDevice) {
        central.connect( device.peripheral)
    }
    
    private func bindEvents() {
        central.events.sink { [weak self] event in
            
            print(event)
            guard let self else { return }
            switch event {
            case .didDiscoverPeripheral(let peripheral, let rssi):
                guard rssi > -60 else { return }
                let device = BLEDevice(
                    id: peripheral.identifier,
                    name: peripheral.name ?? "Unknown",
                    rssi: rssi,
                    peripheral: peripheral,
                    connected: .idle
                )
                var current = devicesSubject.value
                if !current.contains(where: { $0.id == device.id }) {
                    current.append(device)
                    devicesSubject.send(current)
                }

            case .didConect(let peripheral):
                var current = devicesSubject.value
                if let index = current.firstIndex(where: { $0.id == peripheral.identifier }) {
                    print("device Connected: \(current[index].connected)")

                    current[index] = current[index].with(connected: .connected)
                    devicesSubject.send(current)
                }

            case .didDisconnect(let peripheral):
                var current = devicesSubject.value
                if let index = current.firstIndex(where: { $0.id == peripheral.identifier }) {
                    current[index] = current[index].with(connected: .disconnected)
                    devicesSubject.send(current)
                }
                
            default:
                break
            }
        }.store(in: &cancellables)
    }
    
    
    
    
    
    
}
