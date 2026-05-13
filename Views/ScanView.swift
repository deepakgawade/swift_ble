//
//  ScanView.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import SwiftUI
struct ScanView:View{
    
    @StateObject var viewModel: ScanViewModel
    @State private var navigate = false
    
    var body:some View{
        NavigationStack{
            List(viewModel.devices){device in
                Button{
                    viewModel.select(device)
                    navigate = true
                } label: {
                    
                    HStack{
                        Image(systemName: "cpu")
                        VStack(alignment: .leading){
                            Text(device.name).font(.headline)
                            Text("RSSI: \(device.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.overlay{
                if viewModel.devices.isEmpty{
                    ContentUnavailableView("Scanning", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            
            .navigationTitle("Find Device")
            .toolbar{
                ToolbarItem{Button("Scan"){viewModel.startScan()}}
            }.navigationDestination(isPresented: $navigate){}
            
        }.onAppear(){viewModel.startScan()}
        
    }
}
