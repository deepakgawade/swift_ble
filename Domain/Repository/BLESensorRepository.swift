//
//  BLESensorRepository.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import Combine
protocol BLESensorRepository {
    var readings: AnyPublisher<SensorData, Never> { get }
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    func startNotification()
    func stopNotification()
}

