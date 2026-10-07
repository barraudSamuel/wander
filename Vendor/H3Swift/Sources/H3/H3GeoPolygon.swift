import Ch3

/// A geographic polygon used as input to H3's polyfill operation.
///
/// Coordinates are in degrees (latitude/longitude). The polygon follows
/// GeoJSON conventions: exterior ring is counter-clockwise, holes are clockwise.
/// H3's polyfill does not strictly enforce winding order, but cell containment
/// is determined by whether the cell's center point is inside the polygon.
public struct H3GeoPolygon: Sendable {

    /// The exterior boundary of the polygon (in degrees).
    public let exterior: [H3Coordinate]

    /// Interior holes (each an array of coordinates in degrees).
    public let holes: [[H3Coordinate]]

    /// Creates a polygon with an exterior boundary and optional holes.
    ///
    /// - Parameters:
    ///   - exterior: The outer ring coordinates (degrees).
    ///   - holes: Zero or more interior rings (degrees).
    public init(exterior: [H3Coordinate], holes: [[H3Coordinate]] = []) {
        self.exterior = exterior
        self.holes = holes
    }

    // MARK: - Polyfill

    /// Returns all H3 cells whose center points lie within this polygon at the
    /// given resolution.
    ///
    /// - Parameter resolution: The H3 resolution (0–15).
    /// - Returns: An array of `H3Index` values. May be empty if the polygon is
    ///   too small to contain any cell centers at the requested resolution.
    public func fill(resolution: Int) -> [H3Index] {
        // Convert exterior coordinates to radians using v4 LatLng (field: lng)
        var exteriorCoords = exterior.map {
            LatLng(lat: degsToRads($0.lat), lng: degsToRads($0.lng))
        }

        // Convert each hole to radians
        var holeCoords: [[LatLng]] = holes.map { ring in
            ring.map { LatLng(lat: degsToRads($0.lat), lng: degsToRads($0.lng)) }
        }

        let exteriorCount = exteriorCoords.count
        let holeCount = holeCoords.count

        return exteriorCoords.withUnsafeMutableBufferPointer { extPtr in
            // Build the GeoLoop for the exterior ring (v4: Geofence → GeoLoop)
            let geoloop = GeoLoop(
                numVerts: Int32(exteriorCount),
                verts: extPtr.baseAddress
            )

            if holeCoords.isEmpty {
                // Fast path: no holes
                var polygon = GeoPolygon(geoloop: geoloop, numHoles: 0, holes: nil)
                return Self.runPolyfill(&polygon, resolution: resolution)
            } else {
                // Build GeoLoop structs for each hole.
                // We must keep holeCoords alive (pinned) for the duration of the call.
                return withUnsafeHoleGeoLoops(&holeCoords) { holeLoops in
                    var loops = holeLoops
                    return loops.withUnsafeMutableBufferPointer { holesPtr in
                        var polygon = GeoPolygon(
                            geoloop: geoloop,
                            numHoles: Int32(holeCount),
                            holes: holesPtr.baseAddress
                        )
                        return Self.runPolyfill(&polygon, resolution: resolution)
                    }
                }
            }
        }
    }

    // MARK: - Private helpers

    private static func runPolyfill(_ polygon: inout GeoPolygon, resolution: Int) -> [H3Index] {
        // v4: maxPolygonToCellsSize(polygon, res, flags, &out) → H3Error
        var maxSize: Int64 = 0
        let sizeErr = maxPolygonToCellsSize(&polygon, Int32(resolution), 0, &maxSize)
        guard sizeErr == 0, maxSize > 0 else { return [] }

        var raw = [UInt64](repeating: 0, count: Int(maxSize))
        // v4: polygonToCells(polygon, res, flags, out) → H3Error
        let fillErr = polygonToCells(&polygon, Int32(resolution), 0, &raw)
        guard fillErr == 0 else { return [] }

        return raw.filter { $0 != 0 }.map { H3Index($0) }
    }

    /// Calls `body` with an array of `GeoLoop` values whose `verts` pointers
    /// are pinned into each element of `holeCoords`.
    private func withUnsafeHoleGeoLoops<R>(
        _ holeCoords: inout [[LatLng]],
        body: ([GeoLoop]) -> R
    ) -> R {
        // Recursively pin each hole array and build GeoLoop values.
        func pin(_ index: Int, _ built: [GeoLoop]) -> R {
            if index == holeCoords.count {
                return body(built)
            }
            var ring = holeCoords[index]
            let vertCount = ring.count
            return ring.withUnsafeMutableBufferPointer { ptr in
                let loop = GeoLoop(
                    numVerts: Int32(vertCount),
                    verts: ptr.baseAddress
                )
                return pin(index + 1, built + [loop])
            }
        }
        return pin(0, [])
    }

}
