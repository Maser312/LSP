# LiDAR Scanner Pro

Native iOS LiDAR scanning application built with SwiftUI, ARKit and RealityKit/SceneKit.

## Project status

Initial native application foundation. The first milestone focuses on reliable LiDAR mesh capture, live preview, project metadata and PLY export. Additional export formats and editing tools are added in subsequent milestones.

## Requirements

- iPhone or iPad with a LiDAR scanner
- iOS 17.0 or later
- Xcode 16 or later
- XcodeGen (`brew install xcodegen`)

## Build

```bash
xcodegen generate
xcodebuild -project LiDARScannerPro.xcodeproj -scheme LiDARScannerPro -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The GitHub Actions workflow builds the unsigned iOS app. A physical LiDAR device is required to test scanning; the iOS Simulator cannot provide real LiDAR mesh data.
