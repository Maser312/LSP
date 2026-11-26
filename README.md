# LiDAR Scanner Pro

Native iOS LiDAR scanning app built with SwiftUI, ARKit, SceneKit, Model I/O and RoomPlan.

## Current feature set

- Live LiDAR mesh reconstruction with semantic classification and camera-derived vertex colors.
- Interactive 3D model viewer with orbit, pan, zoom, wireframe mode and point-to-point measurement.
- Surface area and signed-mesh volume estimates. Volume is meaningful for closed, consistently wound meshes.
- Voxel-based mesh simplification with adjustable cell size.
- Export of arbitrary meshes to PLY, OBJ, STL, GLB and USDZ where the installed iOS Model I/O exporter supports USDZ.
- RoomPlan room capture with recognized walls, doors, windows and objects, plus USDZ export.
- Local project libraries for object scans and RoomPlan rooms, including rendered 3D thumbnails and Quick Look previews.

## Requirements

- iPhone or iPad with LiDAR for mesh capture and RoomPlan.
- iOS 17.0 or later.
- Xcode 16 or later.
- XcodeGen (brew install xcodegen).

## Build

```bash
xcodegen generate
xcodebuild -project LiDARScannerPro.xcodeproj -scheme LiDARScannerPro -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions builds an unsigned iOS app bundle. A physical LiDAR device is required to test capture; the iOS Simulator cannot provide real LiDAR data.

Camera-derived color is stored as per-vertex color. It is not yet a UV-unwrapped photographic texture atlas. Measurement volume is an estimate and requires a watertight mesh for reliable results.
