# GATT Protocol — iOS Integration Guide
### MVVM + SOLID Architecture

---

## Table of Contents

1. [GATT Protocol Reference](#1-gatt-protocol-reference)
2. [SOLID Principles Applied](#2-solid-principles-applied)
3. [MVVM Layer Responsibilities](#3-mvvm-layer-responsibilities)
4. [Folder Structure](#4-folder-structure)
5. [Data Source Layer](#5-data-source-layer)
6. [Domain Layer — Protocols and Models](#6-domain-layer--protocols-and-models)
7. [Repository Layer — Implementations](#7-repository-layer--implementations)
8. [ViewModel Layer](#8-viewmodel-layer)
9. [View Layer — SwiftUI](#9-view-layer--swiftui)
10. [App Entry Point and DI Wiring](#10-app-entry-point-and-di-wiring)
11. [Mocks for Previews and Tests](#11-mocks-for-previews-and-tests)
12. [Startup Sequence](#12-startup-sequence)

---

## 1. GATT Protocol Reference

### Device

| Property | Value |
|---|---|
| Advertised Name | `ESP32-BLE-Dev` |
| ATT MTU | 512 bytes |
| BLE Stack | NimBLE-Arduino v1.4.x |
| Max Simultaneous Clients | 3 |

---

### Data Transfer Format

All multi-byte numeric values are transmitted **little-endian (LSB first)**.
String characteristics are **raw UTF-8 bytes with no null terminator**.

```
Temperature 23.5 °C
  Scaled integer : 235  (= 23.5 × 10)
  Hex            : 0x00EB
  Bytes on wire  : EB 00   ← LSB first
  Swift decode   : Int16(bytes[0]) | (Int16(bytes[1]) << 8) → 235 → / 10.0 → 23.5
```

---

### Service 1 — Device Information Service (DIS)

**UUID:** `0x180A` (Bluetooth SIG standard)

Static read-only metadata. Set once at boot.

| Characteristic | UUID | Properties | Format |
|---|---|---|---|
| Manufacturer Name | `0x2A29` | READ | UTF-8 bytes |
| Model Number | `0x2A24` | READ | UTF-8 bytes |
| Firmware Revision | `0x2A26` | READ | UTF-8 bytes |
| Hardware Revision | `0x2A27` | READ | UTF-8 bytes |

---

### Service 2 — Sensor Data Service

**UUID:** `12345678-1234-1234-1234-123456789abc` (custom)

Notifications are **off by default** — client must write `0x0001` to the Control
characteristic to begin receiving them.

| Characteristic | UUID | Properties | Format | Range |
|---|---|---|---|---|
| Temperature | `...123456789abd` | READ, NOTIFY | `int16_t` LE ×10, 2 bytes | −40.0 – 85.0 °C |
| Humidity | `...123456789abe` | READ, NOTIFY | `uint16_t` LE ×10, 2 bytes | 0.0 – 100.0 % RH |
| Control | `...123456789abf` | WRITE | `uint16_t` LE, 2 bytes | `0x0001` start / `0x0000` stop |

#### Temperature decode table

| Bytes | Raw `int16_t` | Decoded |
|---|---|---|
| `C8 00` | 200 | 20.0 °C |
| `EB 00` | 235 | 23.5 °C |
| `5E 01` | 350 | 35.0 °C |
| `F0 FF` | −16 | −1.6 °C |

#### Humidity decode table

| Bytes | Raw `uint16_t` | Decoded |
|---|---|---|
| `90 01` | 400 | 40.0 % |
| `26 02` | 550 | 55.0 % |
| `84 03` | 900 | 90.0 % |

---

### Notification Flow

```
Client                           ESP32
  |--- Connect ----------------->|
  |--- Subscribe temp CCCD ----->|   ← iOS accepts incoming notifications
  |--- Subscribe hum  CCCD ----->|   ← iOS accepts incoming notifications
  |--- Write Control: 01 00 ---->|   ← ESP32 starts sending
  |<-- Notify temp : EB 00 ------|   23.5 °C  ┐
  |<-- Notify hum  : 26 02 ------|   55.0 %   ┘ every 2 000 ms
  |--- Write Control: 00 00 ---->|   ← ESP32 stops sending
  |--- Disconnect -------------->|
```

> **Critical:** subscribing CCCD (steps 2–3) tells iOS to *accept* notifications.
> Writing Control `01 00` (step 4) tells the *ESP32 to start sending* them.
> Both steps are required — the most common integration bug is doing one but not the other.

---

## 2. SOLID Principles Applied

### S — Single Responsibility

Each class owns exactly one concern. No class crosses layer boundaries.

| Class | Owns | Does NOT own |
|---|---|---|
| `BLECentralManager` | `CBCentralManager` lifecycle, connection FSM | Decoding bytes, UI state |
| `BLEDecoder` | Binary LE → Swift types | Bluetooth, UI |
| `BLESensorRepositoryImpl` | Subscribe, notify, publish `SensorReading` | Connecting, scanning |
| `DashboardViewModel` | Format readings for display | Any BLE detail |
| `DashboardView` | Render state | Any logic |

> **The failure mode:** one giant `BLEManager` that scans, connects, decodes,
> formats, and publishes UI state. Every concern lives in one class, every change
> risks breaking everything else.

---

### O — Open / Closed

ViewModels depend on **protocols**, not concrete implementations.
Adding a new sensor service means adding a new conforming type — existing code is untouched.

```swift
// Adding a pressure sensor requires zero changes to DashboardViewModel
protocol BLESensorRepository {
    var readings: AnyPublisher<SensorReading, Never> { get }
    func startNotifications()
    func stopNotifications()
}
```

---

### L — Liskov Substitution

Any conforming `BLESensorRepository` is fully substitutable for another.
This is what makes SwiftUI Previews and unit tests possible without a physical device.

```swift
// Production — real CoreBluetooth
let vm = DashboardViewModel(repository: BLESensorRepositoryImpl(central: manager))

// Preview / test — fake data, no hardware needed
let vm = DashboardViewModel(repository: MockBLESensorRepository())
```

---

### I — Interface Segregation

No ViewModel receives a repository with methods it does not need.
`DashboardViewModel` has no business calling `startScan()`.

```swift
protocol BLEScanRepository       { ... }  // ScanViewModel only
protocol BLESensorRepository     { ... }  // DashboardViewModel only
protocol BLEDeviceInfoRepository { ... }  // DeviceInfoViewModel only
protocol BLEControlRepository    { ... }  // ControlViewModel only
```

---

### D — Dependency Inversion

ViewModels receive dependencies through **constructor injection**.
They never import `CoreBluetooth` or instantiate concrete types.

```swift
final class DashboardViewModel: ObservableObject {
    private let repository: BLESensorRepository  // abstraction

    init(repository: BLESensorRepository) {      // injected, not created here
        self.repository = repository
    }
}
```

---

## 3. MVVM Layer Responsibilities

```
┌──────────────────────────────────────────────┐
│  View (SwiftUI)                              │
│  Renders @Published state.                   │
│  Calls ViewModel methods on user interaction.│
│  Zero logic.                                 │
└───────────────────┬──────────────────────────┘
                    │ @Published / method calls
┌───────────────────▼──────────────────────────┐
│  ViewModel (ObservableObject)                │
│  Subscribes to Repository publisher.         │
│  Holds @Published display state.             │
│  Formats values ("23.5 °C").                 │
│  Zero CoreBluetooth imports.                 │
└───────────────────┬──────────────────────────┘
                    │ AnyPublisher<Model, Never>
┌───────────────────▼──────────────────────────┐
│  Repository (protocol + implementation)      │
│  Subscribes to BLECentralManager publisher.  │
│  Runs raw Data through BLEDecoder.           │
│  Exposes clean typed publishers.             │
│  No CBPeripheral / Data leaks upward.        │
└───────────────────┬──────────────────────────┘
                    │ PassthroughSubject<Data, Never>
┌───────────────────▼──────────────────────────┐
│  Data Source                                 │
│  BLECentralManager — wraps CBCentralManager. │
│  BLEDecoder        — binary → Swift types.   │
│  GATTConstants     — all CBUUIDs.            │
└──────────────────────────────────────────────┘
```

---

## 4. Folder Structure

```
ESP32SensorApp/
│
├── App/
│   ├── ESP32SensorApp.swift          # @main, injects real dependency graph
│   └── AppDependencies.swift         # builds and owns all concrete types
│
├── Data/                             # Data source layer
│   ├── BLE/
│   │   ├── BLECentralManager.swift       # CBCentralManager lifecycle + scan/connect only
│   │   ├── BLEPeripheralConnection.swift # per-device state + CBPeripheralDelegate
│   │   ├── BLEDecoder.swift              # pure static decode / encode functions
│   │   └── GATTConstants.swift           # all CBUUIDs and control payloads
│   └── Repositories/                 # concrete repository implementations
│       ├── BLEScanRepositoryImpl.swift
│       ├── BLESensorRepositoryImpl.swift
│       ├── BLEDeviceInfoRepositoryImpl.swift
│       └── BLEControlRepositoryImpl.swift
│
├── Domain/                           # Protocols and models — zero CoreBluetooth
│   ├── Models/
│   │   ├── SensorReading.swift
│   │   ├── DeviceInfo.swift
│   │   ├── BLEDevice.swift
│   │   └── ConnectionState.swift
│   └── Repositories/
│       ├── BLEScanRepository.swift
│       ├── BLESensorRepository.swift
│       ├── BLEDeviceInfoRepository.swift
│       └── BLEControlRepository.swift
│
├── Presentation/
│   ├── Scan/
│   │   ├── ScanViewModel.swift
│   │   └── ScanView.swift
│   ├── Dashboard/
│   │   ├── DashboardViewModel.swift
│   │   └── DashboardView.swift
│   ├── DeviceInfo/
│   │   ├── DeviceInfoViewModel.swift
│   │   └── DeviceInfoView.swift
│   └── Control/
│       ├── ControlViewModel.swift
│       └── ControlView.swift
│
└── Mocks/
    ├── MockBLEScanRepository.swift
    ├── MockBLESensorRepository.swift
    ├── MockBLEDeviceInfoRepository.swift
    └── MockBLEControlRepository.swift
```

---

## 5. Data Source Layer

### `GATTConstants.swift`

```swift
import CoreBluetooth

enum GATT {

    enum DIS {
        static let service          = CBUUID(string: "180A")
        static let manufacturerName = CBUUID(string: "2A29")
        static let modelNumber      = CBUUID(string: "2A24")
        static let firmwareRevision = CBUUID(string: "2A26")
        static let hardwareRevision = CBUUID(string: "2A27")

        static let allCharacteristics = [
            manufacturerName, modelNumber,
            firmwareRevision, hardwareRevision
        ]
    }

    enum Sensor {
        static let service     = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
        static let temperature = CBUUID(string: "12345678-1234-1234-1234-123456789abd")
        static let humidity    = CBUUID(string: "12345678-1234-1234-1234-123456789abe")
        static let control     = CBUUID(string: "12345678-1234-1234-1234-123456789abf")

        // Control characteristic payloads — uint16 little-endian
        static let startNotifications: Data = Data([0x01, 0x00])
        static let stopNotifications:  Data = Data([0x00, 0x00])
    }

    static let allServices = [DIS.service, Sensor.service]
}
```

---

### `BLEDecoder.swift`

Pure static functions. No BLE state, no side effects, fully unit-testable.

```swift
import Foundation

enum BLEDecoder {

    // MARK: Temperature
    // int16_t little-endian ×10 → Double °C
    // [0xEB, 0x00] → raw 235 → 23.5 °C
    static func decodeTemperature(_ data: Data) -> Double? {
        guard data.count >= 2 else { return nil }
        let raw = Int16(data[0]) | (Int16(data[1]) << 8)
        return Double(raw) / 10.0
    }

    // MARK: Humidity
    // uint16_t little-endian ×10 → Double %RH
    // [0x26, 0x02] → raw 550 → 55.0 %
    static func decodeHumidity(_ data: Data) -> Double? {
        guard data.count >= 2 else { return nil }
        let raw = UInt16(data[0]) | (UInt16(data[1]) << 8)
        return Double(raw) / 10.0
    }

    // MARK: DIS strings
    // Raw UTF-8 bytes, no null terminator
    static func decodeString(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }

    // MARK: Control (encode for writing to ESP32)
    // Bool → uint16 LE → Data
    static func encodeControl(_ start: Bool) -> Data {
        return start ? GATT.Sensor.startNotifications
                     : GATT.Sensor.stopNotifications
    }
}
```

---

### `BLEPeripheralConnection.swift`

One instance per connected device. Owns all per-device state and is the sole
`CBPeripheralDelegate`. `BLECentralManager` creates one on `didConnect` and
destroys it on `didDisconnect`.

```swift
import CoreBluetooth
import Combine

final class BLEPeripheralConnection: NSObject {

    let peripheral: CBPeripheral
    let events = PassthroughSubject<BLEEvent, Never>()

    private var controlChar: CBCharacteristic?
    private var pendingWrite: Data?

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self   // each connection is its own delegate
    }

    func discoverServices() {
        peripheral.discoverServices(GATT.allServices)
    }

    func write(_ data: Data, to uuid: CBUUID) {
        guard let service = peripheral.services?.first(where: { $0.uuid == GATT.Sensor.service }),
              let char = service.characteristics?.first(where: { $0.uuid == uuid })
        else { pendingWrite = data; return }   // queue if not yet discovered
        peripheral.writeValue(data, for: char, type: .withResponse)
    }

    func disconnect() {
        write(GATT.Sensor.stopNotifications, to: GATT.Sensor.control)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEPeripheralConnection: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        peripheral.services?.forEach { service in
            switch service.uuid {
            case GATT.DIS.service:
                peripheral.discoverCharacteristics(GATT.DIS.allCharacteristics, for: service)
            case GATT.Sensor.service:
                peripheral.discoverCharacteristics(
                    [GATT.Sensor.temperature, GATT.Sensor.humidity, GATT.Sensor.control],
                    for: service)
            default: break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        service.characteristics?.forEach { char in
            switch char.uuid {
            case GATT.Sensor.temperature, GATT.Sensor.humidity:
                // Step 1 — subscribe CCCD so iOS accepts incoming notifications
                peripheral.setNotifyValue(true, for: char)

            case GATT.Sensor.control:
                controlChar = char
                // Step 2 — tell ESP32 to start sending (or apply queued write)
                let data = pendingWrite ?? GATT.Sensor.startNotifications
                peripheral.writeValue(data, for: char, type: .withResponse)
                pendingWrite = nil

            case GATT.DIS.manufacturerName,
                 GATT.DIS.modelNumber,
                 GATT.DIS.firmwareRevision,
                 GATT.DIS.hardwareRevision:
                peripheral.readValue(for: char)   // one-time read

            default: break
            }
        }
        events.send(.didUpdateConnectionState(.ready))
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        events.send(.didReceiveData(characteristic.uuid, data))
    }
}
```

---

### `BLECentralManager.swift`

Owns **only** scanning and connection lifecycle. Per-device state and
`CBPeripheralDelegate` have moved to `BLEPeripheralConnection`.
Holds a dictionary of active connections keyed by peripheral UUID.

```swift
import CoreBluetooth
import Combine

// Events emitted upward to repositories
enum BLEEvent {
    case didDiscoverPeripheral(CBPeripheral, rssi: Int)
    case didConnect(CBPeripheral)
    case didDisconnect(CBPeripheral)
    case didReceiveData(CBUUID, Data)       // characteristic UUID + raw bytes
    case didUpdateConnectionState(ConnectionState)
}

final class BLECentralManager: NSObject {

    // Repositories subscribe to this
    let events = PassthroughSubject<BLEEvent, Never>()

    // One entry per connected device — repositories access via this dictionary
    private(set) var connections: [UUID: BLEPeripheralConnection] = [:]

    private var central: CBCentralManager!

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func startScanning() {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [GATT.Sensor.service])
        events.send(.didUpdateConnectionState(.scanning))
    }

    func connect(_ peripheral: CBPeripheral) {
        central.stopScan()
        central.connect(peripheral)
        events.send(.didUpdateConnectionState(.connecting))
    }

    func disconnect(_ peripheral: CBPeripheral) {
        connections[peripheral.identifier]?.disconnect()
        central.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLECentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state: ConnectionState = central.state == .poweredOn ? .idle : .disconnected
        events.send(.didUpdateConnectionState(state))
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        events.send(.didDiscoverPeripheral(peripheral, rssi: RSSI.intValue))
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        // Create one BLEPeripheralConnection per device — it becomes the CBPeripheralDelegate
        let connection = BLEPeripheralConnection(peripheral: peripheral)
        connections[peripheral.identifier] = connection
        connection.discoverServices()
        events.send(.didConnect(peripheral))
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connections.removeValue(forKey: peripheral.identifier)
        events.send(.didDisconnect(peripheral))
        events.send(.didUpdateConnectionState(.disconnected))
        // Auto-reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.connect(peripheral)
        }
    }
}
// CBPeripheralDelegate is now handled by BLEPeripheralConnection, not here
```

---

## 6. Domain Layer — Protocols and Models

### `Models/ConnectionState.swift`

```swift
enum ConnectionState {
    case idle
    case scanning
    case connecting
    case discoveringServices
    case ready
    case disconnected
}
```

### `Models/SensorReading.swift`

```swift
import Foundation

struct SensorReading: Equatable {
    let temperature: Double   // °C
    let humidity: Double      // % RH
    let timestamp: Date
}
```

### `Models/DeviceInfo.swift`

```swift
struct DeviceInfo: Equatable {
    var manufacturerName: String = "--"
    var modelNumber:      String = "--"
    var firmwareRevision: String = "--"
    var hardwareRevision: String = "--"
}
```

### `Models/BLEDevice.swift`

```swift
import CoreBluetooth

struct BLEDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id
    }
}
```

---

### Repository Protocols

```swift
// BLEScanRepository.swift
import Combine

protocol BLEScanRepository {
    var devices: AnyPublisher<[BLEDevice], Never> { get }
    func startScanning()
    func connect(to device: BLEDevice)
}

// BLESensorRepository.swift
import Combine

protocol BLESensorRepository {
    var readings: AnyPublisher<SensorReading, Never> { get }
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
}

// BLEDeviceInfoRepository.swift
import Combine

protocol BLEDeviceInfoRepository {
    var deviceInfo: AnyPublisher<DeviceInfo, Never> { get }
}

// BLEControlRepository.swift
protocol BLEControlRepository {
    func startNotifications()
    func stopNotifications()
    func disconnect()
}
```

---

## 7. Repository Layer — Implementations

### `BLESensorRepositoryImpl.swift`

```swift
import Combine
import CoreBluetooth

final class BLESensorRepositoryImpl: BLESensorRepository {

    private let connection: BLEPeripheralConnection   // specific device, not the central
    private var cancellables = Set<AnyCancellable>()

    private let readingsSubject     = PassthroughSubject<SensorReading, Never>()
    private let connectionSubject   = CurrentValueSubject<ConnectionState, Never>(.idle)

    private var latestTemp: Double = 0
    private var latestHum:  Double = 0

    var readings: AnyPublisher<SensorReading, Never> {
        readingsSubject.eraseToAnyPublisher()
    }

    var connectionState: AnyPublisher<ConnectionState, Never> {
        connectionSubject.eraseToAnyPublisher()
    }

    init(connection: BLEPeripheralConnection) {
        self.connection = connection
        bindEvents()
    }

    private func bindEvents() {
        connection.events
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .didReceiveData(let uuid, let data):
                    self.handleData(uuid: uuid, data: data)

                case .didUpdateConnectionState(let state):
                    self.connectionSubject.send(state)

                default: break
                }
            }
            .store(in: &cancellables)
    }

    private func handleData(uuid: CBUUID, data: Data) {
        switch uuid {
        case GATT.Sensor.temperature:
            guard let temp = BLEDecoder.decodeTemperature(data) else { return }
            latestTemp = temp
            readingsSubject.send(SensorReading(
                temperature: latestTemp,
                humidity: latestHum,
                timestamp: Date()
            ))

        case GATT.Sensor.humidity:
            guard let hum = BLEDecoder.decodeHumidity(data) else { return }
            latestHum = hum
            readingsSubject.send(SensorReading(
                temperature: latestTemp,
                humidity: latestHum,
                timestamp: Date()
            ))

        default: break
        }
    }
}
```

### `BLEDeviceInfoRepositoryImpl.swift`

```swift
import Combine

final class BLEDeviceInfoRepositoryImpl: BLEDeviceInfoRepository {

    private let connection: BLEPeripheralConnection   // specific device, not the central
    private var cancellables = Set<AnyCancellable>()

    private let infoSubject = CurrentValueSubject<DeviceInfo, Never>(DeviceInfo())

    var deviceInfo: AnyPublisher<DeviceInfo, Never> {
        infoSubject.eraseToAnyPublisher()
    }

    init(connection: BLEPeripheralConnection) {
        self.connection = connection
        bindEvents()
    }

    private func bindEvents() {
        connection.events
            .sink { [weak self] event in
                guard let self,
                      case .didReceiveData(let uuid, let data) = event,
                      let str = BLEDecoder.decodeString(data)
                else { return }

                var info = self.infoSubject.value
                switch uuid {
                case GATT.DIS.manufacturerName: info.manufacturerName = str
                case GATT.DIS.modelNumber:      info.modelNumber      = str
                case GATT.DIS.firmwareRevision: info.firmwareRevision = str
                case GATT.DIS.hardwareRevision: info.hardwareRevision = str
                default: return
                }
                self.infoSubject.send(info)
            }
            .store(in: &cancellables)
    }
}
```

### `BLEScanRepositoryImpl.swift`

```swift
import Combine
import CoreBluetooth

final class BLEScanRepositoryImpl: BLEScanRepository {

    private let central: BLECentralManager
    private var cancellables = Set<AnyCancellable>()
    private let devicesSubject = CurrentValueSubject<[BLEDevice], Never>([])

    var devices: AnyPublisher<[BLEDevice], Never> {
        devicesSubject.eraseToAnyPublisher()
    }

    init(central: BLECentralManager) {
        self.central = central
        bindEvents()
    }

    func startScanning() {
        devicesSubject.send([])
        central.startScanning()
    }

    func connect(to device: BLEDevice) {
        central.connect(device.peripheral)
    }

    private func bindEvents() {
        central.events
            .sink { [weak self] event in
                guard let self,
                      case .didDiscoverPeripheral(let peripheral, let rssi) = event
                else { return }

                let device = BLEDevice(
                    id: peripheral.identifier,
                    name: peripheral.name ?? "Unknown",
                    rssi: rssi,
                    peripheral: peripheral
                )
                var current = self.devicesSubject.value
                if !current.contains(where: { $0.id == device.id }) {
                    current.append(device)
                    self.devicesSubject.send(current)
                }
            }
            .store(in: &cancellables)
    }
}
```

### `BLEControlRepositoryImpl.swift`

```swift
final class BLEControlRepositoryImpl: BLEControlRepository {

    private let connection: BLEPeripheralConnection   // specific device, not the central

    init(connection: BLEPeripheralConnection) {
        self.connection = connection
    }

    func startNotifications() {
        connection.write(GATT.Sensor.startNotifications, to: GATT.Sensor.control)
    }

    func stopNotifications() {
        connection.write(GATT.Sensor.stopNotifications, to: GATT.Sensor.control)
    }

    func disconnect() {
        connection.disconnect()
    }
}
```

---

## 8. ViewModel Layer

### `ScanViewModel.swift`

```swift
import Combine
import Foundation

final class ScanViewModel: ObservableObject {

    @Published var devices: [BLEDevice] = []
    @Published var isScanning = false

    private let repository: BLEScanRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: BLEScanRepository) {
        self.repository = repository
        repository.devices
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)
    }

    func startScanning() {
        isScanning = true
        repository.startScanning()
    }

    func select(_ device: BLEDevice) {
        repository.connect(to: device)
    }
}
```

### `DashboardViewModel.swift`

```swift
import Combine
import Foundation

final class DashboardViewModel: ObservableObject {

    @Published var formattedTemperature = "--"
    @Published var formattedHumidity    = "--"
    @Published var lastUpdated          = "--"
    @Published var connectionState: ConnectionState = .idle

    private let sensorRepository: BLESensorRepository
    private var cancellables = Set<AnyCancellable>()

    init(sensorRepository: BLESensorRepository) {
        self.sensorRepository = sensorRepository
        bindReadings()
        bindConnectionState()
    }

    private func bindReadings() {
        sensorRepository.readings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                self?.formattedTemperature = String(format: "%.1f °C", reading.temperature)
                self?.formattedHumidity    = String(format: "%.1f %%", reading.humidity)
                self?.lastUpdated          = reading.timestamp.formatted(date: .omitted, time: .standard)
            }
            .store(in: &cancellables)
    }

    private func bindConnectionState() {
        sensorRepository.connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }
}
```

### `DeviceInfoViewModel.swift`

```swift
import Combine

final class DeviceInfoViewModel: ObservableObject {

    @Published var deviceInfo = DeviceInfo()

    private let repository: BLEDeviceInfoRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: BLEDeviceInfoRepository) {
        self.repository = repository
        repository.deviceInfo
            .receive(on: DispatchQueue.main)
            .assign(to: &$deviceInfo)
            .store(in: &cancellables)
    }
}
```

### `ControlViewModel.swift`

```swift
import Combine

final class ControlViewModel: ObservableObject {

    @Published var isNotifying = false

    private let repository: BLEControlRepository

    init(repository: BLEControlRepository) {
        self.repository = repository
    }

    func toggleNotifications() {
        isNotifying ? repository.stopNotifications()
                    : repository.startNotifications()
        isNotifying.toggle()
    }

    func disconnect() {
        repository.stopNotifications()
        repository.disconnect()
    }
}
```

---

## 9. View Layer — SwiftUI

Views only read `@Published` properties and call ViewModel methods. No logic, no BLE imports.

### `ScanView.swift`

```swift
import SwiftUI

struct ScanView: View {

    @StateObject var viewModel: ScanViewModel
    @State private var navigate = false

    var body: some View {
        NavigationStack {
            List(viewModel.devices) { device in
                Button {
                    viewModel.select(device)
                    navigate = true
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text("RSSI: \(device.rssi) dBm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.devices.isEmpty {
                    ContentUnavailableView(
                        "Scanning…",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                }
            }
            .navigationTitle("Find Device")
            .toolbar {
                ToolbarItem {
                    Button("Scan") { viewModel.startScanning() }
                        .disabled(viewModel.isScanning)
                }
            }
            .navigationDestination(isPresented: $navigate) {
                // inject DashboardView from AppDependencies
            }
        }
        .onAppear { viewModel.startScanning() }
    }
}
```

### `DashboardView.swift`

```swift
import SwiftUI

struct DashboardView: View {

    @StateObject var viewModel: DashboardViewModel

    var body: some View {
        List {
            Section("Connection") {
                HStack {
                    Circle()
                        .fill(viewModel.connectionState == .ready ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text(viewModel.connectionState.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sensor Data") {
                LabeledContent("Temperature", value: viewModel.formattedTemperature)
                LabeledContent("Humidity",    value: viewModel.formattedHumidity)
                LabeledContent("Updated",     value: viewModel.lastUpdated)
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
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
        }
    }
}
```

### `DeviceInfoView.swift`

```swift
import SwiftUI

struct DeviceInfoView: View {

    @StateObject var viewModel: DeviceInfoViewModel

    var body: some View {
        List {
            Section("Device Information") {
                LabeledContent("Manufacturer", value: viewModel.deviceInfo.manufacturerName)
                LabeledContent("Model",        value: viewModel.deviceInfo.modelNumber)
                LabeledContent("Firmware",     value: viewModel.deviceInfo.firmwareRevision)
                LabeledContent("Hardware",     value: viewModel.deviceInfo.hardwareRevision)
            }
        }
        .navigationTitle("Device Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

### `ControlView.swift`

```swift
import SwiftUI

struct ControlView: View {

    @StateObject var viewModel: ControlViewModel

    var body: some View {
        List {
            Section("Notifications") {
                Button {
                    viewModel.toggleNotifications()
                } label: {
                    Label(
                        viewModel.isNotifying ? "Stop Notifications" : "Start Notifications",
                        systemImage: viewModel.isNotifying ? "bell.slash" : "bell"
                    )
                }
            }

            Section {
                Button("Disconnect", role: .destructive) {
                    viewModel.disconnect()
                }
            }
        }
        .navigationTitle("Controls")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

---

## 10. App Entry Point and DI Wiring

This is the **only** place in the app where concrete types are instantiated.
All other code depends on protocols.

### `AppDependencies.swift`

```swift
import Combine
import Foundation

final class AppDependencies {

    // Single shared BLECentralManager — one CBCentralManager for the whole app
    let centralManager = BLECentralManager()
    private var cancellables = Set<AnyCancellable>()

    // Scan is global — one repository shared across all devices
    lazy var scanRepository: BLEScanRepository =
        BLEScanRepositoryImpl(central: centralManager)

    // Per-device repositories — keyed by peripheral UUID
    private var sensorRepos:     [UUID: BLESensorRepository]     = [:]
    private var deviceInfoRepos: [UUID: BLEDeviceInfoRepository] = [:]
    private var controlRepos:    [UUID: BLEControlRepository]    = [:]

    init() {
        // Auto-create repositories when a device connects, destroy on disconnect
        centralManager.events
            .sink { [weak self] event in
                switch event {
                case .didConnect(let peripheral):
                    self?.makeDeviceRepositories(for: peripheral.identifier)
                case .didDisconnect(let peripheral):
                    self?.removeDeviceRepositories(for: peripheral.identifier)
                default: break
                }
            }
            .store(in: &cancellables)
    }

    private func makeDeviceRepositories(for id: UUID) {
        guard let connection = centralManager.connections[id] else { return }
        sensorRepos[id]     = BLESensorRepositoryImpl(connection: connection)
        deviceInfoRepos[id] = BLEDeviceInfoRepositoryImpl(connection: connection)
        controlRepos[id]    = BLEControlRepositoryImpl(connection: connection)
    }

    private func removeDeviceRepositories(for id: UUID) {
        sensorRepos.removeValue(forKey: id)
        deviceInfoRepos.removeValue(forKey: id)
        controlRepos.removeValue(forKey: id)
    }

    // ViewModels — scan is shared, all others are per-device
    func makeScanViewModel() -> ScanViewModel {
        ScanViewModel(repository: scanRepository)
    }
    func makeDashboardViewModel(for id: UUID) -> DashboardViewModel {
        DashboardViewModel(sensorRepository: sensorRepos[id]!)
    }
    func makeDeviceInfoViewModel(for id: UUID) -> DeviceInfoViewModel {
        DeviceInfoViewModel(repository: deviceInfoRepos[id]!)
    }
    func makeControlViewModel(for id: UUID) -> ControlViewModel {
        ControlViewModel(repository: controlRepos[id]!)
    }
}
```

### `ESP32SensorApp.swift`

```swift
import SwiftUI

@main
struct ESP32SensorApp: App {

    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ScanView(viewModel: dependencies.makeScanViewModel())
        }
    }
}
```

---

## 11. Mocks for Previews and Tests

```swift
// MockBLESensorRepository.swift
import Combine
import Foundation

final class MockBLESensorRepository: BLESensorRepository {

    var readings: AnyPublisher<SensorReading, Never> {
        Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .map { _ in
                SensorReading(
                    temperature: Double.random(in: 20...30),
                    humidity: Double.random(in: 40...80),
                    timestamp: Date()
                )
            }
            .eraseToAnyPublisher()
    }

    var connectionState: AnyPublisher<ConnectionState, Never> {
        Just(.ready).eraseToAnyPublisher()
    }
}

// MockBLEControlRepository.swift
final class MockBLEControlRepository: BLEControlRepository {
    func startNotifications() {}
    func stopNotifications()  {}
    func disconnect()         {}
}

// MockBLEDeviceInfoRepository.swift
import Combine

final class MockBLEDeviceInfoRepository: BLEDeviceInfoRepository {
    var deviceInfo: AnyPublisher<DeviceInfo, Never> {
        Just(DeviceInfo(
            manufacturerName: "YourCompany",
            modelNumber:      "ESP32-DEV-001",
            firmwareRevision: "1.0.0",
            hardwareRevision: "ESP32-DEVKIT-V1"
        )).eraseToAnyPublisher()
    }
}
```

### Using mocks in SwiftUI Previews

```swift
#Preview {
    DashboardView(
        viewModel: DashboardViewModel(
            sensorRepository: MockBLESensorRepository()
        )
    )
}
```

---

## 12. Startup Sequence

The exact order of operations after a connection is established.
Deviating from this order results in a connected device that sends no data.

```
1. centralManager.connect(peripheral)                          ← BLECentralManager
      │
2. didConnect → BLEPeripheralConnection created               ← BLECentralManager
               → connection.discoverServices([DIS, Sensor])   ← BLEPeripheralConnection
      │
      ↓  All steps below execute inside BLEPeripheralConnection (CBPeripheralDelegate)
      │
3. didDiscoverServices → discoverCharacteristics for each service
      │
4. didDiscoverCharacteristics (Sensor service)
      ├── setNotifyValue(true) on Temperature char  ← iOS subscribes CCCD
      ├── setNotifyValue(true) on Humidity char     ← iOS subscribes CCCD
      └── writeValue(01 00) to Control char         ← ESP32 starts sending
      │
5. didDiscoverCharacteristics (DIS service)
      └── readValue() on all 4 DIS characteristics  ← one-time metadata fetch
      │
6. connectionState → .ready  (events.send via BLEPeripheralConnection)
      │
7. didUpdateValueFor (Temperature)  →  events.send(.didReceiveData)  →  BLESensorRepositoryImpl  →  BLEDecoder.decodeTemperature()  →  publisher
8. didUpdateValueFor (Humidity)     →  events.send(.didReceiveData)  →  BLESensorRepositoryImpl  →  BLEDecoder.decodeHumidity()     →  publisher
9. didUpdateValueFor (DIS chars)    →  events.send(.didReceiveData)  →  BLEDeviceInfoRepositoryImpl  →  BLEDecoder.decodeString()    →  publisher
```

> `Info.plist` requirement — add this key or the app will crash silently on first BLE access:
> ```xml
> <key>NSBluetoothAlwaysUsageDescription</key>
> <string>This app communicates with your ESP32 sensor device via Bluetooth.</string>
> ```
