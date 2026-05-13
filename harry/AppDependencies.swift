//
//  AppDependencies.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//

import Combine
import Foundation

final class AppDependencies{
    // Single shared BLECentralManager — one CBCentralManager for the whole app
    let centralManager = BLECentralManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    // Scan is global — one repository shared across all devices
    lazy var scanRepository: BLEScanRepository = BLEScanRepoImpl(central: centralManager)
    
    //Per device repositories - keyed by perpheral UUID
    private var sensorRepos: [UUID: BLESensorRepository] = [:]
    
    
    init(){
        centralManager.events.sink{ [weak self] event in
            switch event{
            case .didConect(let peripheral):
                //makeDeviceRepositories(for: peripheral.identifier)
                break
            case .didDisconnect(let peripheral):
                break
                
            default: break
            }
        }.store(in: &cancellables)
    }
    
    
    private func makeDeviceRepositories(for id: UUID) {
        guard let connection = centralManager.connections[id] else { return }
//        sensorRepos[id]     = BLESensorRepositoryImpl(connection: connection)
//        deviceInfoRepos[id] = BLEDeviceInfoRepositoryImpl(connection: connection)
//        controlRepos[id]    = BLEControlRepositoryImpl(connection: connection)
    }

    private func removeDeviceRepositories(for id: UUID) {
//        sensorRepos.removeValue(forKey: id)
//        deviceInfoRepos.removeValue(forKey: id)
//        controlRepos.removeValue(forKey: id)
    }
        
        func makeScanViewModel()->ScanViewModel{
            ScanViewModel(repository: scanRepository)
        }
    
    
    
}
