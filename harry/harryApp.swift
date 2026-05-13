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

    var body: some Scene {
        WindowGroup {
            ScanView(viewModel: dependencies.makeScanViewModel())
        }
    }
}
