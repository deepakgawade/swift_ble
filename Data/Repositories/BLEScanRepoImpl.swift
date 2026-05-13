//
//  BLEScanRepoImpl.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import Combine
import CoreBluetooth
final class BLEScanRepoImpl: BLEScanRepository{

    
    private let central: BLECentralManager
    //Set<Subscriptions> which can cancel itself
    private var cancellables = Set<AnyCancellable>()
    
    //private CurrentValueSubject is used like oBsevable subject with deafult value in dart
    private let devicesSubject = CurrentValueSubject<[BLEDevice],Never>([])//default value here is empty list
    
    var devices : AnyPublisher<[BLEDevice],Never>{
        
        //this will prevent form sending data on subscription like using add or send method
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
    
    private func bindEvents(){
        
        central.events.sink{ [weak self] event in
            guard let self ,
        case .didDiscoverPeripheral(let peripheral, let rssi) = event
            else {return}
            
            guard rssi > -60 else {return}
            
            let device = BLEDevice(
                id: peripheral.identifier,
                name: peripheral.name ?? "Unknown",
                rssi: rssi,
                peripheral: peripheral
                
            )
            //reading the list of devices
            var current = self.devicesSubject.value
            print(current.count)
            
            //checking if the same device exist in list already the skip adding it again
            if !current.contains(where: {$0.id == device.id}){
                current.append(device)
                //send the updated list to devicesSubject
                self.devicesSubject.send(current)// this will update the [devices]
            }
        }.store(in: &cancellables)// keeps the Anycancelalble object alive and bind it to class otherwise its lost means subscription will be lost.
        
    }
    
    
    
    
    
    
}
