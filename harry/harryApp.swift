//
//  harryApp.swift
//  harry
//
//  Created by ESAB India on 07/05/26.
//

import SwiftUI

@main
struct harryApp: App {
    private let dependencies = AppDependencies()
    
    private let menuOption:[String] = ["Books","BLE Scanner"]

    
    //ToDo: Need to add About page for IOT device version.
    var body: some Scene {
        WindowGroup {
            NavigationStack{
                List{
                    ForEach(menuOption, id:\.self){ item in
                        NavigationLink{
                            switch item {
                                case menuOption[0]:
                                    BookView()
                                case menuOption[1]:
                                ScanView(
                                    viewModel: dependencies.makeScanViewModel(),
                                    makeDashboard: dependencies.makeDashboardViewModel(from:)
                                )
                            default:
                                Text("About")
                                
                            }
                        } label: {
                            Text(item)
                        }
                       
                    }
                }.navigationTitle("Harry Potter App")
            }
         
        }
    }
}
