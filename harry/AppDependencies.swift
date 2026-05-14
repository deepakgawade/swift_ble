//
//  AppDependencies.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//

import Combine
import Foundation

final class AppDependencies {
    private let centralManager = BLECentralManager()

    lazy var scanRepository: BLEScanRepository = BLEScanRepoImpl(central: centralManager)

    func makeScanViewModel() -> ScanViewModel {
        ScanViewModel(
            repository: scanRepository,
           
        )
    }

    func makeDashboardViewModel(from device: ConnectedDevice) -> DashBoardViewModel {
        let repo = BLESensorRepoImpl(
            connection: device.connection,
       
        )
        return DashBoardViewModel(
            repository: repo,
            onDisconnect: { [weak self] in self?.centralManager.disconnect(id: device.id) }
        )
    }
}
