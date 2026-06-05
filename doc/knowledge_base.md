# Knowledge Base

## Swift Package Manager (SPM)

This project uses **Swift Package Manager (SPM)** for external dependencies — no CocoaPods or Cartfile setup required. SPM is integrated directly into Xcode.

---

### How to Add a Dependency

1. Open `harry.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies…**
3. Paste the GitHub URL of the package
4. Choose a version rule (e.g. **Up to Next Major**)
5. Click **Add Package**, select the product, and add it to the `harry` target

Xcode automatically updates `harry.xcodeproj/project.pbxproj` with the remote package reference and product dependency.

---

### Example: Adding Alamofire

**URL:** `https://github.com/Alamofire/Alamofire`  
**Version rule:** Up to Next Major from `5.0.0`

After adding, use it in any Swift file:

```swift
import Alamofire

AF.request("https://api.example.com/data").responseJSON { response in
    print(response)
}
```

---

### What Xcode Writes to `project.pbxproj`

```
/* Remote package source */
XCRemoteSwiftPackageReference "Alamofire" = {
    repositoryURL = "https://github.com/Alamofire/Alamofire";
    requirement = { kind = upToNextMajorVersion; minimumVersion = 5.0.0; };
};

/* Linkable product */
XCSwiftPackageProductDependency "Alamofire" = {
    package = XCRemoteSwiftPackageReference "Alamofire";
    productName = Alamofire;
};
```

---

### Where to Find Packages

| Resource | URL | Best For |
|---|---|---|
| Swift Package Index | https://swiftpackageindex.com | Searching by keyword, checking compatibility |
| GitHub | https://github.com | Finding a known library, reading README |
| Awesome Swift | https://github.com/matteocrippa/awesome-swift | Discovering libraries by category |

**Swift Package Index** is the recommended starting point — it shows iOS/macOS compatibility, Swift version support, license, and maintenance status.

---

### BLE-Relevant Packages (for this project)

Since this app uses `CoreBluetooth`, useful higher-level BLE libraries if needed:

- **AsyncBluetooth** — modern async/await BLE wrapper
- **RxBluetoothKit** — RxSwift-based BLE abstraction

Both are available on Swift Package Index.
