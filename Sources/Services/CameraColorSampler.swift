import ARKit
import CoreGraphics
import CoreImage
import simd

enum CameraColorSampler {
    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    static func sample(points: [SIMD3<Float>], fallback: [SIMD4<Float>], frame: ARFrame) -> [SIMD4<Float>] {
        guard !points.isEmpty, fallback.count == points.count else { return fallback }
        let pixelBuffer = frame.capturedImage
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return fallback }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height
        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
        defer { pixels.deallocate() }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let bitmap = CGContext(
            data: pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return fallback }

        bitmap.translateBy(x: 0, y: CGFloat(height))
        bitmap.scaleBy(x: 1, y: -1)
        bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let camera = frame.camera
        let cameraFromWorld = simd_inverse(camera.transform)
        let viewport = CGSize(width: width, height: height)
        var result = fallback

        for index in points.indices {
            let point = points[index]
            let cameraPoint = cameraFromWorld * SIMD4<Float>(point.x, point.y, point.z, 1)
            guard cameraPoint.z < 0 else { continue }

            let projected = camera.projectPoint(point, orientation: .landscapeRight, viewportSize: viewport)
            let x = Int(projected.x.rounded())
            let y = Int(projected.y.rounded())
            guard x >= 0, y >= 0, x < width, y < height else { continue }

            let offset = y * bytesPerRow + x * 4
            let alpha = max(Float(pixels[offset + 3]) / 255, 0.001)
            result[index] = SIMD4<Float>(
                min(Float(pixels[offset]) / 255 / alpha, 1),
                min(Float(pixels[offset + 1]) / 255 / alpha, 1),
                min(Float(pixels[offset + 2]) / 255 / alpha, 1),
                1
            )
        }
        return result
    }
}
