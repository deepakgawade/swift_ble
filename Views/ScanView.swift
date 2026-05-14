//
//  ScanView.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import SwiftUI

struct ScanView: View {

    @StateObject var viewModel: ScanViewModel
    let makeDashboard: (ConnectedDevice) -> DashBoardViewModel
    @State private var showDashboard = false
    @State private var dashboardViewModel: DashBoardViewModel?

    var body: some View {
        NavigationStack {
            List(viewModel.devices) { device in
                Button {
                    viewModel.select(device)
                
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text("RSSI: \(device.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if device.id == viewModel.connectingID {
                            connectionIndicator(device.connected)
                        }
                    }
                }
                .disabled(viewModel.connectingID != nil && device.id != viewModel.connectingID)
            }
            .overlay {
                if viewModel.devices.isEmpty {
                    ContentUnavailableView("Scanning", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .navigationTitle("Find Device")
            .toolbar {
                ToolbarItem { Button("Scan") { viewModel.startScan() } }
            }
            .navigationDestination(isPresented: $showDashboard) {
                if let vm = dashboardViewModel {
                    DashBoardView(viewModel: vm)
                }
            }
            .onChange(of: viewModel.navigateTo != nil) { _, isConnected in
                if isConnected, let device = viewModel.navigateTo {
                    dashboardViewModel = makeDashboard(device)
                    showDashboard = true
                }
            }
            .onChange(of: showDashboard) { _, isShown in
                if !isShown {
                    viewModel.resetConnecting()
                    dashboardViewModel = nil
                }
            }
        }
        .onAppear { viewModel.startScan() }
    }

    @ViewBuilder
    private func connectionIndicator(_ state: ConnectionState) -> some View {
        switch state {
        case .connecting:
            ProgressView()
        case .ready,.connected:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        default:
            EmptyView()
        }
    }
}
