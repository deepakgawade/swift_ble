# Plan: Per-Device Connection State in ScanView + Gated Navigation

## Context

Tapping a device in `ScanView` immediately pushed `DashboardView` before BLE was ready.
`DashBoardViewModel` then waited asynchronously for the repo via `sensorRepoPublisher` — an
`AnyPublisher<BLESensorRepository, Never>` that made the repo optional and deferred binding.

Goal: navigate to Dashboard **only when `ConnectionState == .ready`**, so the repo always exists
at construction time — no async waiting, no optional repo.

**Already done (previous session):**
- `centralManager` made `private` in `AppDependencies`
- `ScanView` dependency changed from `AppDependencies` to `makeDashboard: (UUID) -> DashBoardViewModel`

**Responsibility split:**
- `BLEScanRepository` — owns connect/disconnect (peripheral lifecycle, tracks connected devices)
- `BLESensorRepository` — owns sensor operations only: `readings`, `connectionState`, `startNotification()`, `stopNotification()`. No `disconnect()`.
- `DashBoardViewModel` — receives `BLESensorRepository` for sensor ops + explicit `onDisconnect` closure

---

## Files to Modify (in order)

1. `Domain/Repository/BLESensorRepository.swift` — remove `disconnect()` from protocol
2. `Data/Repositories/BLESensorRepoImpl.swift` — remove `disconnect()` method + `onDisconnect` from init
3. `harry/AppDependencies.swift` — pure factory, no sensorRepos, pass repo + onDisconnect to ViewModel
4. `ViewModels/DashBoardViewModel.swift` — init with `repository` + `onDisconnect`
5. `ViewModels/ScanViewModel.swift` — add `centralEvents`, expose `navigateTo` + `connectingState`
6. `Views/ScanView.swift` — value-based navigation, status indicator per row

**No changes needed:** `BLECentralManager`, `BLEPeripheralConnection`,
`BLEScanRepoImpl`, `BLEScanRepository`, `ConnectionState`, `BLEDevice`, `DashBoardView`

---

## 1. `BLESensorRepository.swift` — data-only protocol

Remove `disconnect()`. Connect/disconnect belongs to `BLEScanRepository`.

```swift
protocol BLESensorRepository {
    var readings: AnyPublisher<SensorData, Never> { get }
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    func startNotification()
    func stopNotification()
}
```

---

## 2. `BLESensorRepoImpl.swift` — remove disconnect

Remove `onDisconnect` from init and delete the `disconnect()` method.

```swift
init(
    connection: BLEPeripheralConnection,
    disconnectSignal: AnyPublisher<ConnectionState, Never>
) {
    self.connection = connection
    bindEvents(disconnectSignal: disconnectSignal)
}
```

---

## 3. `AppDependencies.swift` — pure factory

No `sensorRepos` dict, no `cancellables`, no `init`.
`makeDashboardViewModel` builds the repo on the spot — `centralManager.connections[id]` is
guaranteed because navigation only fires after `.ready` (after `didConnect`).
`onDisconnect` closure is wired directly from `centralManager` and passed explicitly to the ViewModel.

```swift
final class AppDependencies {
    private let centralManager = BLECentralManager()

    lazy var scanRepository: BLEScanRepository = BLEScanRepoImpl(central: centralManager)

    func makeScanViewModel() -> ScanViewModel {
        ScanViewModel(
            repository: scanRepository,
            centralEvents: centralManager.events.eraseToAnyPublisher()
        )
    }

    func makeDashboardViewModel(for id: UUID) -> DashBoardViewModel {
        guard let connection = centralManager.connections[id] else {
            fatalError("No connection for \(id) — unreachable before .ready")
        }
        let disconnectSignal = centralManager.events
            .compactMap { event -> ConnectionState? in
                guard case .didDisconnect(let p) = event, p.identifier == id else { return nil }
                return .disconnected
            }
            .eraseToAnyPublisher()
        let repo = BLESensorRepoImpl(
            connection: connection,
            disconnectSignal: disconnectSignal
        )
        return DashBoardViewModel(
            repository: repo,
            onDisconnect: { [weak self] in self?.centralManager.disconnect(id: id) }
        )
    }
}
```

---

