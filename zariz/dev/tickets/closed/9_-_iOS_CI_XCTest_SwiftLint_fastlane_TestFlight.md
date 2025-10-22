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

Implementation Summary
- Fastlane: `zariz/ios/fastlane/Fastfile` with `test`, `build`, `beta` lanes; Gemfile at `zariz/ios/Gemfile`.
- CI: `.github/workflows/ios.yml` installs XcodeGen, generates project, builds and runs tests on iPhone 15 simulator; SwiftLint optional.
- Lint: SwiftLint config `zariz/ios/.swiftlint.yml`.
- Convenience: `make ios-xcodeproj` to generate project; `zariz/ios/Zariz.xcodeproj` generated locally.

How to Verify
- Local: `cd zariz/ios && bundle install && bundle exec fastlane test` (or `fastlane test`).
- CI: Push/PR triggers `ios-ci` workflow; check build and test logs.
- TestFlight: Configure App Store Connect API key in local fastlane (or GitHub secrets) and run `fastlane beta` locally.

Notes
- Codesigning/upload in CI requires additional secrets and possibly fastlane Match; out of scope for MVP but lanes are ready.

