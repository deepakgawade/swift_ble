//
//  BLEScanRepository.swift
//  harry
//
//  Created by ESAB India on 12/05/26.
//

import Combine
import Foundation
protocol BLEScanRepository{
    var devices : AnyPublisher<[BLEDevice], Never>{get }
    var connections: [UUID:BLEPeripheralConnection] {get}
    func startScanning()
    func connect(to device: BLEDevice)
}