## 4. `DashBoardViewModel.swift` — explicit dependencies

`repository` handles sensor data and notifications.
`onDisconnect` handles peripheral disconnect (routed through `BLECentralManager`).

```swift
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

    func disconnect() { onDisconnect() }

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
```

---

## 5. `ScanViewModel.swift` — own the connect lifecycle

Add `centralEvents` to init. Track connecting device and auto-navigate on `.ready`.

```swift
final class ScanViewModel: ObservableObject {
    @Published var devices: [BLEDevice] = []
    @Published var connectingID: UUID? = nil
    @Published var connectingState: ConnectionState = .idle
    @Published var navigateTo: UUID? = nil

    private let repository: BLEScanRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: BLEScanRepository, centralEvents: AnyPublisher<BLEEvent, Never>) {
        self.repository = repository
        repository.devices
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)
        bindCentralEvents(centralEvents)
    }

    func startScan() { repository.startScanning() }

    func select(_ device: BLEDevice) {
        connectingID = device.id
        connectingState = .connecting
        repository.connect(to: device)
    }

    func resetConnecting() {
        connectingID = nil
        connectingState = .idle
    }

    private func bindCentralEvents(_ events: AnyPublisher<BLEEvent, Never>) {
        events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self,
                      case .didUpdateConnectionState(let state) = event else { return }
                connectingState = state
                if state == .ready, let id = connectingID {
                    navigateTo = id
                }
            }
            .store(in: &cancellables)
    }
}
```

---

## 6. `ScanView.swift` — value-based navigation + per-row status

Remove `@State navigate` and `@State selectedDeviceID`.
Use `.navigationDestination(item:)` — SwiftUI clears `navigateTo` on Back automatically.

```swift
struct ScanView: View {
    @StateObject var viewModel: ScanViewModel
    let makeDashboard: (UUID) -> DashBoardViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.devices) { device in
                Button { viewModel.select(device) } label: {
                    HStack {
                        Image(systemName: "cpu")
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text("RSSI: \(device.rssi) dBm")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if device.id == viewModel.connectingID {
                            connectionIndicator(viewModel.connectingState)
                        }
                    }
                }
                .disabled(viewModel.connectingID != nil && device.id != viewModel.connectingID)
            }
            .overlay {
                if viewModel.devices.isEmpty {
                    ContentUnavailableView("Scanning",
                        systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .navigationTitle("Find Device")
            .toolbar {
                ToolbarItem { Button("Scan") { viewModel.startScan() } }
            }
            .navigationDestination(item: $viewModel.navigateTo) { id in
                DashBoardView(viewModel: makeDashboard(id))
            }
            .onChange(of: viewModel.navigateTo) { _, id in
                if id == nil { viewModel.resetConnecting() }
            }
        }
        .onAppear { viewModel.startScan() }
    }

    @ViewBuilder
    private func connectionIndicator(_ state: ConnectionState) -> some View {
        switch state {
        case .connecting, .discoveringServices:
            ProgressView()
        case .ready:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        default:
            EmptyView()
        }
    }
}
```

---

## State Flow

```
User taps device
  → ScanViewModel.select(_:)  →  connectingID = id, repository.connect(to:)

BLECentralManager fires:
  .connecting          →  row shows ProgressView
  .discoveringServices →  row shows ProgressView
  .ready               →  navigateTo = id  →  SwiftUI pushes DashBoardView

Dashboard opens:
  makeDashboard(id)
    → centralManager.connections[id] exists ✓
    → BLESensorRepoImpl(connection:disconnectSignal:)  — no onDisconnect inside repo
    → DashBoardViewModel(repository: repo, onDisconnect: { centralManager.disconnect(id:) })

User taps Back:
  SwiftUI sets navigateTo = nil  →  onChange  →  resetConnecting()
  DashBoardView.onDisappear  →  viewModel.disconnect()  →  onDisconnect()
  → BLECentralManager.disconnect() — intentional, no auto-reconnect
```

---

## Verification

