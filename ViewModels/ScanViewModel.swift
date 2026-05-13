//
//  ScanViewModel.swift
//  harry
//
//  Created by ESAB India on 13/05/26.
//
import Combine
import Foundation
final class ScanViewModel: ObservableObject{
    
    @Published var isScanning: Bool = false
    @Published var devices:[BLEDevice] = []
    
    private let repository: BLEScanRepository
    //private var cancellables = Set<AnyCancellable>()
    
    
    init(repository: BLEScanRepository){
        self.repository = repository
        
        repository.devices.receive(on: DispatchQueue.main)
            .assign(to: &$devices)///repository.devices.receive hold the refenec to published devices and as long as View is watching the deviecs it will last otherwise. onec view is rmoved the iViewmodel nwill bedeallocated along with  repository.devices subcription
        
        
    }
    
    func startScan(){
        
        print("Sacn started")
        isScanning = true
        repository.startScanning()
 
    }
    
    func select(_ device: BLEDevice){
        print("Sacn stoped")
        isScanning = false
        repository.connect(to: device)
    }
}
