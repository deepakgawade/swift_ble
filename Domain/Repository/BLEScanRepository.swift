//
//  BLEScanRepository.swift
//  harry
//
//  Created by ESAB India on 12/05/26.
//

import Combine

protocol BLEScanRepository{
    var devices : AnyPublisher<[BLEDevice], Never>{get }
    func startScanning()
    func connect(to device: BLEDevice)
}