| Step | Expected |
|------|----------|
| App launches | ScanView, scanning starts |
| Devices appear | List with name + RSSI |
| Tap a device | Row shows spinner; other rows disabled |
| BLE connects | Spinner through Connecting → DiscoveringServices |
| `.ready` fires | Green checkmark briefly, Dashboard pushes automatically |
| Dashboard | Live readings immediately, no `--` loading state |
| Tap Back | `onDisconnect()` fires, no auto-reconnect, indicator cleared |
| Tap device again | Fresh connection cycle, new repo created |
| BLE drops on Dashboard | Shows "Disconnected" via `disconnectSignal` bridge |

---

## Bug Fix: Reconnect shows stale `.idle` state and `--` sensor values

### Symptom

First connection to Dashboard worked correctly. After pressing Back and reconnecting, Dashboard showed `.idle` connection state and `--` for all sensor values — no updates ever arrived.

### Root cause: `@StateObject` swallows the second `DashBoardViewModel`

`DashBoardView` was declared with `@StateObject var viewModel: DashBoardViewModel`. SwiftUI's `@StateObject` only uses the wrapped value **once** — when the view is first inserted into the navigation stack. On every subsequent render while `showDashboard = true`, the `navigationDestination` closure was re-evaluated:

```swift
// WRONG — closure re-evaluates on every render
.navigationDestination(isPresented: $showDashboard) {
    if let device = viewModel.navigateTo {
        DashBoardView(viewModel: makeDashboard(device))  // called every render
    }
}
```

Each render called `makeDashboard(device)`, which created a new `BLESensorRepoImpl` and immediately called `connection.discoverServices()` on it. But `@StateObject` discarded every instance after the first, so:

- The new `BLESensorRepoImpl`'s `cancellables` were released immediately
- Its Combine subscription to `BLEPeripheralConnection.events` was cancelled
- `conn.events` (a `PassthroughSubject`) had **no subscribers** when `.ready` and `.didReceiveData` arrived
- The displayed `DashBoardViewModel` was subscribed to a dead repo → stuck at `.idle` and `--`

### Why `--` and not the previous session's values

`DashBoardViewModel` is initialized with `formattedTemperature = "--"` and `connectionState = .idle`. On the second push, if `@StateObject` gave SwiftUI a fresh instance (as it does after a full dismiss/re-push cycle), those were the initial values. The `.ready` event and sensor readings that followed were emitted to a `PassthroughSubject` with no live subscribers and were silently dropped.

### Fix

Two changes — ownership correction only, no logic changes:

**`DashBoardView.swift`** — `@StateObject` → `@ObservedObject`

`DashBoardViewModel` is created externally by `makeDashboard()`. Externally-owned objects belong with `@ObservedObject`; `@StateObject` is for objects the view creates and owns itself.

**`ScanView.swift`** — move `makeDashboard(device)` out of the `navigationDestination` closure

```swift
// Store the viewModel in @State so it's created exactly once per connection
@State private var dashboardViewModel: DashBoardViewModel?

// Create it once when navigateTo becomes non-nil
.onChange(of: viewModel.navigateTo != nil) { _, isConnected in
    if isConnected, let device = viewModel.navigateTo {
        dashboardViewModel = makeDashboard(device)   // called once
        showDashboard = true
    }
}

// Release it when dismissed
.onChange(of: showDashboard) { _, isShown in
    if !isShown {
        viewModel.resetConnecting()
        dashboardViewModel = nil
    }
}

// Closure just reads the already-created instance — no makeDashboard() call here
.navigationDestination(isPresented: $showDashboard) {
    if let vm = dashboardViewModel {
        DashBoardView(viewModel: vm)
    }
}
```

### Ownership chain after fix

```
ScanView (@State dashboardViewModel)
  └─ DashBoardViewModel
       └─ BLESensorRepoImpl
            ├─ cancellables (subscription to BLEPeripheralConnection.events)
            └─ BLEPeripheralConnection  ←  peripheral.delegate = this
```

The `DashBoardViewModel` and its entire BLE subscription chain live from "device connected" to "dashboard dismissed" — exactly as long as needed.

### Rule to carry forward

> Never call a factory function that has side effects (like `discoverServices()`) inside a `navigationDestination` or `navigationDestination(item:)` closure. SwiftUI re-evaluates those closures on every render. Use `@State` in the parent to hold the result and create it exactly once in `onChange`.
