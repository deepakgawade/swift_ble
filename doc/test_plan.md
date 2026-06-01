# Test Plan

## Architecture Overview

```
Domain/           ← pure models & protocols
Data/             ← BLEDecoder, repos (BLE + Network)
ViewModels/       ← ScanViewModel, DashBoardViewModel, BookViewModel
Views/            ← SwiftUI views (tested last)
```

No test target exists yet — add a Unit Test target (`harryTests`) and optionally a UI Test target (`harryUITests`) in Xcode before writing tests.

---

## Layer 1: Domain (Pure Logic — no mocks needed)

### BLEDecoderTests

| Test | Input | Expected |
|---|---|---|
| Temperature valid | `[0xEB, 0x00]` | `23.5` |
| Temperature negative | `[0xFF, 0xFF]` | `-0.1` |
| Temperature too short | `[0xEB]` | `nil` |
| Humidity valid | `[0x26, 0x02]` | `55.0` |
| Humidity too short | `[0x26]` | `nil` |
| Decode UTF-8 string | `"Hello"` bytes | `"Hello"` |
| `encodeControl(true)` | — | `GATT.Sensor.startSensor` |
| `encodeControl(false)` | — | `GATT.Sensor.stopSensor` |

### BookMapperTests

- All fields map correctly from `BookDTO` → `Book`
- `id` = `String(dto.number)`

---

## Layer 2: Data (Mock URLSession / no real hardware)

### RemoteBookRepositoryTests — using `MockURLProtocol`

- 200 + valid JSON → returns correct `Book`
- Non-200 response → throws `URLError(.badServerResponse)`
- Malformed JSON → throws `DecodingError`
- Network error → propagates error

> `BLEScanRepoImpl` and `BLESensorRepoImpl` wrap `BLECentralManager` / `CBPeripheral` which require real hardware. Skip unit-testing those directly; they are covered indirectly through ViewModel mock tests.

---

## Layer 3: ViewModels (Mock Repositories via protocols)

### Mock objects to write

- `MockBookRepository: BookRepository`
- `MockBLEScanRepository: BLEScanRepository`
- `MockBLESensorRepository: BLESensorRepository`

### BookViewModelTests

- `loadBook()` success → `book` set, `isLoading = false`, `errorMessage = nil`
- `loadBook()` failure → `errorMessage` set, `book = nil`, `isLoading = false`
- `isLoading` is `true` during fetch, `false` after
- `refresh()` triggers a new fetch

### ScanViewModelTests

- Initial state: `devices = []`, `connectingID = nil`, `navigateTo = nil`
- `startScan()` → calls `repository.startScanning()`
- `select(device)` → `connectingID = device.id`, `connectingState = .connecting`
- Repo emits a `.connected` device → `navigateTo` set, `connectingState = .connected`
- `resetConnecting()` → all state cleared back to idle/nil

### DashBoardViewModelTests

- `toogelNotify()` when off → calls `startNotification()`, `isNotifyEnabled = true`
- `toogelNotify()` when on → calls `stopNotification()`, `isNotifyEnabled = false`
- `disconnect()` → fires `onDisconnect` callback
- Readings arrive → `formattedTemperature = "23.5 °C"`, `formattedHumidity = "55.0 %"`
- Connection state changes → `connectionState` updated

---

## Layer 4: Views (Tested last)

### Approach options

| Option | Approach | Tradeoff |
|---|---|---|
| **XCUITest** | Apple's UI test runner, no extra libraries | Black-box only, slower |
| **ViewInspector** | SPM library, unit-style view inspection | Requires small view changes (`Inspectable`) |

### Coverage (per view: ScanView, DashBoardView, BookView)

- Loading state renders correctly
- Data-filled state renders correctly
- Error/empty state renders correctly

---

## File Plan

```
harryTests/
  Domain/
    BLEDecoderTests.swift
    BookMapperTests.swift
  Data/
    MockURLProtocol.swift
    RemoteBookRepositoryTests.swift
  Mocks/
    MockBookRepository.swift
    MockBLEScanRepository.swift
    MockBLESensorRepository.swift
  ViewModels/
    BookViewModelTests.swift
    ScanViewModelTests.swift
    DashBoardViewModelTests.swift
harryUITests/
  BookViewUITests.swift
  ScanViewUITests.swift
  DashBoardViewUITests.swift
```
