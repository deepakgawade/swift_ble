//
//  DashBoardView.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//


import SwiftUI

struct DashBoardView: View{
    @ObservedObject var viewModel: DashBoardViewModel
    
    var body: some View{
        List{
            Section("Connection"){
                HStack{
                    Circle().fill(viewModel.connectionState == .ready ? .green : .orange)
                        .frame(width: 10,height: 10)
                    Text(viewModel.connectionState.displayName).foregroundStyle(.secondary)
                }
            }
            Section("Sensor Data"){
                
                LabeledContent("Temperature", value: viewModel.formattedTemperature)
                LabeledContent("Humidity", value: viewModel.formattedHumidity)
                LabeledContent("Updated", value: viewModel.lastUpdated)
                
            }
        }
        .navigationTitle("Dashboard")
        .onDisappear { viewModel.disconnect() }
        .toolbar{
            ToolbarItem{Button{viewModel.toogelNotify()}label:{
                Label(
                                        viewModel.isNotifyEnabled ? "Stop Notifications" : "Start Notifications",
                                        systemImage: viewModel.isNotifyEnabled ? "bell.slash" : "bell"
                                    )
            } }
        }
        .navigationBarTitleDisplayMode( .inline)
    }
}

private extension ConnectionState {
    var displayName: String {
        switch self {
        case .idle:                return "Idle"
        case .scanning:            return "Scanning…"
        case .connecting:          return "Connecting…"
        case .discoveringServices: return "Setting up…"
        case .ready:               return "Connected"
        case .disconnected:        return "Disconnected — reconnecting…"
        case .connected: return "Connected"
            
        }
    }
}
