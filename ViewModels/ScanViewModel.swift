//
//  ScanViewModel.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import Combine
import Foundation
import CoreBluetooth

struct ConnectedDevice: Identifiable {
    let id: UUID
    let connection: BLEPeripheralConnection
}

final class ScanViewModel: ObservableObject {

    @Published var devices: [BLEDevice] = []
    @Published var connectingID: UUID? = nil
    @Published var connectingState: ConnectionState = .idle
    @Published var navigateTo: ConnectedDevice? = nil

    private let repository: BLEScanRepository
    
    private var cancellables = Set<AnyCancellable>()

    init(
        repository: BLEScanRepository,
    ) {
        self.repository = repository
        repository.devices
            .receive(on: DispatchQueue.main)
        //.assign(to: &$devices)
            .sink { [weak self] newDevices in
                guard let self else { return }
                devices = newDevices
                
                guard navigateTo == nil,
                      let connected = newDevices.first(where: { $0.connected == .connected }),
                     
                        let connection = self.repository.connections[connected.id] else { return }
                
                
                connectingID = connected.id
                connectingState = .connected
                navigateTo = ConnectedDevice(
                    id: connected.id,
                    connection: connection,
                )
                
                
            }.store(in: &cancellables)
    }
    func startScan() {
        repository.startScanning()
    }

    func select(_ device: BLEDevice) {
        connectingID = device.id
        connectingState = .connecting
        repository.connect(to: device)
    }

    func resetConnecting() {
        connectingID = nil
        connectingState = .idle
        navigateTo = nil
    }
    
}
