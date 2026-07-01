---
summary: 'Commander multiplatform support log'
read_when:
  - enabling Commander on additional OS targets
  - modifying Commander CI coverage
---

# Commander Multiplatform Tracking

## Current Status (July 1, 2026)
- **Supported platforms:** macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1.0+ via `Package.swift` declarations; Linux remains unrestricted because SwiftPM only constrains Apple-family targets explicitly. Windows and Android are intentionally unsupported.
- **Portability audit:** Commander exclusively depends on `Foundation` and concurrency features already available in Swift 6, so no conditional compilation was required.
- **Testing coverage:** `CommanderTests` run natively on macOS and Linux. Apple simulator builds validate iOS, tvOS, watchOS, and visionOS. Windows and Android are not part of our CI story.

> ¹ See [Swift Package Manager Platform Support](https://developer.apple.com/documentation/swift_packages/supportedplatform), which documents that only Apple OS minimums are declared in `Package.swift` and other platforms remain unconstrained.

## Implementation Checklist

| Item | Status | Notes |
| --- | --- | --- |
| Declare Apple platform minimums in `Package.swift` | ✅ | Uses `.macOS(.v14)`, `.iOS(.v17)`, `.tvOS(.v17)`, `.watchOS(.v10)`, `.visionOS(.v1)`
| Verify Linux portability of sources/tests | ✅ | Host-only APIs avoided; runs via `swift test --package-path Commander` on Linux
| Validate Apple simulator builds | ✅ | `xcodebuild` uses generic iOS, tvOS, watchOS, and visionOS simulator destinations
| Standalone Commander workflow | ✅ | `.github/workflows/ci.yml` covers macOS, Linux, and iOS/tvOS/watchOS/visionOS simulator builds

## CI Design Highlights
- **macOS host tests:** Run `swift test` on the `macos-15` runner with Swift 6.3.3.
- **Apple simulator builds:** Each matrix entry runs `xcodebuild` against a generic iOS, tvOS, watchOS, or visionOS simulator destination.
- **Linux:** We use `SwiftyLab/setup-swift@v1.14.0` with Ubuntu 24.04 targeting Swift 6.3.3. Windows coverage was dropped, so no WinGet/compnerd steps remain.
## Follow-Ups
1. Expand visionOS coverage beyond compiler smoke tests once Peekaboo formally adopts it in app targets.
2. Expand the test suite with parser edge cases so non-macOS runs provide more value.
3. Publish a reusable GitHub Actions composite to share these steps with Tachikoma/PeekabooCore once Commander graduates to its own repository.
