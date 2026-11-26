import Foundation
import simd

struct MeshMeasurements {
    let surfaceAreaSquareMeters: Double
    let signedVolumeCubicMeters: Double

    var volumeCubicMeters: Double { abs(signedVolumeCubicMeters) }

    static func calculate(_ mesh: ScanMesh) -> MeshMeasurements {
        var area: Double = 0
        var volume: Double = 0
        guard mesh.faces.count >= 3 else {
            return MeshMeasurements(surfaceAreaSquareMeters: 0, signedVolumeCubicMeters: 0)
        }

        for offset in stride(from: 0, to: mesh.faces.count - 2, by: 3) {
            let ia = Int(mesh.faces[offset])
            let ib = Int(mesh.faces[offset + 1])
            let ic = Int(mesh.faces[offset + 2])
            guard ia < mesh.vertices.count, ib < mesh.vertices.count, ic < mesh.vertices.count else { continue }
            let a = mesh.vertices[ia]
            let b = mesh.vertices[ib]
            let c = mesh.vertices[ic]
            let cross = simd_cross(b - a, c - a)
            area += Double(simd_length(cross)) * 0.5
            volume += Double(simd_dot(a, simd_cross(b, c))) / 6.0
        }
        return MeshMeasurements(surfaceAreaSquareMeters: area, signedVolumeCubicMeters: volume)
    }

    static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double {
        Double(simd_distance(a, b))
    }
}

enum MeshSimplifier {
    private struct Voxel: Hashable {
        let x: Int
        let y: Int
        let z: Int
    }

    static func simplify(_ mesh: ScanMesh, voxelSize: Float) -> ScanMesh {
        guard mesh.vertices.count > 4, voxelSize > 0 else { return mesh }

        var sums: [Voxel: SIMD3<Float>] = [:]
        var colorSums: [Voxel: SIMD4<Float>] = [:]
        var counts: [Voxel: Int] = [:]
        var oldKeys: [Voxel] = []
        oldKeys.reserveCapacity(mesh.vertices.count)

        for (index, point) in mesh.vertices.enumerated() {
            let key = Voxel(
                x: Int(floor(point.x / voxelSize)),
                y: Int(floor(point.y / voxelSize)),
                z: Int(floor(point.z / voxelSize))
            )
            oldKeys.append(key)
            sums[key, default: .zero] += point
            if mesh.hasColors { colorSums[key, default: .zero] += mesh.colors[index] }
            counts[key, default: 0] += 1
        }

        var newIndices: [Voxel: UInt32] = [:]
        var vertices: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []
        vertices.reserveCapacity(sums.count)
        for key in sums.keys.sorted(by: {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }) {
            let count = Float(counts[key, default: 1])
            newIndices[key] = UInt32(vertices.count)
            vertices.append(sums[key, default: .zero] / count)
            if mesh.hasColors { colors.append(colorSums[key, default: .zero] / count) }
        }

        var faces: [UInt32] = []
        faces.reserveCapacity(mesh.faces.count)
        var seen = Set<String>()
        for offset in stride(from: 0, to: mesh.faces.count - 2, by: 3) {
            let oldA = Int(mesh.faces[offset])
            let oldB = Int(mesh.faces[offset + 1])
            let oldC = Int(mesh.faces[offset + 2])
            guard oldA < oldKeys.count, oldB < oldKeys.count, oldC < oldKeys.count,
                  let a = newIndices[oldKeys[oldA]],
                  let b = newIndices[oldKeys[oldB]],
                  let c = newIndices[oldKeys[oldC]],
                  a != b, b != c, a != c else { continue }
            let sorted = [a, b, c].sorted()
            let key = "\(sorted[0])-\(sorted[1])-\(sorted[2])"
            guard seen.insert(key).inserted else { continue }
            faces.append(contentsOf: [a, b, c])
        }

        return ScanMesh(vertices: vertices, faces: faces, colors: colors)
    }
}
