# iOS App - Getting Started

## Prerequisites

- macOS 14.0+ (Sonoma or later)
- Xcode 16.0+ with iOS 17.0+ SDK
- Apple Developer Account (for device testing and TestFlight)
- CocoaPods or Swift Package Manager
- Command Line Tools: `xcode-select --install`

## Project Structure

```
ios/
├── Zariz/
│   ├── App/                 # App entry point
│   ├── Features/
│   │   ├── Auth/           # Authentication flow
│   │   ├── Orders/         # Order list and details
│   │   └── Notifications/  # Push notifications
│   ├── Core/
│   │   ├── Network/        # API client
│   │   ├── Storage/        # SwiftData models
│   │   └── Security/       # Keychain wrapper
│   └── Resources/          # Assets, Info.plist
├── ZarizTests/
└── Zariz.xcodeproj
```

## Setup

### 1. Clone and Open Project

```bash
cd /Users/sasha/IdeaProjects/ios/zariz/ios
open Zariz.xcodeproj
```

### 2. Configure Bundle Identifier

1. Select project in Xcode navigator
2. Select "Zariz" target
3. Update Bundle Identifier: `com.yourteam.zariz`
4. Select your Team in Signing & Capabilities

### 3. Configure Backend URL

Edit `Zariz/Core/Network/APIConfig.swift`:

```swift
enum APIConfig {
    static let baseURL = "https://your-backend-url.com/api/v1"
    // For local development:
    // static let baseURL = "http://localhost:8000/api/v1"
}
```

### 4. Setup Push Notifications

1. Enable Push Notifications capability in Xcode
2. Enable Background Modes → Remote notifications
3. Download APNs Auth Key (.p8) from Apple Developer Portal
4. Add to backend configuration (see backend setup)

### 5. Install Dependencies

If using Swift Package Manager (recommended):
- Dependencies are auto-resolved on build

If using CocoaPods:
```bash
cd ios
pod install
open Zariz.xcworkspace  # Use workspace, not xcodeproj
```

## Build & Run

### Simulator

```bash
# List available simulators
xcrun simctl list devices

# Build and run
xcodebuild -project Zariz.xcodeproj \
  -scheme Zariz \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build

# Or use Xcode: Cmd+R
```

### Physical Device

1. Connect iPhone via USB
2. Select device in Xcode toolbar
3. Trust computer on device
4. Press Cmd+R to build and run

**Note**: Push notifications only work on physical devices, not simulator.

## CLI Build Commands

### Build for Testing

```bash
xcodebuild clean build \
  -project Zariz.xcodeproj \
  -scheme Zariz \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Run Tests

```bash
xcodebuild test \
  -project Zariz.xcodeproj \
  -scheme Zariz \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -resultBundlePath TestResults.xcresult
```

### Build Archive (for TestFlight/App Store)

```bash
xcodebuild archive \
  -project Zariz.xcodeproj \
  -scheme Zariz \
  -configuration Release \
  -archivePath build/Zariz.xcarchive

xcodebuild -exportArchive \
  -archivePath build/Zariz.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

## Using Fastlane (Recommended)

### Install Fastlane

```bash
# Using Bundler (recommended)
cd ios
bundle init
echo 'gem "fastlane"' >> Gemfile
bundle install

# Or using Homebrew
brew install fastlane
```

### Initialize Fastlane

```bash
cd ios
fastlane init
```

### Common Fastlane Commands

```bash
# Run tests
fastlane test

# Build for testing
fastlane build

# Upload to TestFlight
fastlane beta

# Release to App Store
fastlane release

# Run SwiftLint
fastlane lint
```

### Example Fastfile

```ruby
default_platform(:ios)

platform :ios do
  desc "Run tests"
  lane :test do
    run_tests(scheme: "Zariz")
  end

  desc "Build app"
  lane :build do
    build_app(scheme: "Zariz")
  end

  desc "Upload to TestFlight"
  lane :beta do
    increment_build_number
    build_app(scheme: "Zariz")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```

## Code Quality Tools

### SwiftLint

```bash
# Install
brew install swiftlint

# Run manually
swiftlint

# Auto-fix
swiftlint --fix

# Add to Xcode Build Phase:
# New Run Script Phase: swiftlint
```

### SwiftFormat

```bash
# Install
brew install swiftformat

# Format all files
swiftformat .

# Check without modifying
swiftformat --lint .
```

## Debugging

### View Logs

```bash
# Real-time device logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "app.zariz"'

# Or use Console.app and filter by "zariz"
```

### Instruments

```bash
# Profile performance
instruments -t "Time Profiler" -D trace.trace build/Zariz.app

# Memory leaks
instruments -t "Leaks" -D leaks.trace build/Zariz.app
```

### Network Debugging

Enable in `APIClient.swift`:
```swift
let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [LoggingURLProtocol.self]
```

## Testing

### Unit Tests

```bash
# Run all tests
xcodebuild test -scheme Zariz -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test
xcodebuild test -scheme Zariz -only-testing:ZarizTests/OrderViewModelTests
```

### UI Tests

```bash
xcodebuild test -scheme ZarizUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Snapshot Tests

```swift
// Add to test
assertSnapshot(matching: view, as: .image)
```

## Troubleshooting

### Code Signing Issues

```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset signing
fastlane match nuke development
fastlane match development
```

### Build Errors

```bash
# Clean build folder
xcodebuild clean -project Zariz.xcodeproj -scheme Zariz

# Reset package cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build
```

### Simulator Issues

```bash
# Reset simulator
xcrun simctl erase all

# Restart CoreSimulator
killall -9 com.apple.CoreSimulator.CoreSimulatorService
```

## Environment Configuration

### Debug vs Release

Create `Config.xcconfig` files:

**Debug.xcconfig**:
```
API_BASE_URL = http:/\/localhost:8000
ENABLE_LOGGING = YES
```

**Release.xcconfig**:
```
API_BASE_URL = https:/\/api.zariz.com
ENABLE_LOGGING = NO
```

Access in code:
```swift
let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as! String
```

## CI/CD Integration

### GitHub Actions

See `.github/workflows/ios.yml`:

```yaml
name: iOS CI
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: xcodebuild build -scheme Zariz
      - name: Test
        run: xcodebuild test -scheme Zariz
```

### Automated TestFlight

```bash
# Setup App Store Connect API Key
export APP_STORE_CONNECT_API_KEY_PATH=~/AuthKey.p8

# Upload via fastlane
fastlane beta
```

## Performance Targets

- Cold start: < 2 seconds
- List load: < 700ms (p95)
- Memory usage: < 200 MB
- Frame rate: 60 fps (16ms per frame)

## Security Checklist

- [ ] JWT tokens stored in Keychain
- [ ] Biometric authentication enabled
- [ ] ATS (App Transport Security) enforced
- [ ] No sensitive data in logs
- [ ] Certificate pinning (optional)
- [ ] Obfuscated API keys

## Next Steps

1. Configure backend URL
2. Setup Apple Developer account
3. Enable push notifications
4. Run on device
5. Test offline mode
6. Upload to TestFlight

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Fastlane Docs](https://docs.fastlane.tools/)
- [SwiftData Guide](https://developer.apple.com/documentation/swiftdata)
