//
//  BLECentralManager.swift
//  harry
//
//  Created by ESAB India on 12/05/26.
//
import CoreBluetooth
import Combine
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "harry", category: "BLE")

enum BLEEvent{
    case didDiscoverPeripheral(CBPeripheral, rssi:Int)
    case didConect(CBPeripheral)
    case didDisconnect(CBPeripheral)
    case didReceiveData(CBUUID, data: Data)
    case didUpdateConnectionState(ConnectionState)
}

final class BLECentralManager: NSObject{

    let events = PassthroughSubject<BLEEvent,Never>()//like a stream<BlEEvent>

    private(set) var connections: [UUID:BLEPeripheralConnection] = [:]

    private var central: CBCentralManager!
    // Holds scan request that arrived before BLE was ready
    private var pendingScan = false


    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue:.main)
    }

    func startScanning(){
        guard central.state == .poweredOn else {
            logger.debug("BLE not ready (state=\(self.central.state.rawValue)), deferring scan")
            pendingScan = true
            return
        }
        pendingScan = false
        logger.debug("Starting BLE scan")
        central.scanForPeripherals(withServices: nil)
//        central.scanForPeripherals(withServices: [GATT.Sensor.service])
        events.send(.didUpdateConnectionState(.scanning))
    }
    
    func disconnect(_ peripheral:CBPeripheral){
        connections[peripheral.identifier]?.disconnect()
        central.cancelPeripheralConnection(peripheral)//what thid function will do
        
    }
    
    func connect(_ peripheral: CBPeripheral){
        central.stopScan()
        central.connect(peripheral)
        events.send(.didUpdateConnectionState(.connecting))
    }
}

extension BLECentralManager: CBCentralManagerDelegate{
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.debug("CBCentralManager state changed to \(central.state.rawValue)")
        let state: ConnectionState = central.state == .poweredOn ? .idle : .disconnected
        events.send(.didUpdateConnectionState(state))

        if central.state == .poweredOn && pendingScan {
            startScanning()
        }
    }
    //Here we will receive notification when we connect to a peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let connection = BLEPeripheralConnection(peripheral: peripheral)
        
        connections[peripheral.identifier] = connection
        
        events.send(.didUpdateConnectionState(.discoveringServices))
        connection.discoverServices()
       
    }
    //here we will receive the ntification when peripheral is diconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connections.removeValue(forKey: peripheral.identifier)
        events.send(.didDisconnect(peripheral))
        
        events.send(.didUpdateConnectionState(.disconnected))
        
        //Auto-reconnect
        DispatchQueue.main.asyncAfter(deadline: .now()+2){
            self.connect(peripheral)
        }
        
        
    }
    //on this call we will recve all the peripheral devices
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        events.send(.didDiscoverPeripheral(peripheral, rssi: RSSI.intValue))
    }
    
    
}



