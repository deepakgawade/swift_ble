//
//  DashBoardViewModel.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import Combine
import Foundation

final class DashBoardViewModel: ObservableObject {

    @Published var formattedTemperature = "--"
    @Published var formattedHumidity = "--"
    @Published var lastUpdated = "--"
    @Published var connectionState: ConnectionState = .idle
    @Published var isNotifyEnabled = false

    private let repository: BLESensorRepository
    private let onDisconnect: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(repository: BLESensorRepository, onDisconnect: @escaping () -> Void) {
        self.repository = repository
        self.onDisconnect = onDisconnect
        bindReadings()
        bindConnectionstate()
    }

    func toogelNotify() {
        isNotifyEnabled ? repository.stopNotification() : repository.startNotification()
        isNotifyEnabled.toggle()
    }

    func disconnect() {
        onDisconnect()
    }

    private func bindReadings() {
        repository.readings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                self?.formattedTemperature = String(format: "%.1f °C", reading.temoerature)
                self?.formattedHumidity    = String(format: "%.1f %%", reading.humidity)
                self?.lastUpdated = reading.timeStamp.formatted(date: .omitted, time: .standard)
            }
            .store(in: &cancellables)
    }

    private func bindConnectionstate() {
        repository.connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }
}
