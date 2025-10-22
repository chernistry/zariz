Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: iOS CI (XCTest, SwiftLint), fastlane, TestFlight

Objective
- Add basic unit/UI tests, SwiftLint, and GitHub Actions.
- Configure fastlane for TestFlight uploads using App Store Connect API key.

Deliverables
- `Fastfile` with lanes: test, build, beta.
- `.github/workflows/ios.yml` running tests on macOS and optionally building .ipa.
- SwiftLint config and script run step.

Reference-driven accelerators (copy/adapt)
- From DeliveryApp-iOS:
  - Copy `fastlane/` directory to `zariz/ios/fastlane` and update scheme/bundle IDs in `Fastfile`.
  - Copy `Dangerfile` if you want PR linting; optional for MVP.
  - Align `.github/workflows/CI.yml` steps with our `ios.yml` (already seeded in Ticket 1) — ensure correct workspace/scheme.

fastlane
```
cd zariz/ios && bundle init # optional ruby bundler
fastlane init # select manual setup

cat > zariz/ios/Fastfile << 'EOF'
default_platform(:ios)

platform :ios do
  desc "Run tests"
  lane :test do
    scan(scheme: "Zariz")
  end

  desc "Build for TestFlight"
  lane :beta do
    build_app(scheme: "Zariz")
    upload_to_testflight
  end
end
EOF
```

GitHub Actions
```
cat > .github/workflows/ios.yml << 'EOF'
name: ios-ci
on: [push]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Xcode build & test
        run: |
          cd zariz/ios
          xcodebuild -scheme Zariz -destination 'platform=iOS Simulator,name=iPhone 15' test
EOF
```

SwiftLint (optional)
```
brew install swiftlint # locally
echo 'disabled_rules: [trailing_whitespace]' > zariz/ios/.swiftlint.yml
```

App Store Connect API key
- Add `APP_STORE_CONNECT_API_KEY_*` secrets to repo; fastlane uses them for TestFlight.

Verification
- Workflow runs tests; local `fastlane beta` builds and uploads to TestFlight.

Copy/Integrate
```
cp -R zariz/references/DeliveryApp-iOS/fastlane zariz/ios/fastlane || true
cp -f zariz/references/DeliveryApp-iOS/Dangerfile zariz/ios/Dangerfile || true
```

Next
- Scaffold web admin panel in Ticket 10.
